local async = require("neotest.async")
local lib = require("neotest.lib")
local logger = require("neotest.logging")
local types = require("neotest.types")

local function get_strategy_config(strategy)
    local config = {
        dap = nil, -- TODO: Add dap config
    }
    if config[strategy] then
        return config[strategy]()
    end
end

---@type neotest-busted.Config
local config = {
    busted_command = nil,
    busted_args = nil,
    busted_path = nil,
    busted_cpath = nil,
    minimal_init = nil,
}

local function expand_and_create_path(...)
    return table.concat(vim.tbl_map(vim.fn.expand, ...), ";")
end

--- Find busted command and additional paths
---@return table<string, string>?
local function find_busted_command()
    if config.busted_command ~= nil then
        logger.debug("Using busted command from config")

        return {
            command = config.busted_command,
            path = config.busted_path or "",
            cpath = config.busted_cpath or "",
        }
    end

    -- Try to find a directory-local busted executable
    local local_globs = vim.fn.split(vim.fn.glob("lua_modules/lib/luarocks/**/bin/busted"), "\n")

    if #local_globs > 0 then
        logger.debug("Using project-local busted executable")

        return {
            command = local_globs[1],
            path = config.busted_path or "./lua/?.lua;./lua_modules/share/lua/5.1/?.lua;./lua_modules/share/lua/5.1/?/init.lua;;",
            cpath = config.busted_cpath or "./lua_modules/lib/lua/5.1/?.so;;",
        }
    end

    -- Try to find a local (user home directory) busted executable
    local user_globs = vim.fn.split(vim.fn.glob("~/.luarocks/lib/luarocks/**/bin/busted"), "\n")

    if #user_globs > 0 then
        logger.debug("Using local (~/.luarocks) busted executable")

        return {
            command = user_globs[1],
            path = config.busted_path or expand_and_create_path({
                "~/.luarocks/share/lua/5.1/?.lua",
                "~/.luarocks/share/lua/5.1/?/init.lua",
            }),
            cpath = config.busted_cpath or expand_and_create_path({
                "~/.luarocks/lib/lua/5.1/?.so",
                "~/.luarocks/lib/lua/5.1/?/?.so",
            }),
        }
    end

    -- Try to find busted in path
    if vim.fn.executable("busted") == 1 then
        logger.debug("Using global busted executable")

        return {
            command = "busted",
            path = config.busted_path or "",
            cpath = config.busted_cpath or "",
        }
    end

    return nil
end

---@return string?
local function find_minimal_init()
    local minimal_init = config.minimal_init

    if not minimal_init then
        local glob_matches = vim.fn.split(
            vim.fn.glob(("**%sminimal_init.lua"):format(lib.files.sep), true),
            "\n"
        )

        if #glob_matches > 0 then
            minimal_init = glob_matches[1]
        end
    end

    return minimal_init
end

local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)

    return str:match(("(.*%s)"):format(lib.files.sep))
end

local function get_reporter_path()
    return table.concat({ script_path(), "output_handler.lua" })
end

---@param results_path string
---@param paths string[]
---@param filters string[]
---@return neotest-busted.BustedCommand?
local function create_busted_command(results_path, paths, filters)
    local busted = find_busted_command()

    if not busted then
        return
    end

    -- stylua: ignore start
    local command = {
        vim.loop.exepath(),
        "--headless",
        "-i", "NONE", -- no shada
        "-n", -- no swapfile, always in-memory
        "-u", find_minimal_init() or "NONE",
    }
    -- stylua: ignore end

    if busted.path and #busted.path > 0 then
        -- Add local paths to package.path
        vim.list_extend(
            command,
            { "-c", ("\"lua package.path = '%s;' .. package.path\""):format(busted.path) }
        )
    end

    if busted.cpath and #busted.cpath > 0 then
        -- Add local cpaths to package.cpath
        vim.list_extend(
            command,
            { "-c", ("\"lua package.cpath = '%s;' .. package.cpath\""):format(busted.cpath) }
        )
    end

    -- Create a busted command invocation string using neotest-busted's own output handler
    local busted_command = ("%s --output=%s -Xoutput=%s"):format(
        busted.command,
        get_reporter_path(),
        results_path
    )

    -- Run busted in neovim ('-l' stops parsing arguments for neovim)
    -- stylua: ignore start
    vim.list_extend(command, {
        "-l", busted_command,
        "--verbose",
    })
    -- stylua: ignore end

    if vim.tbl_islist(config.busted_args) and #config.busted_args > 0 then
        vim.list_extend(command, config.busted_args)
    end

    -- Add test filters
    for _, filter in ipairs(filters) do
        table.insert(command, "--filter=" .. '"' .. filter .. '"')
    end

    -- Add test files
    vim.list_extend(command, paths)

    return {
        command = table.concat(command, " "),
        path = busted.path,
        cpath = busted.cpath,
    }
end

---@type neotest.Adapter
local BustedNeotestAdapter = { name = "neotest-busted" }

BustedNeotestAdapter.root =
lib.files.match_root_pattern(".busted", ".luarocks", "lua_modules", "*.rockspec", ".git")

---@param file_path string
---@return boolean
---@diagnostic disable-next-line: duplicate-set-field
function BustedNeotestAdapter.is_test_file(file_path)
    return vim.endswith(file_path, "_spec.lua")
end

---@diagnostic disable-next-line: duplicate-set-field
function BustedNeotestAdapter.filter_dir(name)
    return not vim.tbl_contains({
        "lua_modules",
        ".luarocks",
        "doc",
    }, name)
end

---@async
---@return neotest.Tree | nil
---@diagnostic disable-next-line: duplicate-set-field
function BustedNeotestAdapter.discover_positions(path)
    local query = [[
    ;; describe blocks
    ((function_call
        name: (identifier) @func_name (#match? @func_name "^describe$")
        arguments: (arguments (_) @namespace.name (function_definition))
    )) @namespace.definition

    ;; it blocks
    ((function_call
        name: (identifier) @func_name
        arguments: (arguments (_) @test.name (function_definition))
    ) (#match? @func_name "^it$")) @test.definition
]]

    return lib.treesitter.parse_positions(path, query, { nested_namespaces = true })
end

--- Create a unique key to identify a test
---@param stripped_pos_id string neotest position id stripped of "::"
---@param lnum_start integer
---@return string
local function create_pos_id_key(path, stripped_pos_id, lnum_start)
    return ("%s::%s::%d"):format(path, stripped_pos_id, lnum_start)
end

local function extract_test_info(pos)
    local parts = vim.fn.split(pos.id, "::")
    local path = parts[1]
    local stripped_pos_id = table.concat(
        vim.tbl_map(function(part)
            return vim.fn.trim(part, '"')
        end, vim.list_slice(parts, 2)),
        " "
    )

    -- Busted creates test names concatenated with spaces so we can't recreate the
    -- position id using "::". Instead create a key stripped of "::" like the one
    -- from busted along with the test line range to uniquely identify the test
    local pos_id_key = create_pos_id_key(path, stripped_pos_id, pos.range[1] + 1)

    return path, stripped_pos_id, pos_id_key
end

---@param args neotest.RunArgs
---@return neotest.RunSpec | nil
---@diagnostic disable-next-line: duplicate-set-field
function BustedNeotestAdapter.build_spec(args)
    local tree = args.tree

    if not tree then
        return
    end

    local pos = args.tree:data()

    if pos.type == "dir" then
        return
    end

    local paths = {}
    local filters = {}
    local position_ids = {}

    if pos.type == "namespace" or pos.type == "test" then
        local path, filter, pos_id_key = extract_test_info(pos)

        table.insert(paths, path)
        table.insert(filters, filter)
        position_ids[pos_id_key] = pos.id
    elseif pos.type == "file" then
        table.insert(paths, pos.id)

        -- Iterate all tests in the file and generate position ids for them
        for _, _tree in args.tree:iter_nodes() do
            local _pos = _tree:data()

            if _pos.type == "test" then
                local _, filter, pos_id_key = extract_test_info(_pos)

                table.insert(filters, filter)
                position_ids[pos_id_key] = _pos.id
            end
        end
    end

    local results_path = async.fn.tempname()
    local busted = create_busted_command(results_path, paths, filters)

    if not busted then
        local message = "Could not find a busted executable"
        logger.error(message)
        vim.notify(message, vim.log.levels.ERROR)

        return
    end

    return {
        command = busted.command,
        context = {
            results_path = results_path,
            pos = pos,
            position_ids = position_ids,
        },
    }
end

local function create_error_info(test_result)
    -- We have to extract the line number that the error occurred on from the message
    -- since that information is not part of the json output
    local match = test_result.message:match("_spec.lua:(%d+):")

    if match then
        return {
            {
                message = test_result.trace.message,
                line = tonumber(match) - 1,
            },
        }
    end

    return nil
end

---@param test_result neotest-busted.BustedResult | neotest-busted.BustedFailureResult
---@param status neotest.ResultStatus
---@param output string
---@param is_error boolean
local function test_result_to_neotest_result(test_result, status, output, is_error)
    local pos_id = create_pos_id_key(
        test_result.element.trace.source:sub(2), -- Strip the "@" from the source path
        test_result.name,
        test_result.element.trace.currentline
    )

    local result = {
        status = status,
        short = ("%s: %s"):format(test_result.name, status),
        output = output,
    }

    if is_error then
        result.errors = create_error_info(test_result)
    end

    return pos_id, result
end

---@async
---@param spec neotest.RunSpec
---@param strategy_result neotest.StrategyResult
---@param tree neotest.Tree
---@diagnostic disable-next-line: duplicate-set-field, unused-local
function BustedNeotestAdapter.results(spec, strategy_result, tree)
    -- TODO: Use an output stream instead if possible
    local results_path = spec.context.results_path
    local ok, data = pcall(lib.files.read, results_path)

    if not ok then
        logger.error("Failed to read json test output file ", results_path)
        return {}
    end

    ---@diagnostic disable-next-line: cast-local-type
    local json_ok, parsed = pcall(vim.json.decode, data, { luanil = { object = true } })

    if not json_ok then
        logger.error("Failed to parse json test output ", results_path)
        return {}
    end

    ---@type neotest-busted.BustedResultObject
    ---@diagnostic disable-next-line: assign-type-mismatch
    local test_results = parsed

    local results = {}
    local output = strategy_result.output
    local position_ids = spec.context.position_ids

    ---@type { [1]: string, [2]: neotest.ResultStatus, [3]: boolean }[]
    local test_types = {
        { "successes", types.ResultStatus.passed,  false },
        { "pendings",  types.ResultStatus.skipped, false },
        { "failures",  types.ResultStatus.failed,  true },
        { "errors",    types.ResultStatus.failed,  true },
    }

    for _, test_type in ipairs(test_types) do
        local test_key, result_status, is_error = test_type[1], test_type[2], test_type[3]

        ---@cast test_results neotest-busted.BustedResultObject
        for _, value in pairs(test_results[test_key]) do
            local pos_id_key, result =
            test_result_to_neotest_result(value, result_status, output, is_error)

            local pos_id = position_ids[pos_id_key]

            if not pos_id then
                logger.error("Failed to find matching position id for key ", pos_id_key)
            else
                results[position_ids[pos_id_key]] = result
            end
        end
    end

    return results
end

setmetatable(BustedNeotestAdapter, {
    ---@param user_config neotest-busted.Config?
    __call = function(user_config)
        user_config = user_config or {}

        if user_config.busted_command then
            if vim.fn.executable(config.busted_command) == 0 then
                vim.notify("Busted command in configuration is not executable")
            end
        end

        config = vim.tbl_extend("force", config, user_config)

        return BustedNeotestAdapter
    end,
})

return BustedNeotestAdapter
