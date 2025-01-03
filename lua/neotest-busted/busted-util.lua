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
---@return string?
---@return string?
local function process_runtime_test_line(line)
    -- TODO: Make this more robust
    -- Splitting like this accounts for colons in test names
    local iter = vim.gsplit(line, ": ?")

    local path = iter()
    local lnum = iter()
    local rest = line:sub(#path + #lnum + 4)

    return lnum, rest
end

---@async
---@param tree neotest.Tree
---@return table<string, neotest-busted.RuntimeTestInfo>
---@return table<string>
local function get_runtime_test_info(tree)
    local position = tree:data()
    local path = position.path
    local command_info = adapter.create_test_command({ path }, {
        busted_arguments = { "--list" },
    })

    if not command_info then
        logging.error("Could not find a busted command for listing tests")
        return {}, {}
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
        return {}, {}
    end

    -- 'busted --list' outputs to stderr
    ---@cast process nio.process.Process
    local stderr, read_err = process.stderr.read()

    if read_err then
        logging.error("Got error when reading output from busted: %s", nil, read_err)
        return {}, {}
    end

    local code = process.result()

    if code ~= 0 then
        logging.error("Failed to list tests via busted (code: %d)", nil, code)
        return {}, {}
    end

    ---@cast stderr -nil

    ---@type table<string, neotest-busted.RuntimeTestInfo>
    local tests = {}
    local ordered_pos_ids = {}

    -- 'busted --list' output contains carriage returns
    for line in vim.gsplit(stderr, "\r\n", { plain = true, trimempty = true }) do
        local lnum, rest = process_runtime_test_line(line)
        local test = { path = path, in_tree = false }

        if lnum and rest then
            local non_path_parts = vim.split(rest, " ")
            local position_id = ("%s::%s"):format(path, table.concat(non_path_parts, "::"))

            test.id = position_id
            test.type = types.PositionType.test
            test.lnum = tonumber(lnum)

            tests[position_id] = test
            table.insert(ordered_pos_ids, position_id)
        else
            -- NOTE: This can happen for top-level 'it' tests outside of a
            -- 'describe' where only the test name is listed by busted
            --
            -- https://github.com/lunarmodules/busted/issues/743
            logger.warn(
                "Top-level 'it' found which is not currently supported for parametric tests"
            )
        end
    end

    return tests, ordered_pos_ids
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

    if not position then
        logging.error(
            "Failed to find a matching position for runtime test. This can happen if neotest-busted cannot parse some tests (you are using neotest's async.it instead of neotest-busted's async function) so busted cannot list the tests properly",
            nil,
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
    local runtime_test_info, ordered_pos_ids = get_runtime_test_info(tree)

    if vim.tbl_count(runtime_test_info) == 0 then
        return {}
    end

    -- Await the scheduler since calling vimL functions like vim.split cannot
    -- be done in fast calls
    nio.scheduler()

    -- Iterate all positions and find those not in the 'busted --list' output
    -- as they are the original unexpanded parametric tests
    -- TODO: Can't we just save the mapping between unexpanded tests and
    -- parametric tests here?
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
    -- tree (source) itself. Iterate using the ordered position ids so that
    -- the parametric tests are created in the tree in the order they appear
    -- in the file
    for _, pos_id in ipairs(ordered_pos_ids) do
        local test = runtime_test_info[pos_id]

        if not test.in_tree then
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
