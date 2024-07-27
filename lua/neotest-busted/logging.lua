local logging = {}

local logger = require("neotest.logging")

local log_methods = {
    "debug",
    "info",
    "warn",
    "error",
}

---@param message string
---@param level 1 | 2 | 3 | 4
function logging.log_and_notify(message, level)
    local log_method = log_methods[level]

    if not log_method then
        return
    end

    vim.schedule(function()
        logger[log_method](message)
        vim.notify(message, level)
    end)
end

return logging
