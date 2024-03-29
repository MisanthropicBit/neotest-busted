local util = require("neotest-busted.util")
local lib = require("neotest.lib")

describe("util", function()
    describe("trim", function()
        it("trims string", function()
            assert.are.same(util.trim('"this will be trimmed"', '"'), "this will be trimmed")
            assert.are.same(
                util.trim('"this will not be trimmed"', "-"),
                '"this will not be trimmed"'
            )
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
                "lua/neotest-busted/config.lua",
                "lua/neotest-busted/health.lua",
                "lua/neotest-busted/init.lua",
                "lua/neotest-busted/output_handler.lua",
                "lua/neotest-busted/types.lua",
                "lua/neotest-busted/util.lua",
            })
        end)
    end)

    describe("create_package_path_argument", function()
        it("creates package path argument", function()
            local args = { "some/path", "some\\other/path" }

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
