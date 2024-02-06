local async = require("neotest.async").tests
local adapter = require("neotest-busted")()

describe("adapter.discover_positions", function()
    local function compare_test_positions(positions, expected_positions)
        assert.are.same(#positions, #expected_positions)

        for idx = 1, #positions, 1 do
            local position = positions[idx]
            local expected_position = expected_positions[idx]

            if position.id ~= nil then
                assert.are.same(position.name, expected_position.name)
                assert.are.same(position.type, expected_position.type)
            else
                compare_test_positions(position, expected_position)
            end
        end
    end

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
                    name = '"top-level namespace 2"',
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
    end)
end)
