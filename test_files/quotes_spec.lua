describe("quotes", function()
    -- stylua: ignore start
    it('single quotes test', function()
        -- stylua: ignore end
        assert.are.same(true, true)
    end)

    it([[literal quotes test]], function()
        assert.are.same(true, true)
    end)
end)
