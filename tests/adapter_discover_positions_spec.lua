local async = require("neotest.async").tests
local config = require("neotest-busted.config")
local nio = require("nio")
local stub = require("luassert.stub")

---@type neotest.Adapter
local adapter = require("neotest-busted")()

describe("adapter.discover_positions", function()
    local function sort_parametric_results(results)
        table.sort(results, function(result1, result2)
            return result1.id < result2.id
        end)
    end

    before_each(function()
        assert:set_parameter("TableFormatLevel", 10)
        config.configure()
    end)

    async.it("discovers test positions", function()
        local positions = adapter.discover_positions("./test_files/test1_spec.lua"):to_list()

        local expected_positions = {
            {
                id = "./test_files/test1_spec.lua",
                name = "test1_spec.lua",
                path = "./test_files/test1_spec.lua",
                range = { 0, 0, 21, 0 },
                type = "file",
            },
            {
                {
                    id = './test_files/test1_spec.lua::"top-level namespace 1"',
                    name = '"top-level namespace 1"',
                    path = "./test_files/test1_spec.lua",
                    range = { 0, 0, 10, 4 },
                    type = "namespace",
                },
                {
                    {
                        id = './test_files/test1_spec.lua::"top-level namespace 1"::"nested namespace 1"',
                        name = '"nested namespace 1"',
                        path = "./test_files/test1_spec.lua",
                        range = { 1, 4, 9, 8 },
                        type = "namespace",
                    },
                    {
                        {
                            id = './test_files/test1_spec.lua::"top-level namespace 1"::"nested namespace 1"::"test 1"',
                            name = '"test 1"',
                            path = "./test_files/test1_spec.lua",
                            range = { 2, 8, 4, 12 },
                            type = "test",
                        },
                    },
                    {
                        {
                            id = './test_files/test1_spec.lua::"top-level namespace 1"::"nested namespace 1"::"test 2"',
                            name = '"test 2"',
                            path = "./test_files/test1_spec.lua",
                            range = { 6, 8, 8, 12 },
                            type = "test",
                        },
                    },
                },
            },
            {
                {
                    id = './test_files/test1_spec.lua::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"',
                    name = '"^top-le[ve]l (na*m+e-sp?ac%e) 2$"',
                    path = "./test_files/test1_spec.lua",
                    range = { 12, 0, 20, 4 },
                    type = "namespace",
                },
                {
                    {
                        id = './test_files/test1_spec.lua::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 3"',
                        name = '"test 3"',
                        path = "./test_files/test1_spec.lua",
                        range = { 13, 4, 15, 8 },
                        type = "test",
                    },
                },
                {
                    {
                        id = './test_files/test1_spec.lua::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 4"',
                        name = '"test 4"',
                        path = "./test_files/test1_spec.lua",
                        range = { 17, 4, 19, 8 },
                        type = "test",
                    },
                },
            },
        }

        assert.are.same(positions, expected_positions)

        ---@diagnostic disable-next-line: undefined-field
        local cache = adapter.get_parametric_test_cache()

        assert.are.same(cache:size(), 0)
    end)

    async.it("discovers parametric test positions", function()
        local stderr_output = {
            ".../vim/neotest-busted/test_files/parametric_tests_spec.lua:4: namespace 1 nested namespace 1 test 1",
            ".../vim/neotest-busted/test_files/parametric_tests_spec.lua:4: namespace 1 nested namespace 1 test 2",
            ".../vim/neotest-busted/test_files/parametric_tests_spec.lua:9: namespace 1 nested namespace 1 test 3",
            ".../vim/neotest-busted/test_files/parametric_tests_spec.lua:18: namespace 2 nested namespace 2 - 1 test 1",
            ".../vim/neotest-busted/test_files/parametric_tests_spec.lua:23: namespace 2 nested namespace 2 - 1 test 1",
            ".../vim/neotest-busted/test_files/parametric_tests_spec.lua:23: namespace 2 nested namespace 2 - 1 test 2",
            ".../vim/neotest-busted/test_files/parametric_tests_spec.lua:18: namespace 2 nested namespace 2 - 2 test 1",
            ".../vim/neotest-busted/test_files/parametric_tests_spec.lua:23: namespace 2 nested namespace 2 - 2 test 1",
            ".../vim/neotest-busted/test_files/parametric_tests_spec.lua:23: namespace 2 nested namespace 2 - 2 test 2",
        }

        -- Stub nio process functions since running `busted --list` appears to be broken
        stub(nio.process, "run",
            -- Fake process object
            {
                stderr = {
                    read = function()
                        return table.concat(stderr_output, "\r\n"), nil
                    end
                },
                result = function()
                    return 0
                end
            }
        )

        config.configure({ parametric_test_discovery = true })

        local positions =
            adapter.discover_positions("./test_files/parametric_tests_spec.lua"):to_list()

        local expected_positions = {
            {
                id = "./test_files/parametric_tests_spec.lua",
                name = "parametric_tests_spec.lua",
                path = "./test_files/parametric_tests_spec.lua",
                range = { 0, 0, 29, 0 },
                type = "file",
            },
            {
                {
                    id = './test_files/parametric_tests_spec.lua::"namespace 1"',
                    name = '"namespace 1"',
                    path = "./test_files/parametric_tests_spec.lua",
                    range = { 0, 0, 12, 4 },
                    type = "namespace",
                },
                {
                    {
                        id = './test_files/parametric_tests_spec.lua::"namespace 1"::"nested namespace 1"',
                        name = '"nested namespace 1"',
                        path = "./test_files/parametric_tests_spec.lua",
                        range = { 1, 4, 11, 8 },
                        type = "namespace",
                    },
                    {
                        {
                            id =
                            './test_files/parametric_tests_spec.lua::"namespace 1"::"nested namespace 1"::("test %d"):format(i)',
                            name = '("test %d"):format(i)',
                            path = "./test_files/parametric_tests_spec.lua",
                            range = { 3, 12, 5, 16 },
                            type = "test",
                        },
                    },
                    {
                        {
                            id =
                            './test_files/parametric_tests_spec.lua::"namespace 1"::"nested namespace 1"::"test " .. "3"',
                            name = '"test " .. "3"',
                            path = "./test_files/parametric_tests_spec.lua",
                            range = { 8, 8, 10, 12 },
                            type = "test",
                        },
                    },
                },
            },
            {
                {
                    id = './test_files/parametric_tests_spec.lua::"namespace 2"',
                    name = '"namespace 2"',
                    path = "./test_files/parametric_tests_spec.lua",
                    range = { 14, 0, 28, 4 },
                    type = "namespace",
                },
                {
                    {
                        id =
                        './test_files/parametric_tests_spec.lua::"namespace 2"::"nested namespace 2 - " .. tostring(i)',
                        name = '"nested namespace 2 - " .. tostring(i)',
                        path = "./test_files/parametric_tests_spec.lua",
                        range = { 16, 8, 26, 12 },
                        type = "namespace",
                    },
                    {
                        {
                            id =
                            './test_files/parametric_tests_spec.lua::"namespace 2"::"nested namespace 2 - " .. tostring(i)::"test 1"',
                            name = '"test 1"',
                            path = "./test_files/parametric_tests_spec.lua",
                            range = { 17, 12, 19, 16 },
                            type = "test",
                        },
                    },
                    {
                        {
                            id =
                            './test_files/parametric_tests_spec.lua::"namespace 2"::"nested namespace 2 - " .. tostring(i)::("test %d"):format(j)',
                            name = '("test %d"):format(j)',
                            path = "./test_files/parametric_tests_spec.lua",
                            range = { 22, 16, 24, 20 },
                            type = "test",
                        },
                    },
                },
            },
        }

        assert.are.same(positions, expected_positions)

        ---@diagnostic disable-next-line: undefined-field
        local cache = adapter.get_parametric_test_cache()

        assert.are.same(cache:size(), 3)

        local result1 = cache:get(
            './test_files/parametric_tests_spec.lua::"namespace 1"::"nested namespace 1"::("test %d"):format(i)'
        )

        sort_parametric_results(result1)

        assert.are.same(result1, {
            {
                id = "./test_files/parametric_tests_spec.lua::namespace::1::nested::namespace::1::test::1",
                in_tree = false,
                lnum = 4,
                path = "./test_files/parametric_tests_spec.lua",
                type = "test",
            },
            {
                id = "./test_files/parametric_tests_spec.lua::namespace::1::nested::namespace::1::test::2",
                in_tree = false,
                lnum = 4,
                path = "./test_files/parametric_tests_spec.lua",
                type = "test",
            },
        })

        local result2 = cache:get(
            './test_files/parametric_tests_spec.lua::"namespace 1"::"nested namespace 1"::"test " .. "3"'
        )

        assert.are.same(result2, {
            {
                id = "./test_files/parametric_tests_spec.lua::namespace::1::nested::namespace::1::test::3",
                in_tree = false,
                lnum = 9,
                path = "./test_files/parametric_tests_spec.lua",
                type = "test",
            },
        })

        local result3 = cache:get(
            './test_files/parametric_tests_spec.lua::"namespace 2"::"nested namespace 2 - " .. tostring(i)::("test %d"):format(j)'
        )

        sort_parametric_results(result3)

        assert.are.same(result3, {
            {
                id = "./test_files/parametric_tests_spec.lua::namespace::2::nested::namespace::2::-::1::test::1",
                in_tree = false,
                lnum = 23,
                path = "./test_files/parametric_tests_spec.lua",
                type = "test",
            },
            {
                id = "./test_files/parametric_tests_spec.lua::namespace::2::nested::namespace::2::-::1::test::2",
                in_tree = false,
                lnum = 23,
                path = "./test_files/parametric_tests_spec.lua",
                type = "test",
            },
            {
                id = "./test_files/parametric_tests_spec.lua::namespace::2::nested::namespace::2::-::2::test::1",
                in_tree = false,
                lnum = 23,
                path = "./test_files/parametric_tests_spec.lua",
                type = "test",
            },
            {
                id = "./test_files/parametric_tests_spec.lua::namespace::2::nested::namespace::2::-::2::test::2",
                in_tree = false,
                lnum = 23,
                path = "./test_files/parametric_tests_spec.lua",
                type = "test",
            },
        })

        local result4 = cache:get(
            './test_files/parametric_tests_spec.lua::"namespace 2"::"nested namespace 2 - " .. tostring(i)::test 1'
        )

        assert.is_nil(result4)

        nio.process.run:revert()
    end)
end)
