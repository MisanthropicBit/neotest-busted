local nio = require("nio")
local a = require("nio.tests")
local async = require("nio.tests")
local control = require("neotest.async").control
local compat = require("neotest-busted.compat")

describe("nio async tests", function()
    before_each(function()
        vim.wait(200, function()
            return false
        end, 50)
    end)

    -- stylua: ignore start
    async.it("async test 1", function()
        vim.wait(100, function()
            return false
        end, 500)
    end, 40)

    nio.tests.it("async test 2", function()
        local timer = compat.uv.new_timer() ---@cast timer -nil
        local event = control.event()

        -- Print a message after 200 milliseconds
        timer:start(200, 0, function()
            timer:stop()
            timer:close()
            vim.print("Hello from async test")
            event.set()
        end)

        event.wait()
    end)

    a.it("async test 3", function()
        vim.wait(100, function()
            return false
        end, 500)
    end, 40)
    -- stylua: ignore end
end)
