local async = require("neotest.async").tests
local config = require("neotest-busted.config")
local compare_test_positions = require("neotest-busted.testing.compare_test_positions")

---@type neotest.Adapter
local adapter = require("neotest-busted")()

describe("adapter.discover_positions", function()
    local function sort_parametric_results(results)
        table.sort(results, function(result1, result2)
            return result1.id < result2.id
        end)
    end

    before_each(function()
        config.configure()
    end)

    async.it("discovers test positions", function()
        local positions = adapter.discover_positions("./test_files/test1_spec.lua"):to_list()

        local expected_positions = {
            {
                name = "test1_spec.lua",
                type = "file",
            },
            {
                {
                    name = '"top-level namespace 1"',
                    type = "namespace",
                },
                {
                    {
                        name = '"nested namespace 1"',
                        type = "namespace",
                    },
                    {
                        {
                            name = '"test 1"',
                            type = "test",
                        },
                    },
                    {
                        {
                            name = '"test 2"',
                            type = "test",
                        },
                    },
                },
            },
            {
                {
                    name = '"^top-le[ve]l (na*m+e-sp?ac%e) 2$"',
                    type = "namespace",
                },
                {
                    {
                        name = '"test 3"',
                        type = "test",
                    },
                },
                {
                    {
                        name = '"test 4"',
                        type = "test",
                    },
                },
            },
        }

        compare_test_positions(positions, expected_positions)

        ---@diagnostic disable-next-line: undefined-field
        local cache = adapter.get_parametric_test_cache()

        assert.are.same(cache:size(), 0)
    end)

    async.it("discovers parametric test positions", function()
        config.configure({ parametric_test_discovery = true })

        local positions = adapter.discover_positions("./test_files/parametric_tests_spec.lua"):to_list()

        local expected_positions = {
            {
                name = "parametric_tests_spec.lua",
                type = "file",
            },
            {
                {
                    name = '"namespace 1"',
                    type = "namespace",
                },
                {
                    {
                        name = '"nested namespace 1"',
                        type = "namespace",
                    },
                    {
                        {
                            name = '("test %d"):format(i)',
                            type = "test",
                        },
                    },
                    {
                        {
                            name = '"test " .. "4"',
                            type = "test",
                        },
                    },
                },
            },
            {
                {
                    name = '"namespace 2"',
                    type = "namespace",
                },
                {
                    {
                        name = '"nested namespace 2 - " .. tostring(i)',
                        type = "namespace",
                    },
                    {
                        {
                            name = '"test 1"',
                            type = "test",
                        },
                    },
                    {
                        {
                            name = '("test %d"):format(j)',
                            type = "test",
                        },
                    }
                },
            },
        }

        compare_test_positions(positions, expected_positions)

        ---@diagnostic disable-next-line: undefined-field
        local cache = adapter.get_parametric_test_cache()

        assert.are.same(cache:size(), 3)

        local result1 = cache:get('./test_files/parametric_tests_spec.lua::"namespace 1"::"nested namespace 1"::("test %d"):format(i)')

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
            {
                id = "./test_files/parametric_tests_spec.lua::namespace::1::nested::namespace::1::test::3",
                in_tree = false,
                lnum = 4,
                path = "./test_files/parametric_tests_spec.lua",
                type = "test",
            },
        })

        local result2 = cache:get('./test_files/parametric_tests_spec.lua::"namespace 1"::"nested namespace 1"::"test " .. "4"')

        assert.are.same(result2, {
            {
                id = "./test_files/parametric_tests_spec.lua::namespace::1::nested::namespace::1::test::4",
                in_tree = false,
                lnum = 9,
                path = "./test_files/parametric_tests_spec.lua",
                type = "test",
            },
        })

        local result3 = cache:get('./test_files/parametric_tests_spec.lua::"namespace 2"::"nested namespace 2 - " .. tostring(i)::("test %d"):format(j)')

        sort_parametric_results(result3)

        assert.are.same(result3, {
            {
                id = './test_files/parametric_tests_spec.lua::namespace::2::nested::namespace::2::-::1::test::1',
                in_tree = false,
                lnum = 23,
                path = "./test_files/parametric_tests_spec.lua",
                type = "test",
            },
            {
                id = './test_files/parametric_tests_spec.lua::namespace::2::nested::namespace::2::-::1::test::2',
                in_tree = false,
                lnum = 23,
                path = "./test_files/parametric_tests_spec.lua",
                type = "test",
            },
            {
                id = './test_files/parametric_tests_spec.lua::namespace::2::nested::namespace::2::-::1::test::3',
                in_tree = false,
                lnum = 23,
                path = "./test_files/parametric_tests_spec.lua",
                type = "test",
            },
            {
                id = './test_files/parametric_tests_spec.lua::namespace::2::nested::namespace::2::-::2::test::1',
                in_tree = false,
                lnum = 23,
                path = "./test_files/parametric_tests_spec.lua",
                type = "test",
            },
            {
                id = './test_files/parametric_tests_spec.lua::namespace::2::nested::namespace::2::-::2::test::2',
                in_tree = false,
                lnum = 23,
                path = "./test_files/parametric_tests_spec.lua",
                type = "test",
            },
            {
                id = './test_files/parametric_tests_spec.lua::namespace::2::nested::namespace::2::-::2::test::3',
                in_tree = false,
                lnum = 23,
                path = "./test_files/parametric_tests_spec.lua",
                type = "test",
            },
            {
                id = './test_files/parametric_tests_spec.lua::namespace::2::nested::namespace::2::-::3::test::1',
                in_tree = false,
                lnum = 23,
                path = "./test_files/parametric_tests_spec.lua",
                type = "test",
            },
            {
                id = './test_files/parametric_tests_spec.lua::namespace::2::nested::namespace::2::-::3::test::2',
                in_tree = false,
                lnum = 23,
                path = "./test_files/parametric_tests_spec.lua",
                type = "test",
            },
            {
                id = './test_files/parametric_tests_spec.lua::namespace::2::nested::namespace::2::-::3::test::3',
                in_tree = false,
                lnum = 23,
                path = "./test_files/parametric_tests_spec.lua",
                type = "test",
            },
        })
    end)
end)
