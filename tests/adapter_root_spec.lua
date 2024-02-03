local async = require("nio").tests
local adapter = require("neotest-busted")()

describe("adapter.root", function()
    async.it("recognises root", function()
        assert.not_nil(adapter.root("."))
        assert.not_nil(adapter.root("./lua"))
        assert.not_nil(adapter.root("./tests"))
    end)
end)
