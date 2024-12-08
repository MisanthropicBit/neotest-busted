describe("pending tests", function()
    it("pending 1", function()
        pending("finish this test later")
        error("this should not run")
    end)

    pending("pending 2", function()
        it("this test does not run", function()
            error("this should not run")
        end)
    end)

    pending("pending 3")
end)
