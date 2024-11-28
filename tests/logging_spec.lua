local logging = require("neotest-busted.logging")

local logger = require("neotest.logging")
local stub = require("luassert.stub")

describe("logging", function()
    before_each(function()
        stub(vim, "schedule", function(func)
            func()
        end)

        stub(logger, "error")
        stub(vim, "notify")
    end)

    after_each(function()
        ---@diagnostic disable-next-line: undefined-field
        vim.schedule:revert()
        ---@diagnostic disable-next-line: undefined-field
        logger.error:revert()
        ---@diagnostic disable-next-line: undefined-field
        vim.notify:revert()
    end)

    it("logs with no additional arguments", function()
        logging.error("Hello")

        assert.stub(logger.error).was.called_with("Hello", nil)
        assert.stub(vim.notify).was.called_with("Hello", vim.log.levels.ERROR)
    end)

    it("logs with additional arguments", function()
        logging.error("Hello %s", {}, "world")

        assert.stub(logger.error).was.called_with("Hello world", {})
        assert.stub(vim.notify).was.called_with("Hello world", vim.log.levels.ERROR)
    end)

    it("logs with nil argument", function()
        logging.error("Hello", nil, nil)

        assert.stub(logger.error).was.called_with("Hello", nil)
        assert.stub(vim.notify).was.called_with("Hello", vim.log.levels.ERROR)
    end)
end)
