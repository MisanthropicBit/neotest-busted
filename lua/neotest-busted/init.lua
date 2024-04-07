local config = require("neotest-busted.config")
local util = require("neotest-busted.util")

local async = require("neotest.async")
local lib = require("neotest.lib")
local logger = require("neotest.logging")
local types = require("neotest.types")

---@type neotest.Adapter
local BustedNeotestAdapter = { name = "neotest-busted" }

--- Find busted command and additional paths
---@param ignore_local? boolean
---@return neotest-busted.BustedCommandConfig?
function BustedNeotestAdapter.find_busted_command(ignore_local)
    if config.busted_command and #config.busted_command > 0 then
        logger.debug("Using busted command from config")

        return {
            type = "config",
            command = config.busted_command,
            path = config.busted_path or {},
            cpath = config.busted_cpath or {},
        }
    end

    if not ignore_local then
        -- Try to find a directory-local busted executable
        local local_globs =
            util.glob(util.create_path("lua_modules", "lib", "luarocks", "**", "bin", "busted"))

        if #local_globs > 0 then
            logger.debug("Using project-local busted executable")

            return {
                type = "project",
                command = local_globs[1],
                lua_paths = {
                    util.create_path("lua_modules", "share", "lua", "5.1", "?.lua"),
                    util.create_path("lua_modules", "share", "lua", "5.1", "?", "init.lua"),
                },
                lua_cpaths = {
                    util.create_path("lua_modules", "lib", "lua", "5.1", "?.so"),
                    util.create_path("lua_modules", "lib", "lua", "5.1", "?", "?.so"),
                },
            }
        end
    end

    -- Try to find a local (user home directory) busted executable
    local user_globs =
        util.glob(util.create_path("~", ".luarocks", "lib", "luarocks", "**", "bin", "busted"))

    if #user_globs > 0 then
        logger.debug("Using local (~/.luarocks) busted executable")

        return {
            type = "local",
            command = user_globs[1],
            lua_paths = {
                util.create_path("~", ".luarocks", "share", "lua", "5.1", "?.lua"),
                util.create_path("~", ".luarocks", "share", "lua", "5.1", "?", "init.lua"),
            },
            lua_cpaths = {
                util.create_path("~", ".luarocks", "lib", "lua", "5.1", "?.so"),
                util.create_path("~", ".luarocks", "lib", "lua", "5.1", "?", "?.so"),
            },
        }
    end

    -- Try to find busted in path
    if vim.fn.executable("busted") == 1 then
        logger.debug("Using global busted executable")

        return {
            type = "global",
            command = "busted",
            lua_paths = {},
            lua_cpaths = {},
        }
    end

    return nil
end

---@return string?
local function find_minimal_init()
    local minimal_init = config.minimal_init

    if type(minimal_init) == "string" and #minimal_init > 0 then
        return minimal_init
    end

    local pattern = util.create_path("**", "minimal_init.lua")
    local glob_matches = util.glob(pattern)

    if #glob_matches > 0 then
        return glob_matches[1]
    end
end

---@return string
local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)

    return str:match(util.create_path("(.*", ")"))
end

---@return string
local function get_reporter_path()
    return table.concat({ script_path(), "output_handler.lua" })
end

---@return string
local function get_debug_start_script()
    return table.concat({ script_path(), "start-debug.lua" })
end

--- Escape special characters in a lua pattern
---@param filter string
---@return string
local function escape_test_pattern_filter(filter)
    -- NOTE: The replacement of a literal '%' needs to come first so it does
    -- match any earlier replacements that insert a '%'.
    return (
        filter
            :gsub("%%", "%%%%")
            :gsub("%(", "%%(")
            :gsub("%)", "%%)")
            :gsub("%[", "%%[")
            :gsub("%*", "%%*")
            :gsub("%+", "%%+")
            :gsub("%-", "%%-")
            :gsub("%?", "%%?")
            :gsub("%$", "%%$")
            :gsub("%^", "%%^")
    )
end

---@param results_path string?
---@param paths string[]
---@param filters string[]
---@param options neotest-busted.BustedCommandOptions?
---@return neotest-busted.BustedCommandConfig?
function BustedNeotestAdapter.create_busted_command(results_path, paths, filters, options)
    local busted = BustedNeotestAdapter.find_busted_command()

    if not busted then
        return
    end

    -- stylua: ignore start
    ---@type string[]
    local arguments = {
        "--headless",
        "-i", "NONE", -- no shada
        "-n", -- no swapfile, always in-memory
        "-u", find_minimal_init() or "NONE",
    }
    -- stylua: ignore end

    ---@type string[], string[]
    local lua_paths, lua_cpaths = {}, {}

    -- Append custom paths from config
    if vim.tbl_islist(config.busted_paths) then
        vim.list_extend(lua_paths, config.busted_paths)
    end

    if vim.tbl_islist(config.busted_cpaths) then
        vim.list_extend(lua_cpaths, config.busted_cpaths)
    end

    -- Append paths so busted can find the plugin files
    table.insert(lua_paths, util.create_path("lua", "?.lua"))
    table.insert(lua_paths, util.create_path("lua", "?", "init.lua"))

    -- Add paths for busted
    vim.list_extend(lua_paths, busted.lua_paths)
    vim.list_extend(lua_cpaths, busted.lua_cpaths)

    -- Create '-c' arguments for updating package paths in neovim
    vim.list_extend(arguments, util.create_package_path_argument("package.path", lua_paths))
    vim.list_extend(arguments, util.create_package_path_argument("package.cpath", lua_cpaths))

    local _options = options or {}

    -- Create a busted command invocation string using neotest-busted's own
    -- output handler and run busted with neovim ('-l' stops parsing arguments
    -- for neovim)
    local busted_command = {
        "-l",
        busted.command,
        "--verbose",
    }

    if _options.output_handler then
        vim.list_extend(busted_command, {
            "--output",
            _options.output_handler,
        })

        if _options.output_handler_options then
            table.insert(busted_command, "-Xoutput")
            vim.list_extend(busted_command, _options.output_handler_options)
        end
    else
        if not results_path then
            error("Results path expected but not set")
        end

        vim.list_extend(busted_command, {
            "--output",
            get_reporter_path(),
            "-Xoutput",
            results_path,
        })
    end

    vim.list_extend(command, busted_command)

    if vim.tbl_islist(config.busted_args) and #config.busted_args > 0 then
        vim.list_extend(arguments, config.busted_args)
    end

    -- Add test filters
    for _, filter in ipairs(filters) do
        vim.list_extend(arguments, { "--filter", escape_test_pattern_filter(filter) })
    end

    -- Add test files
    vim.list_extend(arguments, paths)

    return {
        nvim_command = vim.loop.exepath(),
        arguments = arguments,
        path = lua_paths,
        cpath = lua_cpaths,
    }
end

---@param strategy string
---@param results_path string
---@param paths string[]
---@param filters string[]
---@return table?
local function get_strategy_config(strategy, results_path, paths, filters)
    if strategy == "dap" then
        table.insert(paths, 1, get_debug_start_script())

        local test_command_info = create_test_command_info(
            results_path,
            paths,
            filters
        )

        if not test_command_info then
            return nil
        end

        return {
            name = "Debug busted tests",
            type = "local-lua",
            cwd = "${workspaceFolder}",
            request = "launch",
            env = {
                LUA_PATH = util.expand_and_create_lua_path(test_command_info.lua_path),
                LUA_CPATH = util.expand_and_create_lua_path(test_command_info.lua_cpath),
            },
            program = {
                command = test_command_info.nvim_command,
            },
            args = test_command_info.arguments,
        }
    end

    return nil
end

---@type neotest.Adapter
local BustedNeotestAdapter = { name = "neotest-busted" }

BustedNeotestAdapter.root =
    lib.files.match_root_pattern(".busted", ".luarocks", "lua_modules", "*.rockspec")

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

    ;; custom async blocks
    ((function_call
        name: (identifier) @func_name
        arguments: (arguments (_) @test.name (function_call
            name: (identifier) @async (#match? @async "^async$")
        ))
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

--- Extract test info from a position
---@param pos neotest.Position
---@return string
---@return string
---@return string
local function extract_test_info(pos)
    local parts = vim.split(pos.id, "::")
    local path = parts[1]
    local stripped_pos_id = table.concat(
        vim.tbl_map(function(part)
            return util.trim(part, '"')
        end, vim.list_slice(parts, 2)),
        " "
    )

    -- Busted creates test names concatenated with spaces so we can't recreate the
    -- position id using "::". Instead create a key stripped of "::" like the one
    -- from busted along with the test line range to uniquely identify the test
    local pos_id_key = create_pos_id_key(path, stripped_pos_id, pos.range[1] + 1)

    return path, stripped_pos_id, pos_id_key
end

--- Generate test info for the nodes in a tree
---@param tree neotest.Tree
---@param gen_path_filters boolean
---@return string[]
---@return string[]
---@return table<string, string>
local function generate_test_info_for_nodes(tree, gen_path_filters)
    local paths = {}
    local filters = {}
    local position_ids = {}

    for _, _tree in tree:iter_nodes() do
        local _pos = _tree:data()

        if _pos.type == "test" then
            local path, filter, pos_id_key = extract_test_info(_pos)

            if gen_path_filters then
                if not vim.tbl_contains(paths, path) then
                    table.insert(paths, path)
                end

                table.insert(filters, filter)
            end

            position_ids[pos_id_key] = _pos.id
        end
    end

    return paths, filters, position_ids
end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
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

    -- Iterate all tests in the tree and generate position ids for them
    local is_file_pos = pos.type == "file"
    local paths, filters, position_ids = generate_test_info_for_nodes(args.tree, not is_file_pos)

    if is_file_pos then
        -- No need for filters when we are running the entire file
        table.insert(paths, pos.id)
    end

    local results_path = async.fn.tempname() .. ".json"
    local busted = BustedNeotestAdapter.create_busted_command(results_path, paths, filters)

    if not busted then
        local message = "Could not find a busted executable"
        logger.error(message)
        vim.notify(message, vim.log.levels.ERROR)

        return
    end

    local command = vim.list_extend({ command_test_info.nvim_command }, command_test_info.arguments)

    if vim.tbl_islist(args.extra_args) then
        vim.list_extend(busted.command, args.extra_args)
    end

    return {
        command = command,
        context = {
            results_path = results_path,
            pos = pos,
            position_ids = position_ids,
        },
        strategy = get_strategy_config(args.strategy, results_path, paths, filters),
    }
end

---@param test_result neotest-busted.BustedFailureResult | neotest-busted.BustedResult
---@return neotest.Error?
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
        logger.error("Failed to read json test output file ", results_path, " with error: ", data)
        return {}
    end

    ---@diagnostic disable-next-line: cast-local-type
    local json_ok, parsed = pcall(vim.json.decode, data, { luanil = { object = true } })

    if not json_ok then
        logger.error(
            "Failed to parse json test output file ",
            results_path,
            " with error: ",
            parsed
        )
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
        { "successes", types.ResultStatus.passed, false },
        { "pendings", types.ResultStatus.skipped, false },
        { "failures", types.ResultStatus.failed, true },
        { "errors", types.ResultStatus.failed, true },
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
    __call = function(_, user_config)
        config.configure(user_config)

        return BustedNeotestAdapter
    end,
})

return BustedNeotestAdapter
