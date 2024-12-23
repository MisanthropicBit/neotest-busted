pending("top-level pending")

describe("pending tests", function()
    it("pending 1", function()
        pending("finish this test later")
    end)

    pending("pending 2", function()
        it("this test does not run", function() end)
    end)

    pending("pending 3")
end)
