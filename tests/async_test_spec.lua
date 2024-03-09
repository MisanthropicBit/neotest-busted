local async = require("neotest-busted.async")

describe("async tests", function()
    before_each(async(function()
        vim.wait(2000, function()
            vim.print("before_each")
            return false
        end, 500)
    end))

    it("async test 1", async(function()
        vim.wait(2000, function()
            vim.print("hello")
            return false
        end, 500)
    end, 40))
end)
