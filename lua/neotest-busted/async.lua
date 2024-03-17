--- Code adapted from neotest's async library 'nio'
local async = {}

local tasks = require("nio.tasks")

local default_timeout = 2000

---@param timeout integer?
local function get_timeout(timeout)
    if timeout then
        return timeout
    end

    if vim.env.NEOTEST_BUSTED_ASYNC_TEST_TIMEOUT then
        return tonumber(vim.env.NEOTEST_BUSTED_ASYNC_TEST_TIMEOUT) or default_timeout
    end

    if vim.env.PLENARY_TEST_TIMEOUT then
        return tonumber(vim.env.PLENARY_TEST_TIMEOUT) or default_timeout
    end

    return default_timeout
end

---@param func function
---@param timeout integer?
---@return function
local function with_timeout(func, timeout)
    local _timeout = get_timeout(timeout)
    local success, err

    return function()
        local task = tasks.run(func, function(success_, err_)
            success = success_
            if not success_ then
                err = err_
            end
        end)

        vim.wait(_timeout, function()
            return success ~= nil
        end, 20, false)

        if success == nil then
            error(string.format("Test task timed out\n%s", task.trace()))
        elseif not success then
            error(string.format("Test task failed with message:\n%s", err))
        end
    end
end

return setmetatable(async, {
    __call = function(_, async_func, timeout)
        return with_timeout(async_func, timeout)
    end,
})
