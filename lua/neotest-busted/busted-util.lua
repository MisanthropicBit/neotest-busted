local busted_util = {}

local logging = require("neotest-busted.logging")

local lib = require("neotest.lib")
local types = require("neotest.types")
local nio = require("nio")
local util = require("neotest-busted.util")

---@package
---@class neotest-busted.RuntimeTestInfo
---@field id string
---@field path string
---@field lnum integer
---@field position_id string
---@field in_tree boolean

--- Determine if a line number is within a range
---@param lnum integer
---@param range integer[]
local function lnum_is_in_range(lnum, range)
    local _lnum = lnum - 1

    return _lnum >= range[1] and _lnum <= range[3]
end

--- Normalize a neotest position id
---@param position_id string
---@return string
local function normalize_position_id(position_id)
    -- TODO: Isn't this what create_pos_id_key does?
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

---@param position neotest.Position
---@return table<string, neotest-busted.RuntimeTestInfo>
local function get_tests_in_range_for_file(position)
    local path = position.path

    local code, results = lib.process.run(
        { "busted", "--list", path },
        { stdout = true, stderr = true }
    )

    if code ~= 0 or results.stderr ~= "" then
        logging.log_and_notify(
            ("Failed to get all tests via busted (code: %d): %s"):format(
                code,
                results.stderr
            ),
            vim.log.levels.ERROR
        )
        return {}
    end

    -- TODO: Handle windows
    local lines = vim.split(results.stdout, "\n", { trimempty = true })
    local tests = {}

    for _, line in ipairs(lines) do
        local parts = vim.split(line, ": ?")
        local non_path_parts = vim.split(parts[3], " ")
        local position_id = ('%s::%s'):format(
            path,
            table.concat(
                vim.tbl_map(function(item)
                    return ('"%s"'):format(item)
                end, non_path_parts),
                "::"
            )
        )

        local test = {
            path = path,
            position_id = position_id,
            in_tree = false,
        }

        if #parts == 3 then
            test.lnum = tonumber(parts[2])
        elseif #parts == 1 then
            -- This can happen for 'it' tests outside of a 'describe' where
            -- only the test name is listed
            test.lnum = 0
        end

        if lnum_is_in_range(test.lnum, position.range) then
            tests[position_id] = test
        end
    end

    return tests
end

---@param tree neotest.Tree
---@param test_info neotest-busted.RuntimeTestInfo
---@return neotest.Position
---@return string
---@return string
local function find_test_position_id(tree, test_info)
    local position = tree:data()

    if position.type == types.PositionType.namespace then
        -- If this is a namespace (i.e. a 'describe'), iterate all tree nodes
        -- to find a test position that matches the line number of the runtime
        -- test info
        for _, node in tree:iter_nodes() do
            if node:data().range[1] + 1 == test_info.lnum then
                position = node:data()
                break
            end
        end
    end

    local position_parts = util.split_position_id(position.id)
    local test_info_parts = util.split_position_id(test_info.position_id)
    local common_prefix = util.longest_common_prefix(position_parts, test_info_parts)
    local test_name = table.concat(
        vim.tbl_map(util.trim_quotes, vim.list_slice(test_info_parts, #common_prefix + 1)),
        " "
    )

    return position, table.concat(common_prefix, "::"), test_name
end

---@param tree neotest.Tree
---@return neotest.Position[]
---@return boolean
---@return neotest.Position[]
function busted_util.expand_parametric_tests(tree)
    local position = tree:data()
    local tests_in_range = get_tests_in_range_for_file(position)
    local unexpanded_tests = {}

    nio.scheduler()

    -- Iterate all positions and find those not in 'busted --list' output as they
    -- are the original unexpanded parametric tests that should not be run because
    -- they won't be found
    for _, node in tree:iter_nodes() do
        local data = node:data()
        local id = normalize_position_id(data.id)

        if tests_in_range[id] then
            tests_in_range[id].in_tree = true
        else
            if data.type == types.PositionType.test then
                unexpanded_tests[data.id] = {}
            end
        end
    end

    local is_parametric = false
    local parametric_positions = {}

    -- Iterate all tests again and add those that were not in the tree to the tree
    -- since they are parametric tests that were expanded at runtime but do not
    -- exist in the tree (source) itself
    for _, test in pairs(tests_in_range) do
        if not test.in_tree then
            -- If the test position is on the same line as a runtime test then
            -- the test itself must be parametric
            is_parametric = test.lnum == position.range[1] + 1

            local matched_position, prefix, test_name = find_test_position_id(tree, test)

            local data = {
                id = ('%s::"%s"'):format(prefix, test_name),
                name = test_name,
                path = position.path,
                range = matched_position.range,
                type = types.PositionType.test,
            }

            table.insert(parametric_positions, data)
            table.insert(unexpanded_tests[matched_position.id], data)

            ---@diagnostic disable-next-line: invisible
            -- local new_tree = types.Tree:new(data, {}, tree._key, nil, nil)

            -- TODO: Should we add these in Adapter.build_spec instead?
            ---@diagnostic disable-next-line: invisible
            -- tree:add_child(tree._key(new_tree:data()), new_tree)
        end
    end

    return unexpanded_tests, is_parametric, parametric_positions
end

return busted_util
