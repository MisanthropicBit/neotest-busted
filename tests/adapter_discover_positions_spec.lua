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

        local expected_tree = require("./test_files/expected_tree1")
        assert.are.same(positions, expected_tree)

        ---@diagnostic disable-next-line: undefined-field
        local cache = adapter.get_parametric_test_cache()

        assert.are.same(cache:size(), 0)
    end)

    async.it("discovers parametric test positions", function()
        local path = "./test_files/parametric_tests_spec.lua"

        local stderr_output = {
            path .. ":4: namespace 1 nested namespace 1 test 1",
            path .. ":4: namespace 1 nested namespace 1 test 2",
            path .. ":9: namespace 1 nested namespace 1 test 3",
            path .. ":18: namespace 2 nested namespace 2 - 1 some test",
            path .. ":23: namespace 2 nested namespace 2 - 1 test 1",
            path .. ":23: namespace 2 nested namespace 2 - 1 test 2",
            path .. ":18: namespace 2 nested namespace 2 - 2 some test",
            path .. ":23: namespace 2 nested namespace 2 - 2 test 1",
            path .. ":23: namespace 2 nested namespace 2 - 2 test 2",
        }

        -- Stub nio process functions since running `busted --list` appears to be broken
        stub(
            nio.process,
            "run",
            -- Fake process object
            {
                stderr = {
                    read = function()
                        return table.concat(stderr_output, "\r\n"), nil
                    end,
                },
                result = function()
                    return 0
                end,
            }
        )

        config.configure({ parametric_test_discovery = true })

        local positions = adapter.discover_positions(path):to_list()

        local expected_tree = require("./test_files/expected_tree2")
        assert.are.same(positions, expected_tree)

        ---@diagnostic disable-next-line: undefined-field
        local cache = adapter.get_parametric_test_cache()

        assert.are.same(cache:size(), 4)

        local result1 =
            cache:get(path .. '::"namespace 1"::"nested namespace 1"::("test %d"):format(i)')

        sort_parametric_results(result1)

        assert.are.same(result1, {
            {
                id = path .. "::namespace::1::nested::namespace::1::test::1",
                in_tree = false,
                lnum = 4,
                path = path,
                type = "test",
            },
            {
                id = path .. "::namespace::1::nested::namespace::1::test::2",
                in_tree = false,
                lnum = 4,
                path = path,
                type = "test",
            },
        })

        local result2 = cache:get(path .. '::"namespace 1"::"nested namespace 1"::"test " .. "3"')

        assert.are.same(result2, {
            {
                id = path .. "::namespace::1::nested::namespace::1::test::3",
                in_tree = false,
                lnum = 9,
                path = path,
                type = "test",
            },
        })

        local result3 = cache:get(
            path .. '::"namespace 2"::"nested namespace 2 - " .. tostring(i)::("test %d"):format(j)'
        )

        sort_parametric_results(result3)

        assert.are.same(result3, {
            {
                id = path .. "::namespace::2::nested::namespace::2::-::1::test::1",
                in_tree = false,
                lnum = 23,
                path = path,
                type = "test",
            },
            {
                id = path .. "::namespace::2::nested::namespace::2::-::1::test::2",
                in_tree = false,
                lnum = 23,
                path = path,
                type = "test",
            },
            {
                id = path .. "::namespace::2::nested::namespace::2::-::2::test::1",
                in_tree = false,
                lnum = 23,
                path = path,
                type = "test",
            },
            {
                id = path .. "::namespace::2::nested::namespace::2::-::2::test::2",
                in_tree = false,
                lnum = 23,
                path = path,
                type = "test",
            },
        })

        local result4 = cache:get(
            path .. '::"namespace 2"::"nested namespace 2 - " .. tostring(i)::"some test"'
        )

        assert.are.same(result4, {
            {
                id = path .. "::namespace::2::nested::namespace::2::-::1::some::test",
                in_tree = false,
                lnum = 18,
                path = path,
                type = "test",
            },
            {
                id = path .. "::namespace::2::nested::namespace::2::-::2::some::test",
                in_tree = false,
                lnum = 18,
                path = path,
                type = "test",
            },
        })

        nio.process.run:revert()
    end)
end)
