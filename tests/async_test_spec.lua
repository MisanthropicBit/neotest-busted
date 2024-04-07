local async = require("neotest-busted.async")
local control = require("neotest.async").control

describe("async tests", function()
    before_each(async(function()
        vim.wait(200, function()
            return false
        end, 50)
    end))

    -- stylua: ignore start
    it("async test 1", async(function()
        vim.wait(100, function()
            return false
        end, 500)
    end, 40))

    it("async test 2", async(function()
        local timer = vim.loop.new_timer()
        local event = control.event()

        -- Print a message after 1 second
        timer:start(1000, 0, function()
            timer:stop()
            timer:close()
            vim.print("Hello from async test")
            event.set()
        end)

        event.wait()
    end))
    -- stylua: ignore end
end)
