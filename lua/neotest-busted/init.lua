local config = require("neotest-busted.config")
local logging = require("neotest-busted.logging")
local util = require("neotest-busted.util")

local async = require("neotest.async")
local lib = require("neotest.lib")
local logger = require("neotest.logging")
local types = require("neotest.types")
local nb_types = require("neotest-busted.types")

local ResultStatus = types.ResultStatus
local BustedResultKey = nb_types.BustedResultKey

---@type neotest.Adapter
local BustedNeotestAdapter = { name = "neotest-busted" }

--- Find busted command and additional paths
---@param ignore_local? boolean
---@return neotest-busted.BustedCommandConfig?
---@diagnostic disable-next-line: inject-field
function BustedNeotestAdapter.find_busted_command(ignore_local)
    if config.busted_command and #config.busted_command > 0 then
        logger.debug("Using busted command from config")

        return {
            type = "config",
            command = config.busted_command,
            lua_paths = {},
            lua_cpaths = {},
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
    return table.concat({ script_path(), "start_debug.lua" })
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

---@param string string
local function quote_string(string)
    return '"' .. string .. '"'
end

---@param paths string[]
---@param options neotest-busted.TestCommandOptions?
---@return neotest-busted.TestCommandConfig?
---@diagnostic disable-next-line: inject-field
function BustedNeotestAdapter.create_busted_command(paths, options)
    local busted = BustedNeotestAdapter.find_busted_command()

    if not busted then
        logging.error("Could not find a busted command")
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

    -- TODO: Should paths be quoted? Try seeing if a path with a space works
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
    }

    if _options.busted_output_handler then
        vim.list_extend(busted_command, {
            "--output",
            _options.busted_output_handler,
        })

        if _options.busted_output_handler_options then
            table.insert(busted_command, "-Xoutput")
            vim.list_extend(busted_command, _options.busted_output_handler_options)
        end
    else
        if _options.results_path then
            vim.list_extend(busted_command, {
                "--output",
                get_reporter_path(),
                "-Xoutput",
                _options.results_path,
            })
        end
    end

    vim.list_extend(arguments, busted_command)

    if vim.tbl_islist(config.busted_args) and #config.busted_args > 0 then
        for _, busted_arg in ipairs(config.busted_args) do
            local arg = _options.quote_strings and '"' .. busted_arg .. '"' or busted_arg

            table.insert(arguments, arg)
        end
    end

    if vim.tbl_islist(_options.busted_arguments) and #_options.busted_arguments > 0 then
        for _, busted_arg in ipairs(_options.busted_arguments) do
            local arg = _options.quote_strings and '"' .. busted_arg .. '"' or busted_arg

            table.insert(arguments, arg)
        end
    end

    -- Add test filters
    for _, filter in ipairs(_options.filters or {}) do
        local _filter = filter

        if _options.quote_strings then
            _filter = quote_string(filter)
        end

        vim.list_extend(arguments, { "--filter", _filter })
    end

    -- Add test files
    if _options.quote_strings then
        vim.list_extend(arguments, vim.tbl_map(quote_string, paths))
    else
        vim.list_extend(arguments, paths)
    end

    return {
        nvim_command = vim.loop.exepath(),
        arguments = arguments,
        paths = lua_paths,
        cpaths = lua_cpaths,
    }
end

---@param strategy string
---@param results_path string
---@param paths string[]
---@param filters string[]
---@return table?
local function get_strategy_config(strategy, results_path, paths, filters)
    if strategy == "dap" then
        local test_command_info = BustedNeotestAdapter.create_busted_command(
            paths,
            -- NOTE: When run via dap, passing arguments such as the one for
            -- busted's '--filter' need to be escaped since the command is run
            -- using node's child_process.spawn with { shell: true } that will
            -- run via a shell and split arguments on spaces. This will break
            -- the command if a filter contains spaces.
            --
            -- On the other hand, we don't need to quote when running the integrated
            -- strategy (through vim.fn.jobstart) because it runs with command as a
            -- list which does not run through a shell
            {
                results_path = results_path,
                filters = filters,
                quote_strings = true,
                busted_arguments = {
                    "--helper",
                    get_debug_start_script(),
                },
            }
        )

        if not test_command_info then
            logging.error("Failed to construct test command for debugging")
            return nil
        end

        local lua_paths = util.normalize_and_create_lua_path(unpack(test_command_info.paths))
        local lua_cpaths = util.normalize_and_create_lua_path(unpack(test_command_info.cpaths))

        return {
            name = "Debug busted tests",
            type = "local-lua",
            cwd = "${workspaceFolder}",
            request = "launch",
            env = {
                LUA_PATH = lua_paths,
                LUA_CPATH = lua_cpaths,
            },
            program = {
                command = test_command_info.nvim_command,
            },
            args = test_command_info.arguments,
        }
    end

    return nil
end

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

    ---@diagnostic disable-next-line: missing-fields
    local tree = lib.treesitter.parse_positions(path, query, { nested_namespaces = true })

    if config.parametric_test_discovery == true then
        require("neotest-busted.busted-util").add_parametric_tests(tree)
    end

    return tree
end

--- Create a unique key from a position to identify a test
---@param position neotest.Position
---@param stripped_pos_id string neotest position id stripped of "::"
---@return string
local function create_pos_id_key_from_position(position, stripped_pos_id)
    local lnum = position.range and position.range[1] + 1 or nil

    ---@diagnostic disable-next-line: undefined-field
    if not lnum and position.real_range then
        ---@diagnostic disable-next-line: undefined-field
        lnum = position.real_range[1] + 1
    end

    return ("%s::%s::%d"):format(position.path, stripped_pos_id, lnum)
end

--- Create a unique key to identify a test
---@param path string
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
local function extract_test_info(pos)
    -- Busted creates test names concatenated with spaces so we can't recreate the
    -- position id using "::". Instead create a key stripped of "::" like the one
    -- from busted along with the path and test range to uniquely identify the test
    local stripped_pos_id = util.strip_position_id(pos.id)

    return stripped_pos_id, create_pos_id_key_from_position(pos, stripped_pos_id)
end

--- Generate test info for the nodes in a tree
---@param tree neotest.Tree
---@return string[]
---@return string[]
local function generate_test_info_for_nodes(tree)
    local filters = {}
    local position = tree:data()
    local position_id_mapping = {}
    local gen_filters = position.type ~= types.PositionType.file

    local function add_filter(filter)
        -- Escape filters first so we can safely add regex start/end anchors
        table.insert(filters, "^" .. escape_test_pattern_filter(filter) .. "$")
    end

    for _, node in tree:iter_nodes() do
        local pos = node:data()

        if pos.type == types.PositionType.test then
            local filter, pos_id_key = extract_test_info(pos)
            vim.print(vim.inspect({ pos.id, pos_id_key }))

            if gen_filters then
                add_filter(filter)
            end

            position_id_mapping[pos_id_key] = pos.id
        end
    end

    return filters, position_id_mapping
end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
---@diagnostic disable-next-line: duplicate-set-field
function BustedNeotestAdapter.build_spec(args)
    local tree = args.tree

    if not tree then
        return
    end

    local pos = tree:data()

    if pos.type == types.PositionType.dir then
        return
    end

    -- Iterate all tests in the tree and generate position ids for them
    local filters, position_id_mapping = generate_test_info_for_nodes(tree)

    local paths = { pos.path }
    local results_path = async.fn.tempname() .. ".json"
    local test_command = BustedNeotestAdapter.create_busted_command(paths, {
        results_path = results_path,
        filters = filters,
        busted_arguments = { "--verbose" },
    })

    if not test_command then
        logging.error("Could not find a busted executable")
        return
    end

    ---@type string[]
    local command = vim.list_extend({ test_command.nvim_command }, test_command.arguments)

    -- Extra arguments for busted
    if vim.tbl_islist(args.extra_args) then
        vim.list_extend(command, args.extra_args)
    end

    return {
        command = command,
        context = {
            results_path = results_path,
            position_id_mapping = position_id_mapping,
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

---@param test_result neotest-busted.BustedResult | neotest-busted.BustedFailureResult | neotest-busted.BustedErrorResult
---@param status neotest.ResultStatus
---@param output string
---@param is_error boolean
local function test_result_to_neotest_result(test_result, status, output, is_error)
    if test_result.isError == true then
        -- This is an internal error in busted, not a test that threw
        return nil, {
            message = test_result.message,
            line = 0,
        }
    end

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
        ---@cast test_result -neotest-busted.BustedErrorResult
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
    local results_path = spec.context.results_path
    local ok, data = pcall(lib.files.read, results_path)

    if not ok then
        logging.error(
            "Failed to read json test output file %s with error: %s",
            nil,
            results_path,
            data
        )
        return {}
    end

    ---@diagnostic disable-next-line: cast-local-type
    local json_ok, test_results = pcall(vim.json.decode, data, { luanil = { object = true } })

    if not json_ok then
        logging.error(
            "Failed to parse json test output file %s with error: %s",
            nil,
            results_path,
            test_results
        )
        return {}
    end

    ---@cast test_results neotest-busted.BustedResultObject

    ---@type neotest-busted.BustedResultObject
    ---@diagnostic disable-next-line: assign-type-mismatch

    local results = {}
    local output = strategy_result.output
    local position_id_mapping = spec.context.position_id_mapping

    ---@type { [1]: neotest-busted.BustedResultKey, [2]: neotest.ResultStatus }[]
    local test_types = {
        { BustedResultKey.successes, ResultStatus.passed },
        { BustedResultKey.pendings, ResultStatus.skipped },
        { BustedResultKey.failures, ResultStatus.failed },
        { BustedResultKey.errors, ResultStatus.failed },
    }

    for _, test_type in ipairs(test_types) do
        local test_key, result_status = test_type[1], test_type[2]
        local is_error = test_key == BustedResultKey.failures
            or test_key == BustedResultKey.errors

        for _, value in pairs(test_results[test_key]) do
            local pos_id_key, result =
                test_result_to_neotest_result(value, result_status, output, is_error)
            local pos_id = position_id_mapping[pos_id_key]

            if not pos_id then
                logging.error(
                    "Failed to find matching position id for key %s",
                    nil,
                    pos_id_key
                )
            else
                results[pos_id] = result
            end
        end
    end

    -- local unexpanded_tests = spec.context.unexpanded_tests

    -- -- Unexpanded tests (parametric tests in source code) won't a
    -- -- representation at runtime so instead generate the results
    -- -- manually based on the results of the expanded tests
    -- if unexpanded_tests and vim.tbl_count(unexpanded_tests) > 0 then
    --     for unexpanded_key, parametric_tests in pairs(spec.context.unexpanded_tests) do
    --         local status = ResultStatus.passed

    --         for _, test in ipairs(parametric_tests) do
    --             local new_status = results[test.id].status

    --             if new_status ~= ResultStatus.passed then
    --                 status = new_status
    --             end

    --             local temp = vim.split(unexpanded_key, "::")
    --             local name = temp[#temp]

    --             results[unexpanded_key] = {
    --                 status = status,
    --                 short = ("%s: %s"):format(name, status),
    --                 output = output,
    --             }
    --         end
    --     end
    -- end

    -- If the test itself was parametric and all tests passed then mark it
    -- as passed as well so neotest will mark it as passed
    -- if spec.context.is_parametric and all_pass then
    --     local pos = tree:data()

    --     results[pos.id] = {
    --         status = ResultStatus.passed,
    --         short = ("%s: %s"):format(pos.name, ResultStatus.passed),
    --         output = output,
    --     }
    -- end

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
