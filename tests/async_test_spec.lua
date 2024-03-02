local async = require("neotest.async").tests

_G.it = it

describe("async tests", function()
    async.it("async test 1", function()
        vim.wait(1500, function()
            vim.print("hello")
            return false
        end, 500)
    end)
end)
