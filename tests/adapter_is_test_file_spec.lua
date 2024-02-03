local adapter = require("neotest-busted")()

describe("adapter.is_test_file", function()
    it("matches lua test files", function()
        assert.is_true(adapter.is_test_file("./tests/init_spec.lua"))
    end)

    it("does not match plain lua file", function()
        assert.is_false(adapter.is_test_file("./lua/neotest-busted/output_handler.lua"))
        assert.is_false(adapter.is_test_file("./lua/neotest-busted/fake_spec_test.lua"))
    end)
end)
