local async = require("neotest.async").tests
local lib = require("neotest.lib")
local logger = require("neotest.logging")
local types = require("neotest.types")
local stub = require("luassert.stub")

---@type neotest.Adapter
local adapter = require("neotest-busted")()
local config = require("neotest-busted.config")

describe("adapter.results", function()
    local test_path = "/Users/user/vim/project/tests/test_spec.lua"

    local spec = {
        context = {
            results_path = "test_output.json",
            position_id_mapping = {
                [test_path .. "::namespace tests a pending test::5"] = test_path
                    .. '::"namespace"::"tests a pending test"',
                [test_path .. "::namespace tests a passing test::6"] = test_path
                    .. '::"namespace"::"tests a passing test"',
                [test_path .. "::namespace tests a failing test::7"] = test_path
                    .. '::"namespace"::"tests a failing test"',
                [test_path .. "::namespace tests an erroneous test::10"] = test_path
                    .. '::"namespace"::"tests an erroneous test"',
            },
        },
    }

    local strategy_result = {
        output = "test_console_output",
    }

    local test_json = table.concat(vim.fn.readfile("./tests/busted_test_output.json"), "\n")

    before_each(function()
        assert:set_parameter("TableFormatLevel", 10)
        config.configure()

        stub(lib.files, "read", test_json)
        stub(logger, "error")
    end)

    after_each(function()
        ---@diagnostic disable-next-line: undefined-field
        lib.files.read:revert()

        ---@diagnostic disable-next-line: undefined-field
        logger.error:revert()
    end)

    async.it("creates neotest results", function()
        ---@diagnostic disable-next-line: undefined-field
        lib.files.read:revert()

        local tree = adapter.discover_positions("./test_files/test1_spec.lua")
        ---@cast tree -nil

        stub(lib.files, "read", test_json)

        local neotest_results = adapter.results(spec, strategy_result, tree)

        -- TODO: Generate the actual results and put them in the json file
        assert.are.same(neotest_results, {
            [test_path .. '::"namespace"::"tests a pending test"'] = {
                status = types.ResultStatus.skipped,
                short = "namespace tests a pending test: skipped",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace"::"tests a passing test"'] = {
                status = types.ResultStatus.passed,
                short = "namespace tests a passing test: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace"::"tests a failing test"'] = {
                status = types.ResultStatus.failed,
                short = "namespace tests a failing test: failed",
                output = strategy_result.output,
                errors = {
                    {
                        message = "Assert failed",
                        line = 7,
                    },
                },
            },
            [test_path .. '::"namespace"::"tests an erroneous test"'] = {
                status = types.ResultStatus.failed,
                short = "namespace tests an erroneous test: failed",
                output = strategy_result.output,
                errors = {
                    {
                        message = "Oh noes",
                        line = 11,
                    },
                },
            },
        })

        -- Tree remains unchanged
        assert.are.same(tree:to_list(), {
            {
                id = "./test_files/test1_spec.lua",
                name = "test1_spec.lua",
                path = "./test_files/test1_spec.lua",
                range = {
                    0,
                    0,
                    21,
                    0,
                },
                type = "file",
            },
            {
                {
                    id = './test_files/test1_spec.lua::"top-level namespace 1"',
                    name = '"top-level namespace 1"',
                    path = "./test_files/test1_spec.lua",
                    range = {
                        0,
                        0,
                        10,
                        4,
                    },
                    type = "namespace",
                },
                {
                    {
                        id = './test_files/test1_spec.lua::"top-level namespace 1"::"nested namespace 1"',
                        name = '"nested namespace 1"',
                        path = "./test_files/test1_spec.lua",
                        range = {
                            1,
                            4,
                            9,
                            8,
                        },
                        type = "namespace",
                    },
                    {
                        {
                            id = './test_files/test1_spec.lua::"top-level namespace 1"::"nested namespace 1"::"test 1"',
                            name = '"test 1"',
                            path = "./test_files/test1_spec.lua",
                            range = {
                                2,
                                8,
                                4,
                                12,
                            },
                            type = "test",
                        },
                    },
                    {
                        {
                            id = './test_files/test1_spec.lua::"top-level namespace 1"::"nested namespace 1"::"test 2"',
                            name = '"test 2"',
                            path = "./test_files/test1_spec.lua",
                            range = {
                                6,
                                8,
                                8,
                                12,
                            },
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
                    range = {
                        12,
                        0,
                        20,
                        4,
                    },
                    type = "namespace",
                },
                {
                    {
                        id = './test_files/test1_spec.lua::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 3"',
                        name = '"test 3"',
                        path = "./test_files/test1_spec.lua",
                        range = {
                            13,
                            4,
                            15,
                            8,
                        },
                        type = "test",
                    },
                },
                {
                    {
                        id = './test_files/test1_spec.lua::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 4"',
                        name = '"test 4"',
                        path = "./test_files/test1_spec.lua",
                        range = {
                            17,
                            4,
                            19,
                            8,
                        },
                        type = "test",
                    },
                },
            },
        })

        assert.stub(lib.files.read).was.called_with(spec.context.results_path)
        assert.stub(logger.error).was_not_called()
    end)

    async.it("creates neotest results for successful parametric tests and updates tree (test)", function()
        ---@diagnostic disable-next-line: undefined-field
        lib.files.read:revert()

        config.configure({ parametric_test_discovery = true })

        local tree = adapter.discover_positions("./test_files/parametric_tests_spec.lua")
        ---@cast tree -nil

        ---@diagnostic disable-next-line: undefined-field
        lib.files.read:revert()

        local parametric_test_json = table.concat(
            vim.fn.readfile("./tests/busted_parametric_test_output_success.json"),
            "\n"
        )

        stub(lib.files, "read", parametric_test_json)

        local subtree = tree:get_key('./test_files/parametric_tests_spec.lua::"namespace 1"::"nested namespace 1"::"("test %d"):format(i)"')

        assert.is_not_nil(subtree)
        ---@cast subtree -nil

        local neotest_results = adapter.results(spec, strategy_result, subtree)

        assert.are.same(neotest_results, {
            [test_path .. '::"namespace 1"::"nested namespace 1"::"test 1"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 1 nested namespace 1 test 1: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace 1"::"nested namespace 1"::"test 2"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 1 nested namespace 1 test 2: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace 1"::"nested namespace 1"::"test 3"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 1 nested namespace 1 test 3: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace 2"::"nested namespace 2 - 1"::"test 1"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 2 nested namespace 2 - 1 test 1: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace 2"::"nested namespace 2 - 1"::"test 1"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 2 nested namespace 2 - 1 test 1: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace 2"::"nested namespace 2 - 1"::"test 2"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 2 nested namespace 2 - 1 test 2: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace 2"::"nested namespace 2 - 1"::"test 3"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 2 nested namespace 2 - 1 test 3: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace 2"::"nested namespace 2 - 2"::"test 1"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 2 nested namespace 2 - 2 test 1: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace 2"::"nested namespace 2 - 2"::"test 1"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 2 nested namespace 2 - 2 test 1: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace 2"::"nested namespace 2 - 2"::"test 2"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 2 nested namespace 2 - 2 test 2: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace 2"::"nested namespace 2 - 2"::"test 3"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 2 nested namespace 2 - 2 test 3: passed",
                output = strategy_result.output,
            },
        })

        -- TODO: Check updated tree

        assert.stub(lib.files.read).was.called_with(spec.context.results_path)
        assert.stub(logger.error).was_not_called()
    end)

    -- async.it("creates neotest results for parametric tests and updates tree (namespace)", function()
    -- end)

    async.it("creates neotest results for parametric tests and updates tree (file)", function()
        lib.files.read:revert()

        config.configure({ parametric_test_discovery = true })

        local tree = adapter.discover_positions("./test_files/parametric_tests_spec.lua")
        ---@cast tree -nil

        ---@diagnostic disable-next-line: undefined-field
        lib.files.read:revert()

        local parametric_test_json = table.concat(
            vim.fn.readfile("./tests/busted_parametric_test_output_success.json"),
            "\n"
        )

        stub(lib.files, "read", parametric_test_json)

        local neotest_results = adapter.results(spec, strategy_result, tree)

        assert.are.same(neotest_results, {
            [test_path .. '::"namespace 1"::"nested namespace 1"::"test 1"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 1 nested namespace 1 test 1: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace 1"::"nested namespace 1"::"test 2"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 1 nested namespace 1 test 2: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace 1"::"nested namespace 1"::"test 3"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 1 nested namespace 1 test 3: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace 2"::"nested namespace 2 - 1"::"test 1"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 2 nested namespace 2 - 1 test 1: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace 2"::"nested namespace 2 - 1"::"test 1"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 2 nested namespace 2 - 1 test 1: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace 2"::"nested namespace 2 - 1"::"test 2"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 2 nested namespace 2 - 1 test 2: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace 2"::"nested namespace 2 - 1"::"test 3"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 2 nested namespace 2 - 1 test 3: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace 2"::"nested namespace 2 - 2"::"test 1"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 2 nested namespace 2 - 2 test 1: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace 2"::"nested namespace 2 - 2"::"test 1"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 2 nested namespace 2 - 2 test 1: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace 2"::"nested namespace 2 - 2"::"test 2"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 2 nested namespace 2 - 2 test 2: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace 2"::"nested namespace 2 - 2"::"test 3"'] = {
                status = types.ResultStatus.passed,
                short = "namespace 2 nested namespace 2 - 2 test 3: passed",
                output = strategy_result.output,
            },
        })

        -- TODO: Check updated tree

        assert.stub(lib.files.read).was.called_with(spec.context.results_path)
        assert.stub(logger.error).was_not_called()
    end)

    -- async.it("creates neotest results for failed parametric tests and updates tree", function()
    -- end)

    it("handles failure to read json test output", function()
        stub(vim, "schedule", function(func)
            func()
        end)

        stub(vim, "notify")

        stub(lib.files, "read", function()
            error("Could not read file", 0)
        end)

        ---@diagnostic disable-next-line: missing-parameter
        local neotest_results = adapter.results(spec, strategy_result)

        assert.are.same(neotest_results, {})

        assert.stub(vim.schedule).was.called()
        assert.stub(vim.notify).was.called()
        assert.stub(lib.files.read).was.called_with(spec.context.results_path)
        assert.stub(logger.error).was.called_with(
            "Failed to read json test output file test_output.json with error: Could not read file",
            nil
        )
        assert.stub(lib.files.read).was.called_with(spec.context.results_path)

        ---@diagnostic disable-next-line: undefined-field
        vim.schedule:revert()
        ---@diagnostic disable-next-line: undefined-field
        vim.notify:revert()
    end)

    it("handles failure to decode json", function()
        stub(vim, "schedule", function(func)
            func()
        end)

        stub(vim, "notify")

        stub(vim.json, "decode", function()
            error("Expected value but found invalid token at character 1", 0)
        end)

        ---@diagnostic disable-next-line: missing-parameter
        local neotest_results = adapter.results(spec, strategy_result)

        assert.are.same(neotest_results, {})

        assert.stub(vim.schedule).was.called()
        assert.stub(vim.notify).was.called()
        assert.stub(lib.files.read).was.called_with(spec.context.results_path)
        assert.stub(logger.error).was.called_with(
            "Failed to parse json test output file test_output.json with error: Expected value but found invalid token at character 1",
            nil
        )
        assert.stub(lib.files.read).was.called_with(spec.context.results_path)

        ---@diagnostic disable-next-line: undefined-field
        vim.schedule:revert()
        ---@diagnostic disable-next-line: undefined-field
        vim.notify:revert()
        ---@diagnostic disable-next-line: undefined-field
        vim.json.decode:revert()
    end)

    it("logs not finding a matching position id", function()
        stub(vim, "schedule", function(func)
            func()
        end)

        stub(vim, "notify")

        spec.context.position_id_mapping[test_path .. "::namespace tests a failing test::7"] = nil

        ---@diagnostic disable-next-line: missing-parameter
        local neotest_results = adapter.results(spec, strategy_result)

        assert.are.same(neotest_results, {
            [test_path .. '::"namespace"::"tests a pending test"'] = {
                status = types.ResultStatus.skipped,
                short = "namespace tests a pending test: skipped",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace"::"tests a passing test"'] = {
                status = types.ResultStatus.passed,
                short = "namespace tests a passing test: passed",
                output = strategy_result.output,
            },
            [test_path .. '::"namespace"::"tests an erroneous test"'] = {
                status = types.ResultStatus.failed,
                short = "namespace tests an erroneous test: failed",
                output = strategy_result.output,
                errors = {
                    {
                        message = "Oh noes",
                        line = 11,
                    },
                },
            },
        })

        assert.stub(vim.schedule).was.called()
        assert.stub(vim.notify).was.called()
        assert.stub(lib.files.read).was.called_with(spec.context.results_path)
        assert.stub(logger.error).was.called_with(
            "Failed to find matching position id for key "
            .. test_path
            .. "::namespace tests a failing test::7",
            nil
        )

        ---@diagnostic disable-next-line: undefined-field
        vim.schedule:revert()
        ---@diagnostic disable-next-line: undefined-field
        vim.notify:revert()
    end)
end)
