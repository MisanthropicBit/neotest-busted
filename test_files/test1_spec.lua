local nio = require("nio")
local async = nio.tests

describe("top-level namespace 1", function()
    describe("nested namespace 1", function()
        it("test 1", function()
            pending()
            assert.is_true(true)
        end)

        async.it("test 2", function()
            assert.is_false(false)
        end)
    end)
end)

describe("^top-le[ve]l (na*m+e-sp?ac%e) 2$", function()
    it("test 3", function()
        assert.is_true(false)
    end)

    it("test 4", function()
        assert.is_false(true)
    end)
end)
