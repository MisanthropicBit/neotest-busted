local _async = require("neotest.async")
-- local logger = require("neotest.logging")
local Tree = require("neotest.types").Tree
local stub = require("luassert.stub")

local async = _async.tests

describe("adapter.build_spec", function()
    before_each(function()
        stub(vim.api, "nvim_echo")
    end)

    after_each(function()
        vim.api.nvim_echo:revert()
    end)

    local function assert_spec_command(spec_command, items)
        assert.are.same(#spec_command, #items)

        local idx = 1

        while idx <= #items do
            local item = items[idx]
            assert.are.same(spec_command[idx], item)
            idx = idx + 1

            -- Handle a different path when running in github actions
            if item == "--output" then
                assert.is_true(
                    vim.endswith(spec_command[idx], "lua/neotest-busted/output_handler.lua")
                )
                idx = idx + 1
            elseif item == '"--helper"' then
                assert.is_true(
                    vim.endswith(spec_command[idx], 'lua/neotest-busted/start_debug.lua"')
                )
                idx = idx + 1
            end
        end
    end

    ---@param adapter neotest.Adapter
    ---@return neotest.Tree
    local function create_tree(adapter)
        local positions = adapter.discover_positions("./test_files/test1_spec.lua"):to_list()

        return Tree.from_list(positions, function(pos)
            return pos.id
        end)
    end

    before_each(function()
        stub(_async.fn, "tempname", "test-output")
        stub(vim, "notify")
    end)

    after_each(function()
        _async.fn.tempname:revert()
        vim.notify:revert()
    end)

    async.it("builds command for file test", function()
        package.loaded["neotest-busted"] = nil

        local busted_paths = { "~/.luarocks/share/lua/5.1/?.lua" }
        local busted_cpaths = { "~/.luarocks/lib/lua/5.1/?.so" }

        local adapter = require("neotest-busted")({
            busted_command = "./busted",
            busted_args = { "--shuffle-lists" },
            busted_paths = busted_paths,
            busted_cpaths = busted_cpaths,
            minimal_init = nil,
        })
        local tree = create_tree(adapter)
        local spec = adapter.build_spec({ tree = tree })

        assert.is_not_nil(spec)

        local lua_paths = table.concat({
            vim.fs.normalize(busted_paths[1]),
            "lua/?.lua",
            "lua/?/init.lua",
        }, ";")

        assert_spec_command(spec.command, {
            vim.loop.exepath(),
            "--headless",
            "-i",
            "NONE",
            "-n",
            "-u",
            "tests/minimal_init.lua",
            "-c",
            ("lua package.path = '%s;' .. package.path"):format(lua_paths),
            "-c",
            ("lua package.cpath = '%s;' .. package.cpath"):format(
                vim.fs.normalize(busted_cpaths[1])
            ),
            "-l",
            "./busted",
            "--verbose",
            "--output",
            "./lua/neotest-busted/output_handler.lua",
            "-Xoutput",
            "test-output.json",
            "--shuffle-lists",
            "./test_files/test1_spec.lua",
        })

        assert.are.same(spec.context, {
            results_path = "test-output.json",
            pos = {
                id = "./test_files/test1_spec.lua",
                name = "test1_spec.lua",
                path = "./test_files/test1_spec.lua",
                range = { 0, 0, 21, 0 },
                type = "file",
            },
            position_ids = {
                ["./test_files/test1_spec.lua::top-level namespace 1 nested namespace 1 test 1::3"] = './test_files/test1_spec.lua::"top-level namespace 1"::"nested namespace 1"::"test 1"',
                ["./test_files/test1_spec.lua::top-level namespace 1 nested namespace 1 test 2::7"] = './test_files/test1_spec.lua::"top-level namespace 1"::"nested namespace 1"::"test 2"',
                ["./test_files/test1_spec.lua::^top-le[ve]l (na*m+e-sp?ac%e) 2$ test 3::14"] = './test_files/test1_spec.lua::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 3"',
                ["./test_files/test1_spec.lua::^top-le[ve]l (na*m+e-sp?ac%e) 2$ test 4::18"] = './test_files/test1_spec.lua::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 4"',
            },
        })
    end)

    async.it("builds command for namespace test", function()
        package.loaded["neotest-busted"] = nil

        local adapter = require("neotest-busted")({
            busted_command = "./busted",
            busted_args = {},
            busted_paths = nil,
            busted_cpaths = nil,
            minimal_init = nil,
        })
        local tree = create_tree(adapter)
        local spec = adapter.build_spec({ tree = tree:children()[1]:children()[1] })

        assert.is_not_nil(spec)

        assert_spec_command(spec.command, {
            vim.loop.exepath(),
            "--headless",
            "-i",
            "NONE",
            "-n",
            "-u",
            "tests/minimal_init.lua",
            "-c",
            "lua package.path = 'lua/?.lua;lua/?/init.lua;' .. package.path",
            "-l",
            "./busted",
            "--verbose",
            "--output",
            "./lua/neotest-busted/output_handler.lua",
            "-Xoutput",
            "test-output.json",
            "--filter",
            "top%-level namespace 1 nested namespace 1 test 1",
            "--filter",
            "top%-level namespace 1 nested namespace 1 test 2",
            "./test_files/test1_spec.lua",
        })

        assert.are.same(spec.context, {
            results_path = "test-output.json",
            pos = {
                id = './test_files/test1_spec.lua::"top-level namespace 1"::"nested namespace 1"',
                name = '"nested namespace 1"',
                path = "./test_files/test1_spec.lua",
                range = { 1, 4, 9, 8 },
                type = "namespace",
            },
            position_ids = {
                ["./test_files/test1_spec.lua::top-level namespace 1 nested namespace 1 test 1::3"] = './test_files/test1_spec.lua::"top-level namespace 1"::"nested namespace 1"::"test 1"',
                ["./test_files/test1_spec.lua::top-level namespace 1 nested namespace 1 test 2::7"] = './test_files/test1_spec.lua::"top-level namespace 1"::"nested namespace 1"::"test 2"',
            },
        })
    end)

    async.it("builds command for test", function()
        package.loaded["neotest-busted"] = nil

        local adapter = require("neotest-busted")({
            busted_command = "./busted",
            busted_args = {},
            busted_paths = nil,
            busted_cpaths = nil,
            minimal_init = nil,
        })
        local tree = create_tree(adapter)
        local spec = adapter.build_spec({
            tree = tree:children()[1]:children()[1]:children()[1],
        })

        assert.is_not_nil(spec)

        assert_spec_command(spec.command, {
            vim.loop.exepath(),
            "--headless",
            "-i",
            "NONE",
            "-n",
            "-u",
            "tests/minimal_init.lua",
            "-c",
            "lua package.path = 'lua/?.lua;lua/?/init.lua;' .. package.path",
            "-l",
            "./busted",
            "--verbose",
            "--output",
            "./lua/neotest-busted/output_handler.lua",
            "-Xoutput",
            "test-output.json",
            "--filter",
            "top%-level namespace 1 nested namespace 1 test 1",
            "./test_files/test1_spec.lua",
        })

        assert.are.same(spec.context, {
            results_path = "test-output.json",
            pos = {
                id = './test_files/test1_spec.lua::"top-level namespace 1"::"nested namespace 1"::"test 1"',
                name = '"test 1"',
                path = "./test_files/test1_spec.lua",
                range = { 2, 8, 4, 12 },
                type = "test",
            },
            position_ids = {
                ["./test_files/test1_spec.lua::top-level namespace 1 nested namespace 1 test 1::3"] = './test_files/test1_spec.lua::"top-level namespace 1"::"nested namespace 1"::"test 1"',
            },
        })
    end)

    async.it("builds command for test with extra arguments", function()
        package.loaded["neotest-busted"] = nil

        local adapter = require("neotest-busted")({
            busted_command = "./busted",
            busted_args = {},
            busted_paths = nil,
            busted_cpaths = nil,
            minimal_init = nil,
        })
        local tree = create_tree(adapter)
        local spec = adapter.build_spec({
            tree = tree:children()[1]:children()[1]:children()[1],
            extra_args = { "--no-enable-sound", "--no-sort" },
        })

        assert.is_not_nil(spec)

        assert_spec_command(spec.command, {
            vim.loop.exepath(),
            "--headless",
            "-i",
            "NONE",
            "-n",
            "-u",
            "tests/minimal_init.lua",
            "-c",
            "lua package.path = 'lua/?.lua;lua/?/init.lua;' .. package.path",
            "-l",
            "./busted",
            "--verbose",
            "--output",
            "./lua/neotest-busted/output_handler.lua",
            "-Xoutput",
            "test-output.json",
            "--filter",
            "top%-level namespace 1 nested namespace 1 test 1",
            "./test_files/test1_spec.lua",
            "--no-enable-sound",
            "--no-sort",
        })

        assert.are.same(spec.context, {
            results_path = "test-output.json",
            pos = {
                id = './test_files/test1_spec.lua::"top-level namespace 1"::"nested namespace 1"::"test 1"',
                name = '"test 1"',
                path = "./test_files/test1_spec.lua",
                range = { 2, 8, 4, 12 },
                type = "test",
            },
            position_ids = {
                ["./test_files/test1_spec.lua::top-level namespace 1 nested namespace 1 test 1::3"] = './test_files/test1_spec.lua::"top-level namespace 1"::"nested namespace 1"::"test 1"',
            },
        })
    end)

    async.it("escapes special characters in pattern in command", function()
        package.loaded["neotest-busted"] = nil

        local adapter = require("neotest-busted")({
            busted_command = "./busted",
            minimal_init = "custom_init.lua",
        })
        local tree = create_tree(adapter)
        local spec = adapter.build_spec({ tree = tree:children()[2]:children()[1] })

        assert.is_not_nil(spec)

        assert_spec_command(spec.command, {
            vim.loop.exepath(),
            "--headless",
            "-i",
            "NONE",
            "-n",
            "-u",
            "custom_init.lua",
            "-c",
            "lua package.path = 'lua/?.lua;lua/?/init.lua;' .. package.path",
            "-l",
            "./busted",
            "--verbose",
            "--output",
            "./lua/neotest-busted/output_handler.lua",
            "-Xoutput",
            "test-output.json",
            "--filter",
            [[%^top%-le%[ve]l %(na%*m%+e%-sp%?ac%%e%) 2%$ test 3]],
            "./test_files/test1_spec.lua",
        })

        assert.are.same(spec.context, {
            results_path = "test-output.json",
            pos = {
                id = './test_files/test1_spec.lua::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 3"',
                name = '"test 3"',
                path = "./test_files/test1_spec.lua",
                range = { 13, 4, 15, 8 },
                type = "test",
            },
            position_ids = {
                ["./test_files/test1_spec.lua::^top-le[ve]l (na*m+e-sp?ac%e) 2$ test 3::14"] = './test_files/test1_spec.lua::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 3"',
            },
        })
    end)

    async.it("builds command for debugging file test", function()
        package.loaded["neotest-busted"] = nil

        local busted_paths = { "~/.luarocks/share/lua/5.1/?.lua" }
        local busted_cpaths = { "~/.luarocks/lib/lua/5.1/?.so" }

        local adapter = require("neotest-busted")({
            busted_command = "./busted",
            busted_args = { "--shuffle-lists" },
            busted_paths = busted_paths,
            busted_cpaths = busted_cpaths,
            minimal_init = nil,
        })
        local tree = create_tree(adapter)
        local spec = adapter.build_spec({ tree = tree, strategy = "dap" })

        assert.is_not_nil(spec)

        local lua_paths = table.concat({
            vim.fs.normalize(busted_paths[1]),
            "lua/?.lua",
            "lua/?/init.lua",
        }, ";")

        local arguments = {
            "--headless",
            "-i",
            "NONE",
            "-n",
            "-u",
            "tests/minimal_init.lua",
            "-c",
            ("lua package.path = '%s;' .. package.path"):format(lua_paths),
            "-c",
            ("lua package.cpath = '%s;' .. package.cpath"):format(
                vim.fs.normalize(busted_cpaths[1])
            ),
            "-l",
            "./busted",
            "--verbose",
            "--output",
            "./lua/neotest-busted/output_handler.lua",
            "-Xoutput",
            "test-output.json",
            "--shuffle-lists",
            "./test_files/test1_spec.lua",
        }

        assert_spec_command(spec.command, vim.list_extend({ vim.loop.exepath() }, arguments))

        assert.are.same(spec.context, {
            results_path = "test-output.json",
            pos = {
                id = "./test_files/test1_spec.lua",
                name = "test1_spec.lua",
                path = "./test_files/test1_spec.lua",
                range = { 0, 0, 21, 0 },
                type = "file",
            },
            position_ids = {
                ["./test_files/test1_spec.lua::top-level namespace 1 nested namespace 1 test 1::3"] = './test_files/test1_spec.lua::"top-level namespace 1"::"nested namespace 1"::"test 1"',
                ["./test_files/test1_spec.lua::top-level namespace 1 nested namespace 1 test 2::7"] = './test_files/test1_spec.lua::"top-level namespace 1"::"nested namespace 1"::"test 2"',
                ["./test_files/test1_spec.lua::^top-le[ve]l (na*m+e-sp?ac%e) 2$ test 3::14"] = './test_files/test1_spec.lua::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 3"',
                ["./test_files/test1_spec.lua::^top-le[ve]l (na*m+e-sp?ac%e) 2$ test 4::18"] = './test_files/test1_spec.lua::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 4"',
            },
        })

        local debug_arguments = vim.list_slice(arguments, 1, #arguments - 1)
        vim.list_extend(debug_arguments, {
            '"./test_files/test1_spec.lua"',
            '"--helper"',
            '"./lua/neotest-busted/start_debug.lua"',
        })

        local strategy_keys = vim.tbl_keys(spec.strategy)
        table.sort(strategy_keys)

        assert.are.same(strategy_keys, {
            "args",
            "cwd",
            "env",
            "name",
            "program",
            "request",
            "type",
        })

        assert.are.same(spec.strategy.name, "Debug busted tests")
        assert.are.same(spec.strategy.type, "local-lua")
        assert.are.same(spec.strategy.cwd, "${workspaceFolder}")
        assert.are.same(spec.strategy.request, "launch")
        assert.are.same(spec.strategy.env, {
            LUA_PATH = lua_paths,
            LUA_CPATH = vim.fs.normalize(busted_cpaths[1]),
        })
        assert.are.same(spec.strategy.program, {
            command = vim.loop.exepath(),
        })

        assert_spec_command(spec.strategy.args, debug_arguments)
    end)

    -- async.it("handles failure to find a busted command", function()
    --     adapter({
    --         busted_command = false,
    --         busted_args = {},
    --         busted_paths = false,
    --         busted_cpaths = false
    --     })
    --     stub(vim.fn, "glob", "")
    --     stub(vim.fn, "executable", 0)
    --     stub(vim, "notify")
    --     stub(logger, "debug")
    --     stub(logger, "error")

    --     local message = "Could not find a busted executable"

    --     assert.is_nil(adapter.build_spec({ tree = nil }))
    --     vim.print(vim.notify)
    --     assert.stub(vim.notify).was.called_with(message, vim.log.levels.ERROR)
    --     assert.stub(logger.debug).was.not_called()
    --     -- assert.stub(logger.error).was.called_with({ message })

    --     vim.fn.glob:revert()
    --     vim.fn.executable:revert()
    --     vim.notify:revert()
    --     logger:debug()
    --     logger:error()
    -- end)

    async.it("builds nothing if no tree", function()
        package.loaded["neotest-busted"] = nil

        local adapter = require("neotest-busted")({
            busted_command = "./busted",
            minimal_init = "custom_init.lua",
        })

        assert.is_nil(adapter.build_spec({ tree = nil }))
    end)

    -- async.it("builds nothing if tree data has 'dir' type", function()
    --     local positions = adapter.discover_positions("./test_files"):to_list()

    --     local tree = Tree.from_list(positions, function(pos)
    --         return pos.id
    --     end)

    --     assert.is_nil(adapter.build_spec({ tree = tree }))
    -- end)
end)
