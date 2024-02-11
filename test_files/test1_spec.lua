if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

describe("top-level namespace 1", function()
    describe("nested namespace 1", function()
        it("test 1", function()
            assert.is_true(true)
        end)

        it("test 2", function()
            assert.is_false(false)
        end)
    end)
end)

describe("^top-le[ve]l (na*m+e-sp?ac%e) 2$", function()
    it("test 3", function()
        assert.is_true(true)
    end)

    it("test 4", function()
        assert.is_false(false)
    end)
end)
