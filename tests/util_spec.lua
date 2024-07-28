local util = require("neotest-busted.util")
local lib = require("neotest.lib")

describe("util", function()
    -- TODO: Test new util functions

    describe("trim_quotes", function()
        it("trims quotes", function()
            assert.are.same(util.trim_quotes('"this will be trimmed"'), "this will be trimmed")

            assert.are.same(
                util.trim_quotes('this will not be trimmed'),
                'this will not be trimmed'
            )
        end)
    end)

    describe("longest_common_prefix", function()
        it("finds longest common prefix", function()
            local value1 = { "path", "des1", "des2", "des3", '("test %d"):format(i)' }
            local value2 = { "path", "des1", "des2", "des3", "test 1" }
            local prefix = util.longest_common_prefix(value1, value2)

            assert.are.same(prefix, vim.list_slice(value1, 1, 4))
        end)

        it("finds longest common prefix with items of different lengths", function()

        end)

        it("finds no common prefix", function()

        end)
    end)

    describe("create_path", function()
        it("creates paths using os-specific path separator", function()
            assert.are.same(util.create_path("some", "path"), "some" .. lib.files.sep .. "path")
        end)
    end)

    describe("glob", function()
        it("globs", function()
            local path = util.create_path("lua", "**", "*.lua")

            assert.are.same(util.glob(path), {
                "lua/neotest-busted/async.lua",
                "lua/neotest-busted/busted-util.lua",
                "lua/neotest-busted/config.lua",
                "lua/neotest-busted/health.lua",
                "lua/neotest-busted/init.lua",
                "lua/neotest-busted/logging.lua",
                "lua/neotest-busted/output_handler.lua",
                "lua/neotest-busted/start_debug.lua",
                "lua/neotest-busted/types.lua",
                "lua/neotest-busted/util.lua",
            })
        end)
    end)

    describe("create_package_path_argument", function()
        it("creates package path argument", function()
            local args = { "some/path", "some/other/path" }

            assert.are.same(util.create_package_path_argument("package.path", args), {
                "-c",
                "lua package.path = 'some/path;some/other/path;' .. package.path",
            })
        end)

        it("handles nil or empty array", function()
            ---@diagnostic disable-next-line: param-type-mismatch
            assert.are.same(util.create_package_path_argument("package.path", nil), {})
            assert.are.same(util.create_package_path_argument("package.path", {}), {})
        end)
    end)
end)
