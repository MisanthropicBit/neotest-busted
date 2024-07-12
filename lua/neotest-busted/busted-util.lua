local busted_util = {}

local lib = require("neotest.lib")
local logger = require("neotest.logging")
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

---@param position_id string
---@return string
local function normalize_position_id(position_id)
    local parts = vim.split(position_id, "::")
    local stripped_parts = {}

    for idx, part in ipairs(parts) do
        local trimmed = vim.split(vim.fn.trim(part, '"'), " ")

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
        -- TODO: Notify
        logger.error(
            ("Failed to get all tests via busted (code: %d)"):format(code),
            "stderr: ",
            results.stderr
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

---@param position neotest.Position
---@param test_info neotest-busted.RuntimeTestInfo
---@return string
---@return string
local function deduce_test_position_id(position, test_info)
    local position_parts = vim.split(position.id, "::")
    local test_info_parts = vim.split(test_info.position_id, "::")
    local test_name = table.concat(
        vim.tbl_map(util.trim_quotes, vim.list_slice(test_info_parts, #position_parts)),
        " "
    )

    return table.concat(position_parts, "::", 1, #position_parts - 1), test_name
end

---@param tree neotest.Tree
---@return neotest.Position[]
function busted_util.expand_parametric_tests(tree)
    local position = tree:data()
    local tests_in_range = get_tests_in_range_for_file(position)

    nio.scheduler()

    -- Iterate all positions and find those not in 'busted --list' output as they
    -- are the original unexpanded parametric tests that should not be run because
    -- they won't be found
    for _, node in tree:iter_nodes() do
        local data = node:data()
        local id = normalize_position_id(data.id)

        if tests_in_range[id] then
            tests_in_range[id].in_tree = true
        end
    end

    local parametric_positions = {}

    -- Iterate all tests again and add those that were not in the tree to the tree
    -- since they are parametric tests that were expanded at runtime but do not
    -- exist in the tree (source) itself
    for _, test in pairs(tests_in_range) do
        if not test.in_tree then
            local prefix, test_name = deduce_test_position_id(position, test)

            local data = {
                id = ('%s::"%s"'):format(prefix, test_name),
                name = test_name,
                path = position.path,
                range = position.range,
                type = types.PositionType.test,
            }

            table.insert(parametric_positions, data)

            ---@diagnostic disable-next-line: invisible
            -- local new_tree = types.Tree:new(data, {}, tree._key, nil, nil)

            -- TODO: Should we add these in Adapter.build_spec instead?
            ---@diagnostic disable-next-line: invisible
            -- tree:add_child(tree._key(new_tree:data()), new_tree)
        end
    end

    return parametric_positions
end

return busted_util
