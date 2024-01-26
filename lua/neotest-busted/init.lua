local async = require("neotest.async")
local lib = require("neotest.lib")
local types = require("neotest.types")

-- Docs:
-- * https://mrcjkb.dev/posts/2023-06-06-luarocks-test.html
-- * https://lunarmodules.github.io/busted/#output-handlers

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
    --busted_command =  "busted",
    busted_args = { "" },
}

--- Find busted command and additional paths
---@return table<string, string>
local function find_busted_command()
    if config.busted_command ~= nil then
        return {
            command = config.busted_command,
            path = config.busted_path,
            cpath = config.busted_cpaths,
        }
    end

    -- Try to find a directory-local busted command
    local globs = vim.fn.split(vim.fn.glob("lua_modules/lib/**/bin/busted"), "\n")

    if #globs > 0 then
        return {
            command = globs[1],
            path = 'lua_modules/share/lua/5.1/?.lua;lua_modules/share/lua/5.1/?/init.lua;;',
            cpath = 'lua_modules/lib/lua/5.1/?.so;;',
        }
    end

    -- Try to find busted in path
    if vim.fn.executable("busted") == 1 then
        return {
            command = "busted",
            path = "",
            cpath = "",
        }
    end

    error("Did not find a busted command")
end

local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)

    return str:match(("(.*%s)"):format(lib.files.sep))
end

local function get_reporter_path()
    return table.concat({ script_path(), "output_handler.lua" })
end

local function join_results(base_result, update)
    if not base_result or not update then
        return base_result or update
    end

    local status = (base_result.status == "failed" or update.status == "failed") and "failed" or "passed"
    local errors = (base_result.errors or update.errors)
        and (vim.list_extend(base_result.errors or {}, update.errors or {}))
        or nil

    return {
        status = status,
        errors = errors,
    }
end

---@param results_path string
---@param paths string[]
---@param filters string[]
local function create_busted_command(results_path, paths, filters)
    local package_paths = [["lua package.path = 'lua_modules/share/lua/5.1/?.lua;lua_modules/share/lua/5.1/?/init.lua;' .. package.path"]]
    local package_cpaths = [["lua package.cpath = 'lua_modules/lib/lua/5.1/?.so;' .. package.cpath"]]
    -- local luarocks_loader = [[lua
-- local key, loader, _ = pcall(require, 'luarocks.loader')
-- _ = key and loader.add_context('busted', '$BUSTED_VERSION')]]

    -- Create a busted command invocation string using neotest-busted's own output handler
    local busted = find_busted_command()
    local busted_command = ("%s --output=%s -Xoutput=%s"):format(
        busted.command,
        get_reporter_path(),
        results_path
    )

    local command = {
        vim.loop.exepath(),
        "--headless",
        "-i", "NONE", -- no shada
        "-n", -- no swapfile, always in-memory
        "-u", "NONE", -- no config file
        "-c", package_paths, -- Add local paths to package.path
        "-c", package_cpaths, -- Add local paths to package.cpath
        -- "-c", luarocks_loader, -- ???
        "-l", busted_command, -- Run busted in neovim ('-l' stops parsing arguments for neovim)
        "--verbose",
    }

    -- Add test filters
    for _, filter in ipairs(filters) do
        table.insert(command, "--filter=" .. "\"" .. filter .. "\"")
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

BustedNeotestAdapter.root = lib.files.match_root_pattern("*.lua")

---@param file_path string
---@return boolean
---@diagnostic disable-next-line: duplicate-set-field
function BustedNeotestAdapter.is_test_file(file_path)
    return vim.endswith(file_path, "_spec.lua")
end

---@diagnostic disable-next-line: duplicate-set-field
function BustedNeotestAdapter.filter_dir(name, rel_path, root)
    return name ~= "lua_modules" and name ~= ".luarocks"
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

    ;; async it blocks (async.it)
    ;; ((function_call
    ;;     name: (
    ;;         dot_index_expression
    ;;         field: (identifier) @func_name
    ;;     )
    ;;     arguments: (arguments (_) @test.name (function_definition))
    ;; ) (#match? @func_name "^it$")) @test.definition
]]

    return lib.treesitter.parse_positions(path, query, { nested_namespaces = true })
end

--- Create a unique key to identify a test
---@param stripped_pos_id string neotest position id stripped of "::"
---@param lnum_start integer
---@param lnum_end integer
---@return string
local function create_pos_id_key(path, stripped_pos_id, lnum_start, lnum_end)
    return ("%s::%s::%d"):format(path, stripped_pos_id, lnum_start)
end
    
---@param args neotest.RunArgs
---@return neotest.RunSpec | nil
---@diagnostic disable-next-line: duplicate-set-field
function BustedNeotestAdapter.build_spec(args)
    local results_path = async.fn.tempname()
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

    vim.print(pos)
    if pos.type == "namespace" or pos.type == "test" then
        local parts = vim.fn.split(pos.id, "::")
        local path = parts[1]
        local stripped_pos_id = table.concat(vim.tbl_map(function(part)
            return vim.fn.trim(part, "\"")
        end, vim.list_slice(parts, 2)), " ")

        table.insert(paths, parts[1])
        table.insert(filters, stripped_pos_id)

        -- Busted creates test names concatenated with spaces so we can't recreate the
        -- position id using "::". Instead create a key stripped of "::" like the one
        -- from busted along with the test line range to uniquely identify the test
        local pos_id_key = create_pos_id_key(
            path,
            stripped_pos_id,
            pos.range[1] + 1,
            pos.range[3] + 1
        )

        position_ids[pos_id_key] = pos.id
    end

    local busted = create_busted_command(results_path, paths, filters)

    return {
        command = busted.command,
        context = {
            results_path = results_path,
            pos = pos,
            position_ids = position_ids,
        },
    }
end

---@param test_result neotest-busted.BustedResult | neotest-busted.BustedFailureResult
---@param status "passed" | "skipped" | "failed"
---@param output string
local function test_result_to_neotest_result(test_result, status, output)
    local pos_id = create_pos_id_key(
        test_result.element.trace.source:sub(2), -- Strip the "@" from the source path
        test_result.name,
        test_result.element.trace.currentline,
        test_result.element.trace.lastlinedefined - 1
    )

    return pos_id, {
        status = status,
        short = ("%s: %s"):format(test_result.name, status),
        output = output,
    }
end

---@async
---@param spec neotest.RunSpec
---@param strategy_result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
---@diagnostic disable-next-line: duplicate-set-field
function BustedNeotestAdapter.results(spec, strategy_result, tree)
    -- TODO: Use an output stream instead if possible
    local _tree

    if tree:data().type == "file" and #tree:children() == 0 then
        _tree = BustedNeotestAdapter.discover_positions(tree:data().path)

        if _tree == nil then
            _tree = tree
        end
    else
        _tree = tree
    end

    -- TODO: Find out if this JSON option is supported in future
    local ok, data = pcall(lib.files.read, spec.context.results_path)
    local test_results ---@type neotest-busted.BustedResultObject

    if ok then
        ---@diagnostic disable-next-line: cast-local-type
        test_results = vim.json.decode(data, { luanil = { object = true } })
    else
        test_results = { errors = {}, pendings = {}, successes = {} }
    end

    vim.print(vim.inspect(test_results))
    vim.print(vim.inspect(spec.context.position_ids))

    local results = {}
    local output = strategy_result.output
    local position_ids = spec.context.position_ids

    ---@cast test_results neotest-busted.BustedResultObject
    for _, value in pairs(test_results.successes) do
        local pos_id_key, result = test_result_to_neotest_result(
            value,
            types.ResultStatus.passed,
            output
        )

        results[position_ids[pos_id_key]] = result
    end

    for _, value in pairs(test_results.failures) do
        local pos_id_key, result = test_result_to_neotest_result(
            value,
            types.ResultStatus.failed,
            output
        )

        -- result.errors = {
        --     {
        --         message = value.trace.message .. value.trace.traceback,
        --         line = value.trace.currentline,
        --     }
        -- }

        results[position_ids[pos_id_key]] = result
    end

    for _, value in pairs(test_results.errors) do
        local pos_id_key, result = test_result_to_neotest_result(
            value,
            types.ResultStatus.failed,
            output
        )

        -- result.errors = {
        --     {
        --         message = value.trace.message .. value.trace.traceback,
        --         line = value.trace.currentline,
        --     }
        -- }

        vim.print(pos_id_key)

        results[position_ids[pos_id_key]] = result
    end

    for _, value in pairs(test_results.pendings) do
        local pos_id_key, result = test_result_to_neotest_result(
            value,
            types.ResultStatus.skipped,
            output
        )

        results[position_ids[pos_id_key]] = result
    end

    vim.print(vim.inspect(results))

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
