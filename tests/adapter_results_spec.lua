local async = require("neotest.async").tests
local lib = require("neotest.lib")
local logger = require("neotest.logging")
local types = require("neotest.types")
local nio = require("nio")
local stub = require("luassert.stub")

---@type neotest.Adapter
local adapter = require("neotest-busted")()
local config = require("neotest-busted.config")

describe("adapter.results", function()
    local test_path = "/Users/user/vim/project/tests/test_spec.lua"
    local parametric_test_path = "./test_files/parametric_tests_spec.lua"
    local spec = {}
    local strategy_result = {
        output = "test_console_output",
    }

    -- Output from `busted --list`
    local stderr_output = {
        parametric_test_path .. ":4: namespace 1 nested namespace 1 test 1",
        parametric_test_path .. ":4: namespace 1 nested namespace 1 test 2",
        parametric_test_path .. ":9: namespace 1 nested namespace 1 test 3",
        parametric_test_path .. ":18: namespace 2 nested namespace 2 - 1 some test",
        parametric_test_path .. ":23: namespace 2 nested namespace 2 - 1 test 1",
        parametric_test_path .. ":23: namespace 2 nested namespace 2 - 1 test 2",
        parametric_test_path .. ":18: namespace 2 nested namespace 2 - 2 some test",
        parametric_test_path .. ":23: namespace 2 nested namespace 2 - 2 test 1",
        parametric_test_path .. ":23: namespace 2 nested namespace 2 - 2 test 2",
    }

    local test_json = table.concat(vim.fn.readfile("./test_files/busted_test_output.json"), "\n")

    local function stub_nio_process_run()
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
    end

    before_each(function()
        assert:set_parameter("TableFormatLevel", 10)

        spec = {
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
        -- NOTE: neotest.lib.treesitter.parse_positions uses lib.file.read
        ---@diagnostic disable-next-line: undefined-field
        lib.files.read:revert()

        local path = "./test_files/test1_spec.lua"
        local tree = adapter.discover_positions(path)
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

        local expected_tree = require("./test_files/expected_tree")

        -- Tree remains unchanged
        assert.are.same(tree:to_list(), expected_tree)

        assert.stub(lib.files.read).was.called_with(spec.context.results_path)
        assert.stub(logger.error).was_not_called()
    end)

    async.it(
        "creates neotest results for successful parametric tests and updates tree (test)",
        function()
            config.configure({ parametric_test_discovery = true })

            -- -- Stub nio process functions since running `busted --list` appears to be broken
            -- stub(
            --     nio.process,
            --     "run",
            --     -- Fake process object
            --     {
            --         stderr = {
            --             read = function()
            --                 return table.concat(stderr_output, "\r\n"), nil
            --             end,
            --         },
            --         result = function()
            --             return 0
            --         end,
            --     }
            -- )

            -- NOTE: neotest.lib.treesitter.parse_positions uses lib.file.read so temporarily revert it
            ---@diagnostic disable-next-line: undefined-field
            lib.files.read:revert()

            local path = parametric_test_path
            local tree = adapter.discover_positions(path)
            ---@cast tree -nil

            local parametric_test_json = table.concat(
                vim.fn.readfile("./test_files/parametric_test_output_success_test.json"),
                "\n"
            )

            stub(lib.files, "read", parametric_test_json)

            -- Get the subtree rooted at the the first parametric test in the file
            local subtree = tree:children()[1]:children()[1]:children()[1]

            assert.is_not_nil(subtree)
            ---@cast subtree -nil

            local parametric_pos_id_key1 = path .. "::namespace::1::nested::namespace::1::test::1"
            local parametric_pos_id_key2 = path .. "::namespace::1::nested::namespace::1::test::2"

            spec.context.position_id_mapping = {
                [path .. "::namespace 1 nested namespace 1 test 1::4"] = parametric_pos_id_key1,
                [path .. "::namespace 1 nested namespace 1 test 2::4"] = parametric_pos_id_key2,
            }

            local neotest_results = adapter.results(spec, strategy_result, subtree)

            assert.are.same(neotest_results, {
                [path .. '::"namespace 1"::"nested namespace 1"::("test %d"):format(i)'] = {
                    status = types.ResultStatus.passed,
                    short = '("test %d"):format(i): passed',
                    output = strategy_result.output,
                },
                [parametric_pos_id_key1] = {
                    status = types.ResultStatus.passed,
                    short = "namespace 1 nested namespace 1 test 1: passed",
                    output = strategy_result.output,
                },
                [parametric_pos_id_key2] = {
                    status = types.ResultStatus.passed,
                    short = "namespace 1 nested namespace 1 test 2: passed",
                    output = strategy_result.output,
                },
            })

            local expected_tree = require("./test_files/expected_tree_parametric_test")

            assert.are.same(tree:to_list(), expected_tree)

            assert.stub(lib.files.read).was.called_with(spec.context.results_path)
            assert.stub(logger.error).was_not_called()
        end
    )

    async.it(
        "creates neotest results for successful parametric tests and updates tree (namespace)",
        function()
            config.configure({ parametric_test_discovery = true })

            -- Stub nio process functions since running `busted --list` appears to be broken
            -- stub(
            --     nio.process,
            --     "run",
            --     -- Fake process object
            --     {
            --         stderr = {
            --             read = function()
            --                 return table.concat(stderr_output, "\r\n"), nil
            --             end,
            --         },
            --         result = function()
            --             return 0
            --         end,
            --     }
            -- )

            -- NOTE: neotest.lib.treesitter.parse_positions uses lib.file.read so temporarily revert it
            ---@diagnostic disable-next-line: undefined-field
            lib.files.read:revert()

            local path = parametric_test_path
            local tree = adapter.discover_positions(path)
            ---@cast tree -nil

            local parametric_test_json = table.concat(
                vim.fn.readfile("./test_files/parametric_test_output_success_namespace.json"),
                "\n"
            )

            stub(lib.files, "read", parametric_test_json)

            -- Get the subtree rooted at the the first parametric namespace in the file
            local subtree = tree:children()[2]:children()[1]

            assert.is_not_nil(subtree)
            ---@cast subtree -nil

            local parametric_pos_id_key1 = path
                .. "::namespace::2::nested::namespace::2::-::1::some::test"
            local parametric_pos_id_key2 = path
                .. "::namespace::2::nested::namespace::2::-::2::some::test"
            local parametric_pos_id_key3 = path
                .. "::namespace::2::nested::namespace::2::-::1::test::1"
            local parametric_pos_id_key4 = path
                .. "::namespace::2::nested::namespace::2::-::1::test::2"
            local parametric_pos_id_key5 = path
                .. "::namespace::2::nested::namespace::2::-::2::test::1"
            local parametric_pos_id_key6 = path
                .. "::namespace::2::nested::namespace::2::-::2::test::2"

            spec.context.position_id_mapping = {
                [path .. "::namespace 2 nested namespace 2 - 1 some test::18"] = parametric_pos_id_key1,
                [path .. "::namespace 2 nested namespace 2 - 2 some test::18"] = parametric_pos_id_key2,
                [path .. "::namespace 2 nested namespace 2 - 1 test 1::23"] = parametric_pos_id_key3,
                [path .. "::namespace 2 nested namespace 2 - 1 test 2::23"] = parametric_pos_id_key4,
                [path .. "::namespace 2 nested namespace 2 - 2 test 1::23"] = parametric_pos_id_key5,
                [path .. "::namespace 2 nested namespace 2 - 2 test 2::23"] = parametric_pos_id_key6,
            }

            local neotest_results = adapter.results(spec, strategy_result, subtree)

            assert.are.same(neotest_results, {
                [path .. '::"namespace 2"::"nested namespace 2 - " .. tostring(i)'] = {
                    status = types.ResultStatus.passed,
                    short = '"nested namespace 2 - " .. tostring(i): passed',
                    output = strategy_result.output,
                },
                [path .. "::namespace::2::nested::namespace::2::-::1::some::test"] = {
                    output = "test_console_output",
                    short = "namespace 2 nested namespace 2 - 1 some test: passed",
                    status = "passed",
                },
                [path .. "::namespace::2::nested::namespace::2::-::1::test::1"] = {
                    output = "test_console_output",
                    short = "namespace 2 nested namespace 2 - 1 test 1: passed",
                    status = "passed",
                },
                [path .. "::namespace::2::nested::namespace::2::-::1::test::2"] = {
                    output = "test_console_output",
                    short = "namespace 2 nested namespace 2 - 1 test 2: passed",
                    status = "passed",
                },
                [path .. "::namespace::2::nested::namespace::2::-::2::some::test"] = {
                    output = "test_console_output",
                    short = "namespace 2 nested namespace 2 - 2 some test: passed",
                    status = "passed",
                },
                [path .. "::namespace::2::nested::namespace::2::-::2::test::1"] = {
                    output = "test_console_output",
                    short = "namespace 2 nested namespace 2 - 2 test 1: passed",
                    status = "passed",
                },
                [path .. "::namespace::2::nested::namespace::2::-::2::test::2"] = {
                    output = "test_console_output",
                    short = "namespace 2 nested namespace 2 - 2 test 2: passed",
                    status = "passed",
                },
            })

            local expected_tree = require("test_files/expected_tree_parametric_namespace")

            assert.are.same(tree:to_list(), expected_tree)

            assert.stub(lib.files.read).was.called_with(spec.context.results_path)
            assert.stub(logger.error).was_not_called()
        end
    )

    async.it(
        "creates neotest results for successful parametric tests and updates tree (file)",
        function()
            config.configure({ parametric_test_discovery = true })

            -- Stub nio process functions since running `busted --list` appears to be broken
            -- stub(
            --     nio.process,
            --     "run",
            --     -- Fake process object
            --     {
            --         stderr = {
            --             read = function()
            --                 return table.concat(stderr_output, "\r\n"), nil
            --             end,
            --         },
            --         result = function()
            --             return 0
            --         end,
            --     }
            -- )

            -- NOTE: neotest.lib.treesitter.parse_positions uses lib.file.read so temporarily revert it
            ---@diagnostic disable-next-line: undefined-field
            lib.files.read:revert()

            local path = parametric_test_path
            local tree = adapter.discover_positions(path)
            ---@cast tree -nil

            local parametric_test_json = table.concat(
                vim.fn.readfile("./test_files/parametric_test_output_success_file.json"),
                "\n"
            )

            stub(lib.files, "read", parametric_test_json)

            local parametric_pos_id_key1 = path .. "::namespace::1::nested::namespace::1::test::1"
            local parametric_pos_id_key2 = path .. "::namespace::1::nested::namespace::1::test::2"
            local parametric_pos_id_key3 = path .. "::namespace::1::nested::namespace::1::test::3"
            local parametric_pos_id_key4 = path
                .. "::namespace::2::nested::namespace::2::-::1::some::test"
            local parametric_pos_id_key5 = path
                .. "::namespace::2::nested::namespace::2::-::2::some::test"
            local parametric_pos_id_key6 = path
                .. "::namespace::2::nested::namespace::2::-::1::test::1"
            local parametric_pos_id_key7 = path
                .. "::namespace::2::nested::namespace::2::-::1::test::2"
            local parametric_pos_id_key8 = path
                .. "::namespace::2::nested::namespace::2::-::2::test::1"
            local parametric_pos_id_key9 = path
                .. "::namespace::2::nested::namespace::2::-::2::test::2"

            spec.context.position_id_mapping = {
                [path .. "::namespace 1 nested namespace 1 test 1::4"] = parametric_pos_id_key1,
                [path .. "::namespace 1 nested namespace 1 test 2::4"] = parametric_pos_id_key2,
                [path .. "::namespace 1 nested namespace 1 test 3::9"] = parametric_pos_id_key3,
                [path .. "::namespace 2 nested namespace 2 - 1 some test::18"] = parametric_pos_id_key4,
                [path .. "::namespace 2 nested namespace 2 - 2 some test::18"] = parametric_pos_id_key5,
                [path .. "::namespace 2 nested namespace 2 - 1 test 1::23"] = parametric_pos_id_key6,
                [path .. "::namespace 2 nested namespace 2 - 1 test 2::23"] = parametric_pos_id_key7,
                [path .. "::namespace 2 nested namespace 2 - 2 test 1::23"] = parametric_pos_id_key8,
                [path .. "::namespace 2 nested namespace 2 - 2 test 2::23"] = parametric_pos_id_key9,
            }

            local neotest_results = adapter.results(spec, strategy_result, tree)

            assert.are.same(neotest_results, {
                [path] = {
                    output = "test_console_output",
                    short = "parametric_tests_spec.lua: passed",
                    status = "passed",
                },
                [path .. "::namespace::1::nested::namespace::1::test::1"] = {
                    status = types.ResultStatus.passed,
                    short = "namespace 1 nested namespace 1 test 1: passed",
                    output = strategy_result.output,
                },
                [path .. "::namespace::1::nested::namespace::1::test::2"] = {
                    status = types.ResultStatus.passed,
                    short = "namespace 1 nested namespace 1 test 2: passed",
                    output = strategy_result.output,
                },
                [path .. "::namespace::1::nested::namespace::1::test::3"] = {
                    status = types.ResultStatus.passed,
                    short = "namespace 1 nested namespace 1 test 3: passed",
                    output = strategy_result.output,
                },
                [path .. "::namespace::2::nested::namespace::2::-::1::some::test"] = {
                    output = "test_console_output",
                    short = "namespace 2 nested namespace 2 - 1 some test: passed",
                    status = "passed",
                },
                [path .. "::namespace::2::nested::namespace::2::-::1::test::1"] = {
                    output = "test_console_output",
                    short = "namespace 2 nested namespace 2 - 1 test 1: passed",
                    status = "passed",
                },
                [path .. "::namespace::2::nested::namespace::2::-::1::test::2"] = {
                    output = "test_console_output",
                    short = "namespace 2 nested namespace 2 - 1 test 2: passed",
                    status = "passed",
                },
                [path .. "::namespace::2::nested::namespace::2::-::2::some::test"] = {
                    output = "test_console_output",
                    short = "namespace 2 nested namespace 2 - 2 some test: passed",
                    status = "passed",
                },
                [path .. "::namespace::2::nested::namespace::2::-::2::test::1"] = {
                    output = "test_console_output",
                    short = "namespace 2 nested namespace 2 - 2 test 1: passed",
                    status = "passed",
                },
                [path .. "::namespace::2::nested::namespace::2::-::2::test::2"] = {
                    output = "test_console_output",
                    short = "namespace 2 nested namespace 2 - 2 test 2: passed",
                    status = "passed",
                },
            })

            local expected_tree = require("./test_files/expected_tree_parametric_file")

            assert.are.same(tree:to_list(), expected_tree)

            assert.stub(lib.files.read).was.called_with(spec.context.results_path)
            assert.stub(logger.error).was_not_called()
        end
    )

    ---- async.it("creates neotest results for failed parametric tests and updates tree", function()
    ---- end)

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
