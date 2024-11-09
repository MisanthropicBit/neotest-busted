describe("namespace 1", function()
    describe("nested namespace 1", function()
        for i = 1, 2 do
            it(("test %d"):format(i), function()
                assert.is_false(true)
            end)
        end

        it("test " .. "3", function()
            assert.is_false(true)
        end)
    end)
end)

describe("namespace 2", function()
    for i = 1, 2 do
        describe("nested namespace 2 - " .. tostring(i), function()
            it("some test", function()
                assert.is_true(false)
            end)

            for j = 1, 2 do
                it(("test %d"):format(j), function()
                    assert.is_true(false)
                end)
            end
        end)
    end
end)
