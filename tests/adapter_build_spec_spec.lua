local _async = require("neotest.async")
-- local logger = require("neotest.logging")
local Tree = require("neotest.types").Tree
local stub = require("luassert.stub")

local async = _async.tests

describe("adapter.build_spec", function()
    ---@param adapter neotest.Adapter
    ---@return neotest.Tree
    local function create_tree(adapter)
        local positions = adapter.discover_positions("./test_files/test1_spec.lua"):to_list()

        return Tree.from_list(positions, function(pos)
            return pos.id
        end)
    end

    before_each(function()
        stub(_async.fn, "tempname", "test-output.json")
        stub(vim, "notify")
    end)

    after_each(function()
        _async.fn.tempname:revert()
        vim.notify:revert()
    end)

    local adapter = require("neotest-busted")({
        busted_command = "./busted",
        busted_args = { "--shuffle-lists" },
        busted_path = "~/.luarocks/share/lua/5.1/?.lua",
        busted_cpath = "~/.luarocks/lib/lua/5.1/?.so",
    })

    async.it("builds command for file test", function()
        local tree = create_tree(adapter)
        local spec = adapter.build_spec({ tree = tree })

        assert.is_not_nil(spec)

        assert.are.same(
            spec.command,
            vim.loop.exepath()
                .. [[ --headless -i NONE -n -u tests/minimal_init.lua -c "lua package.path = '~/.luarocks/share/lua/5.1/?.lua;' .. package.path" -c "lua package.cpath = '~/.luarocks/lib/lua/5.1/?.so;' .. package.cpath" -l ./busted --output=./lua/neotest-busted/output_handler.lua -Xoutput=test-output.json --verbose --shuffle-lists ./test_files/test1_spec.lua]]
        )

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
        adapter({
            busted_command = "./busted",
            busted_args = {},
            busted_path = false,
            busted_cpath = false,
        })

        local tree = create_tree(adapter)
        local spec = adapter.build_spec({ tree = tree:children()[1]:children()[1] })

        assert.is_not_nil(spec)

        assert.are.same(
            spec.command,
            vim.loop.exepath()
                .. [[ --headless -i NONE -n -u tests/minimal_init.lua -l ./busted --output=./lua/neotest-busted/output_handler.lua -Xoutput=test-output.json --verbose --filter="top%-level namespace 1 nested namespace 1 test 1" --filter="top%-level namespace 1 nested namespace 1 test 2" ./test_files/test1_spec.lua]]
        )

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
        adapter({
            busted_command = "./busted",
            busted_args = {},
            busted_path = false,
            busted_cpath = false,
        })

        local tree = create_tree(adapter)
        local spec = adapter.build_spec({
            tree = tree:children()[1]:children()[1]:children()[1],
        })

        assert.is_not_nil(spec)

        assert.are.same(
            spec.command,
            vim.loop.exepath()
                .. [[ --headless -i NONE -n -u tests/minimal_init.lua -l ./busted --output=./lua/neotest-busted/output_handler.lua -Xoutput=test-output.json --verbose --filter="top%-level namespace 1 nested namespace 1 test 1" ./test_files/test1_spec.lua]]
        )

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
        adapter({
            busted_command = "./busted",
            busted_args = {},
            busted_path = false,
            busted_cpath = false,
        })

        local tree = create_tree(adapter)
        local spec = adapter.build_spec({ tree = tree:children()[2]:children()[1] })

        assert.is_not_nil(spec)

        assert.are.same(
            spec.command,
            vim.loop.exepath()
                .. [[ --headless -i NONE -n -u tests/minimal_init.lua -l ./busted --output=./lua/neotest-busted/output_handler.lua -Xoutput=test-output.json --verbose --filter="%^top%-le%[ve]l %(na%*m%+e%-sp%?ac%%e%) 2%\$ test 3" ./test_files/test1_spec.lua]]
        )

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

    -- async.it("handles failure to find a busted command", function()
    --     adapter({
    --         busted_command = false,
    --         busted_args = {},
    --         busted_path = false,
    --         busted_cpath = false
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
