describe("quotes", function()
    it('single quotes test', function()
        assert.are.same(true, true)
    end)

    it([[literal quotes test]], function()
        assert.are.same(true, true)
    end)
end)
