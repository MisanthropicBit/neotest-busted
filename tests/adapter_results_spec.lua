local async = require("neotest.async").tests
local lib = require("neotest.lib")
local logger = require("neotest.logging")
local types = require("neotest.types")
local stub = require("luassert.stub")

local adapter = require("neotest-busted")()

describe("adapter.results", function()
    local test_path = "/Users/user/vim/project/tests/test_spec.lua"

    local spec = {
        context = {
            results_path = "test_output.json",
            position_ids = {
                [test_path .. "::namespace tests a pending test::5"] = test_path .. '::"namespace"::"tests a pending test"',
                [test_path .. "::namespace tests a passing test::6"] = test_path .. '::"namespace"::"tests a passing test"',
                [test_path .. "::namespace tests a failing test::7"] = test_path .. '::"namespace"::"tests a failing test"',
                [test_path .. "::namespace tests an erroneous test::10"] = test_path .. '::"namespace"::"tests an erroneous test"',
            },
        },
    }

    local strategy_result = {
        output = "test_console_output",
    }

    before_each(function()
        local test_json = [[{
    "pendings": [
        {
            "name": "namespace tests a pending test",
            "element": {
                "name": "tests a pending test",
                "trace": {
                    "source": "@/Users/user/vim/project/tests/test_spec.lua",
                    "currentline": 5
                }
            },
            "trace": {
                "message": ""
            }
        }
    ],
    "successes": [
        {
            "name": "namespace tests a passing test",
            "element": {
                "name": "tests a passing test",
                "trace": {
                    "source": "@/Users/user/vim/project/tests/test_spec.lua",
                    "currentline": 6
                }
            },
            "trace": {
                "message": ""
            }
        }
    ],
    "failures": [
        {
            "name": "namespace tests a failing test",
            "element": {
                "name": "tests a failing test",
                "trace": {
                    "source": "@/Users/user/vim/project/tests/test_spec.lua",
                    "currentline": 7
                }
            },
            "message": "Test failed at test_spec.lua:8: ...",
            "trace": {
                "message": "Assert failed"
            }
        }
    ],
    "errors": [
        {
            "name": "namespace tests an erroneous test",
            "element": {
                "name": "tests an erroneous test",
                "trace": {
                    "source": "@/Users/user/vim/project/tests/test_spec.lua",
                    "currentline": 10
                }
            },
            "message": "Something went wrong in test_spec.lua:12: ...",
            "trace": {
                "message": "Oh noes"
            }
        }
    ]
}]]

        stub(lib.files, "read", test_json)
        stub(logger, "error")
    end)

    after_each(function()
        lib.files.read:revert()
        logger.error:revert()
    end)

    async.it("creates neotest results", function()
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
            [test_path .. '::"namespace"::"tests a failing test"'] = {
                status = types.ResultStatus.failed,
                short = "namespace tests a failing test: failed",
                output = strategy_result.output,
                errors = {
                    {
                        message = "Assert failed",
                        line = 7,
                    }
                }
            },
            [test_path .. '::"namespace"::"tests an erroneous test"'] = {
                status = types.ResultStatus.failed,
                short = "namespace tests an erroneous test: failed",
                output = strategy_result.output,
                errors = {
                    {
                        message = "Oh noes",
                        line = 11,
                    }
                }
            },
        })

        assert.stub(lib.files.read).was.called_with(spec.context.results_path)
        assert.stub(logger.error).was_not_called()
    end)

    it("handles failure to read json test output", function()
        stub(lib.files, "read", function()
            error("Could not read file", 0)
        end)

        local neotest_results = adapter.results(spec, strategy_result)

        assert.are.same(neotest_results, {})

        assert.stub(lib.files.read).was.called_with(spec.context.results_path)
        assert.stub(logger.error).was.called_with("Failed to read json test output file ", "test_output.json", " with error: ", "Could not read file")
    end)

    it("handles failure to decode json", function()
        stub(vim.json, "decode", function()
            error("Expected value but found invalid token at character 1", 0)
        end)

        local neotest_results = adapter.results(spec, strategy_result)

        assert.are.same(neotest_results, {})

        assert.stub(lib.files.read).was.called_with(spec.context.results_path)
        assert.stub(logger.error).was.called_with("Failed to parse json test output file ", "test_output.json", " with error: ", "Expected value but found invalid token at character 1")

        vim.json.decode:revert()
    end)

    it("logs not finding a matching position id", function()
        spec.context.position_ids[test_path .. "::namespace tests a failing test::7"] = nil

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
                    }
                }
            },
        })

        assert.stub(lib.files.read).was.called_with(spec.context.results_path)
        assert.stub(logger.error).was.called_with("Failed to find matching position id for key ", test_path .. "::namespace tests a failing test::7")
    end)
end)
