local logging = {}

local config = require("neotest-busted.config")
local logger = require("neotest.logging")

local log_methods = {
    "info",
    "warn",
    "error",
}

---@param func fun()
local function schedule(func)
    if config.no_nvim then
        func()
    else
        vim.schedule(func)
    end
end

---@param level string
---@param context table?
---@param message string
---@param ... unknown
local function log(level, context, message, ...)
    local formatted_message = message:format(...)

    schedule(function()
        logger[level](formatted_message, context)
        vim.notify(formatted_message, vim.log.levels[level:upper()])
    end)
end

for _, name in ipairs(log_methods) do
    logging[name] = function(message, context, ...)
        log(name, context, message, ...)
    end
end

return logging
