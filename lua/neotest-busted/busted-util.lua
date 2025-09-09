local busted_util = {}

local adapter = require("neotest-busted")
local logging = require("neotest-busted.logging")
local util = require("neotest-busted.util")

local logger = require("neotest.logging")
local nio = require("nio")
local types = require("neotest.types")

---@package
---@class neotest-busted.RuntimeTestInfo
---@field id string
---@field type neotest.PositionType
---@field path string
---@field lnum integer
---@field in_tree boolean

--- Process a line from the output of 'busted --list'
---@param line string
---@return string
---@return string
---@return integer
local function process_list_test_line(line)
    local parts = vim.split(line, "::")
    local path = parts[1]
    local pos_id_parts = vim.list_slice(parts, 2, #parts - 1)
    local test_name = pos_id_parts[#pos_id_parts]
    local lnum = tonumber(parts[#parts])
    ---@cast lnum -nil

    local quoted_pos_id = vim.tbl_map(function(part)
        return '"' .. part .. '"'
    end, pos_id_parts)

    return path .. "::" .. table.concat(quoted_pos_id, "::"), test_name, lnum
end

---@async
---@param tree neotest.Tree
---@return string?
local function run_list_tests_command(tree)
    local position = tree:data()
    local path = position.path

    -- Using 'busted --list' outputs an incomplete path and uses spaces to
    -- concatenate the full test name so we do not know if a space is a
    -- delimiter or part of the test name. Instead we use a custom helper
    -- script that works similar to the code executed by running 'busted --list'.
    -- It outputs the full path and uses an internal delimiter.
    local command_info = adapter.create_test_command({ path }, {
        busted_arguments = {
            "--helper",
            util.get_path_to_plugin_file("helper_scripts/list_tests.lua"),
        },
    })

    if not command_info then
        logging.error("Could not find a busted command for listing tests")
        return
    end

    logger.debug(
        "Running command ",
        command_info.nvim_command,
        " to list tests with arguments ",
        command_info.arguments
    )

    local process, err = nio.process.run({
        cmd = command_info.nvim_command,
        args = command_info.arguments,
    })

    if err then
        logging.error("Failed to list tests via busted: %s", nil, err)
        return
    end

    -- Output goes to stderr
    ---@cast process nio.process.Process
    local stderr, read_err = process.stderr.read()

    if read_err then
        logging.error("Got error when reading output from busted: %s", nil, read_err)
        return
    end

    local code = process.result()

    if code ~= 0 then
        logging.error("Failed to list tests via busted (code: %d)", nil, code)
        return
    end

    return stderr
end

---@async
---@param tree neotest.Tree
---@return table<string, neotest-busted.RuntimeTestInfo>
---@return table<string>
local function get_runtime_test_info(tree)
    local output = run_list_tests_command(tree)

    if not output then
        return {}, {}
    end

    ---@type table<string, neotest-busted.RuntimeTestInfo>
    local tests = {}
    local ordered_pos_ids = {}
    local path = tree:data().path

    -- Output contains carriage returns
    for line in vim.gsplit(output, "\r\n", { plain = true, trimempty = true }) do
        local position_id, test_name, lnum = process_list_test_line(line)

        tests[position_id] = {
            path = path,
            in_tree = false,
            id = position_id,
            type = types.PositionType.test,
            lnum = lnum,
            name = test_name,
        }

        table.insert(ordered_pos_ids, position_id)
    end

    return tests, ordered_pos_ids
end

---@async
---@param tree neotest.Tree
---@return table<string, neotest.Position[]>
function busted_util.discover_parametric_tests(tree)
    local runtime_test_info, ordered_pos_ids = get_runtime_test_info(tree)

    if vim.tbl_count(runtime_test_info) == 0 then
        return {}
    end

    ---@type table<integer, neotest.Position>
    local tests_by_line_number = {}

    -- Iterate all positions and find those not in the output
    -- as they are the original source-level parametric tests
    for _, node in tree:iter_nodes() do
        local pos = node:data()

        if pos.type == types.PositionType.test then
            tests_by_line_number[pos.range[1] + 1] = pos

            if runtime_test_info[pos.id] then
                -- The tree position appears in the runtime test information
                runtime_test_info[pos.id].in_tree = true
            end
        end
    end

    --- Group parametric (runtime-level) tests by their shared (source-level) position id
    ---@type table<string, neotest-busted.RuntimeTestInfo[]>
    local parametric_positions = {}

    -- Iterate runtime test info and mark those positions not in the tree as
    -- parametric tests because they only existed at runtime but not in the
    -- tree (source) itself. Iterate using the ordered position ids so that
    -- the parametric tests are created in the tree in the order they appear
    -- in the file
    for _, pos_id in ipairs(ordered_pos_ids) do
        local test = runtime_test_info[pos_id]

        -- Test was not in tree so it must be parametric
        if not test.in_tree then
            local source_level_pos = tests_by_line_number[test.lnum]

            if source_level_pos then
                if not parametric_positions[source_level_pos.id] then
                    parametric_positions[source_level_pos.id] = {}
                end

                table.insert(parametric_positions[source_level_pos.id], test)
            end
        end
    end

    return parametric_positions
end

return busted_util
