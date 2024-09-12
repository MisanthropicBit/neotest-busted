local Cache = require("neotest-busted.cache")

describe("Cache", function()
    it("creates a new empty cache", function()
        assert.are.same(Cache.new():size(), 0)
    end)

    it("updates and gets values", function()
        local cache = Cache.new()

        cache:update("a", 1)
        cache:update("b", 2)

        assert.are.same(cache:size(), 2)
        assert.are.same(cache:get("a"), 1)
        assert.are.same(cache:get("b"), 2)
        assert.is_nil(cache:get("c"))

        cache:update("a", 3)

        assert.are.same(cache:size(), 2)
        assert.are.same(cache:get("a"), 3)
        assert.are.same(cache:get("b"), 2)
        assert.is_nil(cache:get("c"))
    end)

    it("clears all values", function()
        local cache = Cache.new({
            a = 1,
            b = 2,
        })

        assert.are.same(cache:size(), 2)
        cache:clear()
        assert.are.same(cache:size(), 0)
    end)
end)
