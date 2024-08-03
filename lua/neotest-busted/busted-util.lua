local busted_util = {}

local adapter = require("neotest-busted")
local logging = require("neotest-busted.logging")

local lib = require("neotest.lib")
local logger = require("neotest.logging")
local nio = require("nio")
local types = require("neotest.types")
local util = require("neotest-busted.util")

---@package
---@class neotest-busted.RuntimeTestInfo
---@field id string
---@field path string
---@field lnum integer
---@field position_id string
---@field in_tree boolean

--- Normalize a neotest position id to a position id key used internally by -
--- neotest-busted e.g.
--- "path::"describe 1"::test 1" => "path::describe::1::test::1"
---@param position_id string
---@return string
local function normalize_position_id(position_id)
    local parts = util.split_position_id(position_id)
    local stripped_parts = {}

    for idx, part in ipairs(parts) do
        local trimmed = vim.split(util.trim_quotes(part), " ")

        if idx > 1 then
            trimmed = vim.tbl_map(function(trim)
                return '"' .. trim .. '"'
            end, trimmed)
        end

        vim.list_extend(stripped_parts, trimmed)
    end

    return table.concat(stripped_parts, "::")
end

--- Process a line from the output 'busted --list'
---@param line string
---@return string?
---@return string?
local function process_runtime_test_line(line)
    -- Splitting like this accounts for colons in test names
    local iter = vim.gsplit(line, ": ?")

    local path = iter()
    local lnum = iter()
    local rest = line:sub(#path + #lnum + 4)

    return lnum, rest
end

---@param tree neotest.Tree
---@return table<string, neotest-busted.RuntimeTestInfo>
local function get_runtime_test_info(tree)
    local position = tree:data()
    local path = position.path
    local command_info = adapter.create_busted_command({ path }, {
        busted_arguments = { "--list" },
    })

    if not command_info then
        logging.error("Could not find a busted command for listing tests")
        return {}
    end

    local command = vim.list_extend({ command_info.nvim_command }, command_info.arguments)
    logger.debug("Running command to list tests: ", command)

    local code, results = lib.process.run(command, { stdout = true, stderr = true })

    if code ~= 0 then
        logging.error(
            "Failed to discover parametric tests via busted (code: %d): %s",
            nil,
            code,
            results.stderr
        )
        return {}
    end

    ---@type table<string, neotest-busted.RuntimeTestInfo>
    local tests = {}

    -- 'busted --list' outputs to stderr and apparently uses carriage return
    for line in vim.gsplit(results.stderr, "\r\n", { plain = true, trimempty = true }) do
        local lnum, rest = process_runtime_test_line(line)
        local test = { path = path, in_tree = false }

        if path then
            local non_path_parts = vim.split(rest, " ")
            -- local position_id = normalize_position_id(path .. "::" .. non_path_parts)
            local position_id = ("%s::%s"):format(
                path,
                table.concat(
                    vim.tbl_map(function(item)
                        return ('"%s"'):format(item)
                    end, non_path_parts),
                    "::"
                )
            )

            test.lnum = tonumber(lnum)
            test.position_id = position_id
            tests[position_id] = test
        else
            -- FIX: This can happen for 'it' tests outside of a 'describe'
            -- where only the test name is listed
        end
    end

    return tests
end

---@param tree neotest.Tree
---@param runtime_test neotest-busted.RuntimeTestInfo
---@return neotest.Position?
---@return string
---@return string
local function find_test_position_id(tree, runtime_test)
    local position

    -- Iterate all nodes to find a test position that matches the line
    -- number of the runtime test
    for _, node in tree:iter_nodes() do
        local pos = node:data()

        if pos.range[1] + 1 == runtime_test.lnum then
            position = pos
            break
        end
    end

    if not position then
        logging.error(
            {
                runtime_test = runtime_test,
            },
            "Failed to find a matching position for runtime test. This could happen if neotest-busted cannot parse some tests but busted can list the tests"
        )
        return nil, "", ""
    end

    local position_parts = util.split_position_id(position.id)
    local test_info_parts = util.split_position_id(runtime_test.position_id)
    local common_prefix = util.longest_common_prefix(position_parts, test_info_parts)
    local non_common_prefix = vim.list_slice(test_info_parts, #common_prefix + 1)
    local test_name = table.concat(vim.tbl_map(util.trim_quotes, non_common_prefix), " ")

    return position, table.concat(common_prefix, "::"), test_name
end

---@async
---@param tree neotest.Tree
---@return neotest.Position[]
---@return table<string, neotest.Position[]>
local function discover_parametric_tests(tree)
    local runtime_test_info = get_runtime_test_info(tree)

    -- Await the scheduler since calling vimL functions like vim.split cannot
    -- be done in fast calls
    nio.scheduler()

    ---@type table<string, neotest.Position[]>
    local unexpanded_tests = {}

    -- Iterate all positions and find those not in 'busted --list' output as they
    -- are the original unexpanded parametric tests that should not be run because
    -- they won't be found
    for _, node in tree:iter_nodes() do
        local pos = node:data()

        if pos.type == types.PositionType.test then
            local normalized_id = normalize_position_id(pos.id)

            if runtime_test_info[normalized_id] then
                -- The tree position appears in the runtime test information
                runtime_test_info[normalized_id].in_tree = true
            else
                -- The tree position does not appear in the runtime test information so
                -- it must be an unexpanded test
                unexpanded_tests[normalized_id] = pos
            end
        end
    end

    local parametric_positions = {}

    -- Iterate runtime test info and mark those positions not in the tree as
    -- parametric tests because they only existed at runtime but not in the
    -- tree (source) itself
    for _, test in pairs(runtime_test_info) do
        if not test.in_tree then
            local matched_position, prefix, test_name = find_test_position_id(tree, test)

            if not matched_position then
                goto continue
            end

            if matched_position ~= nil then
                -- Create an extra 'real_range' property for generating position id keys
                -- later on for parametric tests since we need to set 'range' to nil
                -- mark it as a range-less child test:
                -- https://github.com/nvim-neotest/neotest/pull/172
                local data = {
                    id = ('%s::"%s"'):format(prefix, test_name),
                    name = test_name,
                    path = matched_position.path,
                    range = nil, -- matched_position.range,
                    real_range = matched_position.range,
                    type = types.PositionType.test,
                }

                local matched_id = matched_position.id

                if not parametric_positions[matched_id] then
                    parametric_positions[matched_id] = {}
                end

                table.insert(parametric_positions[matched_id], data)
            end

            ::continue::
        end
    end

    return unexpanded_tests, parametric_positions
end

---@async
---@param tree neotest.Tree
function busted_util.add_parametric_tests(tree)
    local _, parametric_position_data = discover_parametric_tests(tree)

    -- Iterate the whole tree and insert parametric tests at the correct positions
    for _, node in tree:iter_nodes() do
        local pos = node:data()

        if pos.type ~= types.PositionType.test then
            goto continue
        end

        local parametric_positions = parametric_position_data[pos.id] or {}

        -- WARNING: This relies on neotest internals
        for _, parametric_position in ipairs(parametric_positions) do
            ---@diagnostic disable-next-line: invisible
            local new_tree = types.Tree:new(parametric_position, {}, tree._key, nil, nil)

            ---@diagnostic disable-next-line: invisible
            node:add_child(parametric_position.id, new_tree)
        end

        ::continue::
    end
end

return busted_util
