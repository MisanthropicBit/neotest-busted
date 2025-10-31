local Cache = require("neotest-busted.cache")
local compat = require("neotest-busted.compat")
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
---@diagnostic disable-next-line: missing-fields
local BustedNeotestAdapter = { name = "neotest-busted" }

--- Find busted command and additional paths
---@param ignore_local? boolean
---@return neotest-busted.BustedCommandConfig?
---@diagnostic disable-next-line: inject-field
function BustedNeotestAdapter.find_busted_command(ignore_local)
    -- NOTE: We could alternatively just run `luarocks path --lr-path` and
    -- `luarocks path --lr-cpath` and get the correct paths in the correct
    -- filesystem context but they fall back to user-local and system-level
    -- installations so we might not want to do that

    if config.busted_command and #config.busted_command > 0 then
        logger.debug("Using busted command from config")

        -- We do not know what kind of luarocks installation the user-provided
        -- busted command belongs to, it might not even be installed via
        -- luarocks, so for now we just return empty paths
        return {
            type = "config",
            no_nvim = config.no_nvim,
            command = config.busted_command,
            lua_paths = {},
            lua_cpaths = {},
        }
    end

    if not ignore_local then
        -- Try to find a directory-local busted executable. Assume busted is
        -- installed if we can find the script
        -- NOTE: We could also run `luarocks list busted --porcelain` instead
        local local_globs = util.glob(
            util.create_path(
                "lua_modules",
                "lib",
                "luarocks",
                "rocks-5.1",
                "busted",
                "**",
                "bin",
                "busted"
            )
        )

        if #local_globs > 0 then
            logger.debug("Using project-local busted executable")

            return {
                type = "project",
                no_nvim = config.no_nvim,
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

    -- Only skip checking further installations if we are not doing the healthcheck
    if not ignore_local and config.local_luarocks_only == true then
        return nil
    end

    -- Try to find a local (user home directory) busted executable. Assume
    -- busted is installed if we can find the script
    local user_globs = util.glob(
        util.create_path(
            "~",
            ".luarocks",
            "lib",
            "luarocks",
            "rocks-5.1",
            "busted",
            "**",
            "bin",
            "busted"
        )
    )

    if #user_globs > 0 then
        logger.debug("Using local (~/.luarocks) busted executable")

        return {
            type = "user",
            no_nvim = config.no_nvim,
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

    -- Try to find a global busted executable. Assume busted is installed if we
    -- can find the script
    local global_globs = util.glob(
        util.create_path("/usr", "local", "lib", "luarocks", "rocks-5.1", "**", "bin", "busted")
    )

    if #global_globs > 0 then
        logger.debug("Using global busted executable")

        return {
            type = "global",
            no_nvim = config.no_nvim,
            lua_paths = {
                util.create_path("/usr", "local", "share", "lua", "5.1", "?.lua"),
                util.create_path("/usr", "local", "share", "lua", "5.1", "?", "init.lua"),
            },
            lua_cpaths = {
                util.create_path("/usr", "local", "lib", "lua", "5.1", "?.so"),
                util.create_path("/usr", "local", "lib", "lua", "5.1", "?", "?.so"),
            },
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

---@param busted_config neotest-busted.BustedCommandConfig
---@return string[]
---@return string[]
local function get_lua_paths(busted_config)
    local lua_paths, lua_cpaths = {}, {}

    if compat.tbl_islist(config.busted_paths) then
        vim.list_extend(lua_paths, config.busted_paths)
    end

    if compat.tbl_islist(config.busted_cpaths) then
        vim.list_extend(lua_cpaths, config.busted_cpaths)
    end

    -- Append paths so busted can find the plugin files
    table.insert(lua_paths, util.create_path("lua", "?.lua"))
    table.insert(lua_paths, util.create_path("lua", "?", "init.lua"))

    -- Add paths for busted
    vim.list_extend(lua_paths, busted_config.lua_paths)
    vim.list_extend(lua_cpaths, busted_config.lua_cpaths)

    return lua_paths, lua_cpaths
end

---@param lua_paths string[]
---@param lua_cpaths string[]
---@return string[]
local function get_nvim_arguments(lua_paths, lua_cpaths)
    -- stylua: ignore start
    ---@type string[]
    local arguments = {
        "--headless",
        "-i", "NONE", -- no shada
        "-n", -- no swapfile, always in-memory
        "-u", find_minimal_init() or "NONE",
    }
    -- stylua: ignore end

    -- Create '-c' arguments for updating package paths in neovim
    vim.list_extend(arguments, util.create_package_path_argument("package.path", lua_paths))
    vim.list_extend(arguments, util.create_package_path_argument("package.cpath", lua_cpaths))

    return arguments
end

---@param paths string[]
---@param options neotest-busted.TestCommandOptions?
---@return neotest-busted.TestCommandConfig?
---@diagnostic disable-next-line: inject-field
function BustedNeotestAdapter.create_test_command(paths, options)
    local busted_config = BustedNeotestAdapter.find_busted_command()

    if not busted_config then
        logging.error("Could not find a busted installation")
        return
    end

    local arguments = {}
    local _options = options or {}
    local busted_command = busted_config.command
        or util.get_path_to_plugin_file("busted-cli-runner.lua")

    local lua_paths, lua_cpaths = get_lua_paths(busted_config)
    if not config.no_nvim then
        arguments = get_nvim_arguments(lua_paths, lua_cpaths)
        vim.list_extend(arguments, {
            "-l",
            busted_command,
        })
    end

    if _options.busted_output_handler then
        vim.list_extend(arguments, {
            "--output",
            _options.busted_output_handler,
        })

        if _options.busted_output_handler_options then
            table.insert(arguments, "-Xoutput")
            vim.list_extend(arguments, _options.busted_output_handler_options)
        end
    else
        if _options.results_path then
            vim.list_extend(arguments, {
                "--output",
                util.get_path_to_plugin_file("output_handler.lua"),
                "-Xoutput",
                _options.results_path,
            })
        end
    end

    if compat.tbl_islist(config.busted_args) then
        for _, busted_arg in ipairs(config.busted_args) do
            local arg = _options.quote_strings and quote_string(busted_arg) or busted_arg

            table.insert(arguments, arg)
        end
    end

    if compat.tbl_islist(_options.busted_arguments) then
        for _, busted_arg in ipairs(_options.busted_arguments) do
            local arg = _options.quote_strings and quote_string(busted_arg) or busted_arg

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
        command = config.no_nvim and busted_command or compat.loop.exepath(),
        arguments = arguments,
        set_env = config.no_nvim,
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
        local test_command_info = BustedNeotestAdapter.create_test_command(
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
                    util.get_path_to_plugin_file("helper_scripts/start_debug.lua"),
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
                command = test_command_info.command,
            },
            args = test_command_info.arguments,
        }
    end

    return nil
end

BustedNeotestAdapter.root = function(path)
    return lib.files.match_root_pattern(".busted", ".luarocks", "lua_modules", "*.rockspec")(path)
end

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

local parametric_test_cache = Cache.new()

--- Only use in testing
---@package
---@return neotest-busted.Cache
---@diagnostic disable-next-line: inject-field
function BustedNeotestAdapter.get_parametric_test_cache()
    return parametric_test_cache
end

local function get_match_type(captured_nodes)
    if captured_nodes["test.name"] then
        return "test"
    end

    if captured_nodes["namespace.name"] then
        return "namespace"
    end
end

---@param file_path string
---@param source string
---@param captured_nodes any
---@return table?
---@diagnostic disable-next-line: inject-field
function BustedNeotestAdapter.build_position(file_path, source, captured_nodes)
    local match_type = get_match_type(captured_nodes)

    if not match_type then
        return
    end

    ---@type TSNode
    local node = captured_nodes[match_type .. ".name"]
    local name = vim.treesitter.get_node_text(node, source)
    local type = node:type()

    -- If the node is a string then strip the quotes from the name
    -- by getting it's first named child (string_content). This works
    -- for single-, double-, and literal quotes and is necssary
    -- since we generate neotest position ids in the output handler
    -- which cannot know what quotes a test was written with
    if type == "string" then
        local content = node:named_child(0)

        if content then
            name = vim.treesitter.get_node_text(content, source)
        end
    end

    local definition = captured_nodes[match_type .. ".definition"]

    return {
        type = match_type,
        path = file_path,
        name = name,
        range = { definition:range() },
    }
end

---@async
---@return neotest.Tree | nil
---@diagnostic disable-next-line: duplicate-set-field
function BustedNeotestAdapter.discover_positions(path)
    local query = [[
    ;; describe blocks
    ((function_call
        name: (identifier) @func_name (#any-of? @func_name "describe" "context" "insulate" "expose")
        arguments: (arguments (_) @namespace.name (function_definition))
    )) @namespace.definition

    ;; it blocks
    ((function_call
        name: (identifier) @func_name
        arguments: (arguments (_) @test.name (function_definition))
    ) (#any-of? @func_name "it" "test" "spec")) @test.definition

    ;; pending blocks
    ((function_call
        name: (identifier) @func_name
        arguments: (arguments (string) @test.name)
    ) (#eq? @func_name "pending")) @test.definition

    ;; nvim-nio async blocks
    ((function_call
        name: (
            dot_index_expression
                table: (_)
                field: (identifier)
        ) @func_name
        arguments: (arguments (_) @test.name (function_definition))
    ) (#any-of? @func_name "async.it" "nio.tests.it" "a.it")) @test.definition

    ;; custom async blocks
    ((function_call
        name: (identifier) @func_name
        arguments: (arguments (_) @test.name (function_call
            name: (identifier) @async (#eq? @async "async")
        ))
    ) (#any-of? @func_name "it" "test" "spec")) @test.definition
]]

    -- Lua-ls does not understand that neotest.lib.treesitter.ParseOptions
    -- inherits from neotest.lib.positions.ParseOptions
    ---@diagnostic disable-next-line: missing-fields
    local tree = lib.treesitter.parse_positions(path, query, {
        nested_tests = true,
        ---@diagnostic disable-next-line: assign-type-mismatch
        build_position = 'require("neotest-busted").build_position',
    })

    -- TODO: Evict cache entries based on absolute file paths
    if config.parametric_test_discovery == true then
        local busted_util = require("neotest-busted.busted-util")
        local parametric_tests = busted_util.discover_parametric_tests(tree)

        for id, tests in pairs(parametric_tests) do
            parametric_test_cache:update(id, tests)
        end
    end

    return tree
end

---@param position neotest.Position
---@return boolean
local function is_parametric_test(position)
    ---@diagnostic disable-next-line: undefined-field
    return position.lnum ~= nil
end

--- Extract test info from a position
---@param pos neotest.Position
---@return string
local function filter_from_position(pos)
    -- Busted creates test names concatenated with spaces so we can't recreate the
    -- position id using "::". Instead create a key stripped of "::" like the one
    -- from busted along with the path and test range to uniquely identify the test
    local _, stripped_pos_id = util.strip_position_id(pos.id)

    return stripped_pos_id
end

--- Create command line filters for the nodes in a tree
---@param tree neotest.Tree
---@return string[]
local function create_filters_for_tree(tree)
    local filters = {}
    local position = tree:data()

    -- We do not need to generate cli filters when running an entire file
    if position.type == types.PositionType.file then
        return filters
    end

    ---@param pos neotest.Position
    local function add_filter(pos)
        local filter = filter_from_position(pos)

        -- Escape filters first so we can safely add regex start/end anchors
        table.insert(filters, "^" .. escape_test_pattern_filter(filter) .. "$")
    end

    if is_parametric_test(position) then
        -- This is a parametric test. Running one directly like this can occur
        -- when it is run from the neotest summary after being added to the tree
        add_filter(position)

        return filters
    end

    for _, node in tree:iter_nodes() do
        local pos = node:data()

        if pos.type == types.PositionType.test then
            local parametric_tests = parametric_test_cache:get(pos.id)
            local positions = parametric_tests or { pos }

            for _, _pos in ipairs(positions) do
                add_filter(_pos)
            end
        end
    end

    return filters
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
    local filters = create_filters_for_tree(tree)

    local paths = { pos.path }
    local results_path = async.fn.tempname() .. ".json"
    local test_command = BustedNeotestAdapter.create_test_command(paths, {
        results_path = results_path,
        filters = filters,
        busted_arguments = { "--verbose" },
    })

    if not test_command then
        logging.error("Could not find a busted executable")
        return
    end

    ---@type string[]
    local command = vim.list_extend({ test_command.command }, test_command.arguments)

    -- Extra arguments for busted
    if compat.tbl_islist(args.extra_args) then
        vim.list_extend(command, args.extra_args)
    end

    local env = nil
    if test_command.set_env then
        local lua_path = util.normalize_and_create_lua_path(unpack(test_command.paths))
        if vim.env.LUA_PATH ~= "" then
            lua_path = string.format("%s;%s", lua_path, vim.env.LUA_PATH)
        end
        local lua_cpath = util.normalize_and_create_lua_path(unpack(test_command.cpaths))
        if vim.env.LUA_CPATH ~= "" then
            lua_cpath = string.format("%s;%s", lua_cpath, vim.env.LUA_CPATH)
        end
        env = {
            LUA_PATH = lua_path,
            LUA_CPATH = lua_cpath,
        }
    end

    return {
        command = command,
        env = env,
        context = { results_path = results_path },
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

---@param status neotest.ResultStatus
---@param test_result neotest-busted.BustedResult | neotest-busted.BustedFailureResult | neotest-busted.BustedErrorResult
---@param output string
---@return neotest.Result
local function convert_test_result_to_neotest_result(status, test_result, output)
    if test_result.isError == true then
        -- This is an internal error in busted, not a test that threw
        return {
            message = test_result.message,
            line = 0,
        }
    end

    local result = {
        status = status,
        short = ("%s: %s"):format(test_result.element.name, status),
        output = output,
    }

    if status == ResultStatus.failed then
        ---@cast test_result -neotest-busted.BustedErrorResult
        result.errors = create_error_info(test_result)
    end

    return result
end

--- Convert busted test results to neotest test results
---@param test_results_json neotest-busted.BustedResultObject
---@param output string
---@return table<string, neotest.Result>
local function convert_test_results_to_neotest_results(test_results_json, output)
    local results = {}

    ---@type table<neotest-busted.BustedResultKey, neotest.ResultStatus>
    local test_types = {
        [BustedResultKey.successes] = ResultStatus.passed,
        [BustedResultKey.pendings] = ResultStatus.skipped,
        [BustedResultKey.failures] = ResultStatus.failed,
        [BustedResultKey.errors] = ResultStatus.failed,
    }

    for busted_result_key, test_results in pairs(test_results_json) do
        if busted_result_key == BustedResultKey.duration then
            goto continue
        end

        ---@cast busted_result_key neotest-busted.BustedResultKey

        for _, test_result in ipairs(test_results) do
            ---@cast test_result neotest-busted.BustedResult | neotest-busted.BustedFailureResult

            local result = convert_test_result_to_neotest_result(
                test_types[busted_result_key],
                test_result,
                output
            )

            local pos_id = test_result.neotestPositionId

            if pos_id then
                results[pos_id] = result
            else
                logging.error(
                    "Failed to generate neotest position id in output handler for test '%s'",
                    nil,
                    test_result.name
                )
            end
        end

        ::continue::
    end

    return results
end

--- Add any parametric tests that were run to the tree if they have not already been added
---@param tree neotest.Tree
local function update_parametric_tests_in_tree(tree)
    local position = tree:data()
    local parametric_test_map = {}
    local cached_parametric_tests = parametric_test_cache:get(position.id)

    if cached_parametric_tests then
        parametric_test_map[position.id] = cached_parametric_tests
    else
        -- We did not find anything in the cache which can happen when a
        -- namespace (describe) or file test was run as we only cache per test
        -- position
        for _, node in tree:iter_nodes() do
            local pos = node:data()

            if pos.type == types.PositionType.test then
                local cache_result = parametric_test_cache:get(pos.id)

                if cache_result then
                    parametric_test_map[pos.id] = cache_result
                end
            end
        end
    end

    if vim.tbl_count(parametric_test_map) > 0 then
        -- Iterate all parametric tests and add them as range-less (range = nil) children
        -- of the unexpanded test if not already in the tree
        --
        -- https://github.com/nvim-neotest/neotest/pull/172
        for orig_pos_id, parametric_tests in pairs(parametric_test_map) do
            for _, parametric_test in ipairs(parametric_tests) do
                local pos_id = parametric_test.id

                if not tree:get_key(pos_id) then
                    -- WARNING: The following code relies on neotest internals

                    ---@diagnostic disable-next-line: invisible
                    local new_tree = types.Tree:new(parametric_test, {}, tree._key, nil, nil)

                    ---@diagnostic disable-next-line: invisible
                    tree:get_key(orig_pos_id):add_child(pos_id, new_tree)
                end
            end
        end
    end
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
    local json_ok, test_results_json = pcall(vim.json.decode, data, { luanil = { object = true } })

    if not json_ok then
        logging.error(
            "Failed to parse json test output file %s with error: %s",
            nil,
            results_path,
            test_results_json
        )
        return {}
    end

    ---@cast test_results_json neotest-busted.BustedResultObject

    local results =
        convert_test_results_to_neotest_results(test_results_json, strategy_result.output)

    if config.parametric_test_discovery == true then
        update_parametric_tests_in_tree(tree)

        local status = ResultStatus.passed

        -- Aggregate result status and create a fake result for the target position
        for _, result in pairs(results) do
            if result.status ~= ResultStatus.passed then
                status = result.status
            end
        end

        local position = tree:data()

        if position.type == types.PositionType.test then
            results[position.id] = {
                status = status,
                short = ("%s: %s"):format(position.name, status),
                output = strategy_result.output,
            }
        end
    end

    return results
end

setmetatable(BustedNeotestAdapter, {
    ---@param user_config neotest-busted.Config?
    ---@return neotest.Adapter
    __call = function(_, user_config)
        config.configure(user_config)

        return BustedNeotestAdapter
    end,
})

return BustedNeotestAdapter
