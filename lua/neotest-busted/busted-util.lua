local busted_util = {}

local adapter = require("neotest-busted")
local logging = require("neotest-busted.logging")
local util = require("neotest-busted.util")

local lib = require("neotest.lib")
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

        if lnum and rest then
            local non_path_parts = vim.split(rest, " ")
            local position_id = ("%s::%s"):format(path, table.concat(non_path_parts, "::"))

            test.id = position_id
            test.type = types.PositionType.test
            test.lnum = tonumber(lnum)

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
local function find_overlapping_position(tree, runtime_test)
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

    -- FIX: This still triggers, probably for namespaces etc.
    if not position then
        logging.error(
            "Failed to find a matching position for runtime test. This can happen if neotest-busted cannot parse some tests (you are using neotest's async.it instead of neotest-busted's async function) so busted cannot list the tests properly",
            {
                runtime_test = runtime_test,
            }
        )
        return nil
    end

    return position
end

---@async
---@param tree neotest.Tree
---@return table<string, neotest.Position[]>
function busted_util.discover_parametric_tests(tree)
    local runtime_test_info = get_runtime_test_info(tree)

    -- Await the scheduler since calling vimL functions like vim.split cannot
    -- be done in fast calls
    nio.scheduler()

    -- Iterate all positions and find those not in 'busted --list' output as they
    -- are the original unexpanded parametric tests that should not be run because
    -- they won't be found
    for _, node in tree:iter_nodes() do
        local pos = node:data()

        if pos.type == types.PositionType.test then
            local path, stripped = util.strip_position_id(pos.id, "::")
            local normalized_id = ("%s::%s"):format(
                path,
                table.concat(vim.split(stripped, " "), "::")
            )

            if runtime_test_info[normalized_id] then
                -- The tree position appears in the runtime test information
                runtime_test_info[normalized_id].in_tree = true
            end
        end
    end

    local parametric_positions = {}

    -- Iterate runtime test info and mark those positions not in the tree as
    -- parametric tests because they only existed at runtime but not in the
    -- tree (source) itself
    for _, test in pairs(runtime_test_info) do
        if not test.in_tree then
            -- Create an extra 'real_range' property for generating position id keys
            -- later on for parametric tests since we need to set 'range' to nil to
            -- mark it as a range-less child test:
            -- https://github.com/nvim-neotest/neotest/pull/172
            local pos = find_overlapping_position(tree, test)

            if pos then
                if not parametric_positions[pos.id] then
                    parametric_positions[pos.id] = {}
                end

                table.insert(parametric_positions[pos.id], test)
            end
        end
    end

    return parametric_positions
end

return busted_util
