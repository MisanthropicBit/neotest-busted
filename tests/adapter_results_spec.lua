local async = require("neotest.async").tests
local lib = require("neotest.lib")
local logger = require("neotest.logging")
local types = require("neotest.types")
local stub = require("luassert.stub")
local test_utils = require("neotest-busted.test_utils")

test_utils.prepare_vim_treesitter()

---@type neotest.Adapter
local adapter = require("neotest-busted")()
local config = require("neotest-busted.config")

describe("adapter.results", function()
    local parametric_test_path = "./test_files/parametric_tests_spec.lua"
    local spec = {}
    local strategy_result = {
        output = "test_console_output",
    }

    ---@param test_path string
    ---@param json_path string
    ---@return neotest.Tree
    local function discover_positions(test_path, json_path)
        local tree = adapter.discover_positions(test_path)
        local test_json = table.concat(vim.fn.readfile(json_path), "\n")

        stub(lib.files, "read", test_json)

        ---@cast tree -nil
        return tree
    end

    before_each(function()
        assert:set_parameter("TableFormatLevel", 10)

        spec = {
            context = {
                results_path = "test_output.json",
                position_id_mapping = {},
            },
        }

        config.configure()

        stub(logger, "error")
    end)

    after_each(function()
        ---@diagnostic disable-next-line: undefined-field
        logger.error:revert()
    end)

    async.it("creates neotest results", function()
        local path = "./test_files/test1_spec.lua"
        local tree = discover_positions(path, "./test_files/busted_test_output.json")

        spec.context.position_id_mapping = {
            [path .. "::top-level namespace 1 nested namespace 1 test 1::3"] = path
                .. '::"top-level namespace 1"::"nested namespace 1"::"test 1"',
            [path .. "::top-level namespace 1 nested namespace 1 test 2::8"] = path
                .. '::"top-level namespace 1"::"nested namespace 1"::"test 2"',
            [path .. "::^top-le[ve]l (na*m+e-sp?ac%e) 2$ test 3::15"] = path
                .. '::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 3"',
            [path .. "::^top-le[ve]l (na*m+e-sp?ac%e) 2$ test 4::19"] = path
                .. '::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 4"',
        }

        local neotest_results = adapter.results(spec, strategy_result, tree)

        assert.are.same(neotest_results, {
            [path .. '::"top-level namespace 1"::"nested namespace 1"::"test 1"'] = {
                status = types.ResultStatus.skipped,
                short = "top-level namespace 1 nested namespace 1 test 1: skipped",
                output = strategy_result.output,
            },
            [path .. '::"top-level namespace 1"::"nested namespace 1"::"test 2"'] = {
                status = types.ResultStatus.passed,
                short = "top-level namespace 1 nested namespace 1 test 2: passed",
                output = strategy_result.output,
            },
            [path .. '::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 3"'] = {
                status = types.ResultStatus.failed,
                short = "^top-le[ve]l (na*m+e-sp?ac%e) 2$ test 3: failed",
                output = strategy_result.output,
                errors = {
                    {
                        message = "...rojects/vim/neotest-busted/test_files/test1_spec.lua:16: Expected objects to be the same.\nPassed in:\n(boolean) false\nExpected:\n(boolean) true",
                        line = 15,
                    },
                },
            },
            [path .. '::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 4"'] = {
                status = types.ResultStatus.failed,
                short = "^top-le[ve]l (na*m+e-sp?ac%e) 2$ test 4: failed",
                output = strategy_result.output,
                errors = {
                    {
                        message = "...rojects/vim/neotest-busted/test_files/test1_spec.lua:20: Expected objects to be the same.\nPassed in:\n(boolean) true\nExpected:\n(boolean) false",
                        line = 19,
                    },
                },
            },
        })

        local expected_tree = require("./test_files/expected_tree")

        -- Tree remains unchanged
        assert.are.same(tree:to_list(), expected_tree)

        assert.stub(lib.files.read).was.called_with(spec.context.results_path)
        assert.stub(logger.error).was_not_called()

        ---@diagnostic disable-next-line: undefined-field
        lib.files.read:revert()
    end)

    async.it("creates neotest results with single and literal quotes", function()
        local path = "./test_files/quotes_spec.lua"
        local tree = discover_positions(path, "./test_files/quotes_spec.json")

        spec.context.position_id_mapping = {
            [path .. "::quotes single quotes test::2"] = path
                .. "::\"quotes\"::'single quotes test'",
            [path .. "::quotes literal quotes test::6"] = path
                .. '::"quotes"::[[literal quotes test]]',
        }

        local neotest_results = adapter.results(spec, strategy_result, tree)

        assert.are.same(neotest_results, {
            [path .. "::\"quotes\"::'single quotes test'"] = {
                status = types.ResultStatus.passed,
                short = "quotes single quotes test: passed",
                output = strategy_result.output,
            },
            [path .. '::"quotes"::[[literal quotes test]]'] = {
                status = types.ResultStatus.passed,
                short = "quotes literal quotes test: passed",
                output = strategy_result.output,
            },
        })

        local expected_tree = require("./test_files/quotes_expected_tree")

        -- Tree remains unchanged
        assert.are.same(tree:to_list(), expected_tree)

        assert.stub(lib.files.read).was.called_with(spec.context.results_path)
        assert.stub(logger.error).was_not_called()

        ---@diagnostic disable-next-line: undefined-field
        lib.files.read:revert()
    end)

    async.it(
        "creates neotest results for successful parametric tests and updates tree (test)",
        function()
            config.configure({ parametric_test_discovery = true })

            local path = parametric_test_path
            local tree =
                discover_positions(path, "./test_files/parametric_test_output_success_test.json")

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

            local expected_tree = require("./test_files/expected_tree_parametric_test")(path)

            assert.are.same(tree:to_list(), expected_tree)

            assert.stub(lib.files.read).was.called_with(spec.context.results_path)
            assert.stub(logger.error).was_not_called()

            ---@diagnostic disable-next-line: undefined-field
            lib.files.read:revert()
        end
    )

    async.it(
        "creates neotest results for successful parametric tests and updates tree (namespace)",
        function()
            config.configure({ parametric_test_discovery = true })

            local path = parametric_test_path
            local tree = discover_positions(
                path,
                "./test_files/parametric_test_output_success_namespace.json"
            )

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
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 1 some test: passed",
                    status = "passed",
                },
                [path .. "::namespace::2::nested::namespace::2::-::1::test::1"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 1 test 1: passed",
                    status = "passed",
                },
                [path .. "::namespace::2::nested::namespace::2::-::1::test::2"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 1 test 2: passed",
                    status = "passed",
                },
                [path .. "::namespace::2::nested::namespace::2::-::2::some::test"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 2 some test: passed",
                    status = "passed",
                },
                [path .. "::namespace::2::nested::namespace::2::-::2::test::1"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 2 test 1: passed",
                    status = "passed",
                },
                [path .. "::namespace::2::nested::namespace::2::-::2::test::2"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 2 test 2: passed",
                    status = "passed",
                },
            })

            local expected_tree = require("./test_files/expected_tree_parametric_namespace")(path)

            assert.are.same(tree:to_list(), expected_tree)

            assert.stub(lib.files.read).was.called_with(spec.context.results_path)
            assert.stub(logger.error).was_not_called()

            ---@diagnostic disable-next-line: undefined-field
            lib.files.read:revert()
        end
    )

    async.it(
        "creates neotest results for successful parametric tests and updates tree (file)",
        function()
            config.configure({ parametric_test_discovery = true })

            local path = parametric_test_path
            local tree =
                discover_positions(path, "./test_files/parametric_test_output_success_file.json")

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
                    status = "passed",
                    short = "parametric_tests_spec.lua: passed",
                    output = strategy_result.output,
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
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 1 some test: passed",
                    status = "passed",
                },
                [path .. "::namespace::2::nested::namespace::2::-::1::test::1"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 1 test 1: passed",
                    status = "passed",
                },
                [path .. "::namespace::2::nested::namespace::2::-::1::test::2"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 1 test 2: passed",
                    status = "passed",
                },
                [path .. "::namespace::2::nested::namespace::2::-::2::some::test"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 2 some test: passed",
                    status = "passed",
                },
                [path .. "::namespace::2::nested::namespace::2::-::2::test::1"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 2 test 1: passed",
                    status = "passed",
                },
                [path .. "::namespace::2::nested::namespace::2::-::2::test::2"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 2 test 2: passed",
                    status = "passed",
                },
            })

            local expected_tree = require("./test_files/expected_tree_parametric_file")(path)

            assert.are.same(tree:to_list(), expected_tree)

            assert.stub(lib.files.read).was.called_with(spec.context.results_path)
            assert.stub(logger.error).was_not_called()

            ---@diagnostic disable-next-line: undefined-field
            lib.files.read:revert()
        end
    )

    async.it(
        "creates neotest results for failed parametric tests and updates tree (test)",
        function()
            config.configure({ parametric_test_discovery = true })

            local path = "./test_files/parametric_tests_fail_spec.lua"
            local tree =
                discover_positions(path, "./test_files/parametric_test_output_fail_test.json")

            -- Get the subtree rooted at the the first parametric test in the file
            local subtree = tree:children()[1]:children()[1]:children()[1]
            assert.is_not_nil(subtree)

            local parametric_pos_id_key1 = path .. "::namespace::1::nested::namespace::1::test::1"
            local parametric_pos_id_key2 = path .. "::namespace::1::nested::namespace::1::test::2"

            spec.context.position_id_mapping = {
                [path .. "::namespace 1 nested namespace 1 test 1::4"] = parametric_pos_id_key1,
                [path .. "::namespace 1 nested namespace 1 test 2::4"] = parametric_pos_id_key2,
            }

            local neotest_results = adapter.results(spec, strategy_result, subtree)

            assert.are.same(neotest_results, {
                [path .. '::"namespace 1"::"nested namespace 1"::("test %d"):format(i)'] = {
                    status = types.ResultStatus.failed,
                    short = '("test %d"):format(i): failed',
                    output = strategy_result.output,
                },
                [parametric_pos_id_key1] = {
                    status = types.ResultStatus.failed,
                    short = "namespace 1 nested namespace 1 test 1: failed",
                    output = strategy_result.output,
                    errors = {
                        {
                            message = "./test_files/parametric_tests_fail_spec.lua:5: Expected objects to be the same.\nPassed in:\n(boolean) true\nExpected:\n(boolean) false",
                            line = 4,
                        },
                    },
                },
                [parametric_pos_id_key2] = {
                    status = types.ResultStatus.failed,
                    short = "namespace 1 nested namespace 1 test 2: failed",
                    output = strategy_result.output,
                    errors = {
                        {
                            message = "./test_files/parametric_tests_fail_spec.lua:5: Expected objects to be the same.\nPassed in:\n(boolean) true\nExpected:\n(boolean) false",
                            line = 4,
                        },
                    },
                },
            })

            local expected_tree = require("./test_files/expected_tree_parametric_test")(path)

            assert.are.same(tree:to_list(), expected_tree)

            assert.stub(lib.files.read).was.called_with(spec.context.results_path)
            assert.stub(logger.error).was_not_called()

            ---@diagnostic disable-next-line: undefined-field
            lib.files.read:revert()
        end
    )

    async.it(
        "creates neotest results for failed parametric tests and updates tree (namespace)",
        function()
            config.configure({ parametric_test_discovery = true })

            local path = "./test_files/parametric_tests_fail_spec.lua"
            local tree =
                discover_positions(path, "./test_files/parametric_test_output_fail_namespace.json")

            -- Get the subtree rooted at the the first parametric namespace in the file
            local subtree = tree:children()[2]:children()[1]
            assert.is_not_nil(subtree)

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
                    status = types.ResultStatus.failed,
                    short = '"nested namespace 2 - " .. tostring(i): failed',
                    output = strategy_result.output,
                },
                [path .. "::namespace::2::nested::namespace::2::-::1::some::test"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 1 some test: failed",
                    status = "failed",
                    errors = {
                        {
                            message = "./test_files/parametric_tests_fail_spec.lua:19: Expected objects to be the same.\nPassed in:\n(boolean) false\nExpected:\n(boolean) true",
                            line = 18,
                        },
                    },
                },
                [path .. "::namespace::2::nested::namespace::2::-::1::test::1"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 1 test 1: failed",
                    status = "failed",
                    errors = {
                        {
                            message = "./test_files/parametric_tests_fail_spec.lua:24: Expected objects to be the same.\nPassed in:\n(boolean) false\nExpected:\n(boolean) true",
                            line = 23,
                        },
                    },
                },
                [path .. "::namespace::2::nested::namespace::2::-::1::test::2"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 1 test 2: failed",
                    status = "failed",
                    errors = {
                        {
                            message = "./test_files/parametric_tests_fail_spec.lua:24: Expected objects to be the same.\nPassed in:\n(boolean) false\nExpected:\n(boolean) true",
                            line = 23,
                        },
                    },
                },
                [path .. "::namespace::2::nested::namespace::2::-::2::some::test"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 2 some test: failed",
                    status = "failed",
                    errors = {
                        {
                            message = "./test_files/parametric_tests_fail_spec.lua:19: Expected objects to be the same.\nPassed in:\n(boolean) false\nExpected:\n(boolean) true",
                            line = 18,
                        },
                    },
                },
                [path .. "::namespace::2::nested::namespace::2::-::2::test::1"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 2 test 1: failed",
                    status = "failed",
                    errors = {
                        {
                            message = "./test_files/parametric_tests_fail_spec.lua:24: Expected objects to be the same.\nPassed in:\n(boolean) false\nExpected:\n(boolean) true",
                            line = 23,
                        },
                    },
                },
                [path .. "::namespace::2::nested::namespace::2::-::2::test::2"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 2 test 2: failed",
                    status = "failed",
                    errors = {
                        {
                            message = "./test_files/parametric_tests_fail_spec.lua:24: Expected objects to be the same.\nPassed in:\n(boolean) false\nExpected:\n(boolean) true",
                            line = 23,
                        },
                    },
                },
            })

            local expected_tree = require("./test_files/expected_tree_parametric_namespace")(path)

            assert.are.same(tree:to_list(), expected_tree)

            assert.stub(lib.files.read).was.called_with(spec.context.results_path)
            assert.stub(logger.error).was_not_called()

            ---@diagnostic disable-next-line: undefined-field
            lib.files.read:revert()
        end
    )

    async.it(
        "creates neotest results for failed parametric tests and updates tree (file)",
        function()
            config.configure({ parametric_test_discovery = true })

            local path = "./test_files/parametric_tests_fail_spec.lua"
            local tree =
                discover_positions(path, "./test_files/parametric_test_output_fail_file.json")

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
                    status = types.ResultStatus.failed,
                    short = "parametric_tests_fail_spec.lua: failed",
                    output = strategy_result.output,
                },
                [path .. "::namespace::1::nested::namespace::1::test::1"] = {
                    status = types.ResultStatus.failed,
                    short = "namespace 1 nested namespace 1 test 1: failed",
                    output = strategy_result.output,
                    errors = {
                        {
                            message = "./test_files/parametric_tests_fail_spec.lua:5: Expected objects to be the same.\nPassed in:\n(boolean) true\nExpected:\n(boolean) false",
                            line = 4,
                        },
                    },
                },
                [path .. "::namespace::1::nested::namespace::1::test::2"] = {
                    status = types.ResultStatus.failed,
                    short = "namespace 1 nested namespace 1 test 2: failed",
                    output = strategy_result.output,
                    errors = {
                        {
                            message = "./test_files/parametric_tests_fail_spec.lua:5: Expected objects to be the same.\nPassed in:\n(boolean) true\nExpected:\n(boolean) false",
                            line = 4,
                        },
                    },
                },
                [path .. "::namespace::1::nested::namespace::1::test::3"] = {
                    status = types.ResultStatus.failed,
                    short = "namespace 1 nested namespace 1 test 3: failed",
                    output = strategy_result.output,
                    errors = {
                        {
                            message = "./test_files/parametric_tests_fail_spec.lua:10: Expected objects to be the same.\nPassed in:\n(boolean) true\nExpected:\n(boolean) false",
                            line = 9,
                        },
                    },
                },
                [path .. "::namespace::2::nested::namespace::2::-::1::some::test"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 1 some test: failed",
                    status = "failed",
                    errors = {
                        {
                            message = "./test_files/parametric_tests_fail_spec.lua:19: Expected objects to be the same.\nPassed in:\n(boolean) false\nExpected:\n(boolean) true",
                            line = 18,
                        },
                    },
                },
                [path .. "::namespace::2::nested::namespace::2::-::1::test::1"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 1 test 1: failed",
                    status = "failed",
                    errors = {
                        {
                            message = "./test_files/parametric_tests_fail_spec.lua:24: Expected objects to be the same.\nPassed in:\n(boolean) false\nExpected:\n(boolean) true",
                            line = 23,
                        },
                    },
                },
                [path .. "::namespace::2::nested::namespace::2::-::1::test::2"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 1 test 2: failed",
                    status = "failed",
                    errors = {
                        {
                            message = "./test_files/parametric_tests_fail_spec.lua:24: Expected objects to be the same.\nPassed in:\n(boolean) false\nExpected:\n(boolean) true",
                            line = 23,
                        },
                    },
                },
                [path .. "::namespace::2::nested::namespace::2::-::2::some::test"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 2 some test: failed",
                    status = "failed",
                    errors = {
                        {
                            message = "./test_files/parametric_tests_fail_spec.lua:19: Expected objects to be the same.\nPassed in:\n(boolean) false\nExpected:\n(boolean) true",
                            line = 18,
                        },
                    },
                },
                [path .. "::namespace::2::nested::namespace::2::-::2::test::1"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 2 test 1: failed",
                    status = "failed",
                    errors = {
                        {
                            message = "./test_files/parametric_tests_fail_spec.lua:24: Expected objects to be the same.\nPassed in:\n(boolean) false\nExpected:\n(boolean) true",
                            line = 23,
                        },
                    },
                },
                [path .. "::namespace::2::nested::namespace::2::-::2::test::2"] = {
                    output = strategy_result.output,
                    short = "namespace 2 nested namespace 2 - 2 test 2: failed",
                    status = "failed",
                    errors = {
                        {
                            message = "./test_files/parametric_tests_fail_spec.lua:24: Expected objects to be the same.\nPassed in:\n(boolean) false\nExpected:\n(boolean) true",
                            line = 23,
                        },
                    },
                },
            })

            local expected_tree = require("./test_files/expected_tree_parametric_file")(path)

            assert.are.same(tree:to_list(), expected_tree)

            assert.stub(lib.files.read).was.called_with(spec.context.results_path)
            assert.stub(logger.error).was_not_called()

            ---@diagnostic disable-next-line: undefined-field
            lib.files.read:revert()
        end
    )

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

        ---@diagnostic disable-next-line: undefined-field
        vim.schedule:revert()
        ---@diagnostic disable-next-line: undefined-field
        vim.notify:revert()
        ---@diagnostic disable-next-line: undefined-field
        lib.files.read:revert()
    end)

    it("handles failure to decode json", function()
        stub(vim, "schedule", function(func)
            func()
        end)

        stub(vim, "notify")
        stub(lib.files, "read", '{"a".}')

        -- stub(vim.json, "decode", function()
        --     error("Expected value but found invalid token at character 1", 0)
        -- end)

        ---@diagnostic disable-next-line: missing-parameter
        local neotest_results = adapter.results(spec, strategy_result)

        assert.are.same(neotest_results, {})

        assert.stub(vim.schedule).was.called()
        assert.stub(vim.notify).was.called()
        assert.stub(lib.files.read).was.called_with(spec.context.results_path)
        assert.stub(logger.error).was.called_with(
            "Failed to parse json test output file test_output.json with error: Expected colon but found invalid token at character 5",
            nil
        )
        assert.stub(lib.files.read).was.called_with(spec.context.results_path)

        ---@diagnostic disable-next-line: undefined-field
        vim.schedule:revert()
        ---@diagnostic disable-next-line: undefined-field
        vim.notify:revert()
        ---@diagnostic disable-next-line: undefined-field
        lib.files.read:revert()
    end)

    it("logs not finding a matching position id", function()
        stub(vim, "schedule", function(func)
            func()
        end)

        stub(vim, "notify")

        stub(lib.files, "read", function()
            return table.concat(vim.fn.readfile("./test_files/busted_test_output.json"), "\n")
        end)

        local path = "./test_files/test1_spec.lua"
        -- spec.context.position_id_mapping[path .. "::namespace tests a failing test::7"] = nil

        spec.context.position_id_mapping = {
            [path .. "::top-level namespace 1 nested namespace 1 test 2::8"] = path
                .. '::"top-level namespace 1"::"nested namespace 1"::"test 2"',
            [path .. "::^top-le[ve]l (na*m+e-sp?ac%e) 2$ test 3::15"] = path
                .. '::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 3"',
            [path .. "::^top-le[ve]l (na*m+e-sp?ac%e) 2$ test 4::19"] = path
                .. '::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 4"',
        }

        ---@diagnostic disable-next-line: missing-parameter
        local neotest_results = adapter.results(spec, strategy_result)

        assert.are.same(neotest_results, {
            [path .. '::"top-level namespace 1"::"nested namespace 1"::"test 2"'] = {
                status = types.ResultStatus.passed,
                short = "top-level namespace 1 nested namespace 1 test 2: passed",
                output = strategy_result.output,
            },
            [path .. '::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 3"'] = {
                status = types.ResultStatus.failed,
                short = "^top-le[ve]l (na*m+e-sp?ac%e) 2$ test 3: failed",
                output = strategy_result.output,
                errors = {
                    {
                        message = "...rojects/vim/neotest-busted/test_files/test1_spec.lua:16: Expected objects to be the same.\nPassed in:\n(boolean) false\nExpected:\n(boolean) true",
                        line = 15,
                    },
                },
            },
            [path .. '::"^top-le[ve]l (na*m+e-sp?ac%e) 2$"::"test 4"'] = {
                status = types.ResultStatus.failed,
                short = "^top-le[ve]l (na*m+e-sp?ac%e) 2$ test 4: failed",
                output = strategy_result.output,
                errors = {
                    {
                        message = "...rojects/vim/neotest-busted/test_files/test1_spec.lua:20: Expected objects to be the same.\nPassed in:\n(boolean) true\nExpected:\n(boolean) false",
                        line = 19,
                    },
                },
            },
        })

        assert.stub(vim.schedule).was.called()
        assert.stub(vim.notify).was.called()
        assert.stub(lib.files.read).was.called_with(spec.context.results_path)
        assert.stub(logger.error).was.called_with(
            "Failed to find matching position id for key "
                .. path
                .. "::top-level namespace 1 nested namespace 1 test 1::3",
            nil
        )

        ---@diagnostic disable-next-line: undefined-field
        vim.schedule:revert()
        ---@diagnostic disable-next-line: undefined-field
        vim.notify:revert()
    end)
end)
