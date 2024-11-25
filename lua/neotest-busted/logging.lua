local logging = {}

local logger = require("neotest.logging")

local log_methods = {
    "info",
    "warn",
    "error",
}

---@param level string
---@param context table?
---@param message string
---@param ... unknown
local function log(level, context, message, ...)
    local args = { ... }

    vim.schedule(function()
        if not unpack(args) then return end
        local formatted_message = message:format(unpack(args))

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
