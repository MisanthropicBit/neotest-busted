local busted = require("busted")
local util = require("neotest-busted.util")

---@diagnostic disable-next-line: unused-local
local printTestName = function(element, parent, status)
    if status ~= "pending" then
        print(util.position_id_from_busted_element(element, true))
    end

    return nil, false
end

local noop = function() end

local stubOut = function(descriptor, name, fn, ...)
    if fn == noop then
        return nil, true
    end
    busted.publish({ "register", descriptor }, name, noop, ...)
    return nil, false
end

local ignoreAll = function()
    return nil, false
end

---@diagnostic disable-next-line: unused-local
local applyDescFilter = function(descriptors, name, fn)
    for _, descriptor in ipairs(descriptors) do
        local f = function(...)
            return fn(descriptor, ...)
        end
        busted.subscribe({ "register", descriptor }, f, { priority = 1 })
    end
end

busted.subscribe({ "suite", "start" }, ignoreAll, { priority = 1 })
busted.subscribe({ "suite", "end" }, ignoreAll, { priority = 1 })
busted.subscribe({ "file", "start" }, ignoreAll, { priority = 1 })
busted.subscribe({ "file", "end" }, ignoreAll, { priority = 1 })
busted.subscribe({ "describe", "start" }, ignoreAll, { priority = 1 })
busted.subscribe({ "describe", "end" }, ignoreAll, { priority = 1 })
busted.subscribe({ "test", "start" }, ignoreAll, { priority = 1 })
busted.subscribe({ "test", "end" }, printTestName, { priority = 1 })
applyDescFilter({ "setup", "teardown", "before_each", "after_each" }, "list", stubOut)
applyDescFilter({ "lazy_setup", "lazy_teardown" }, "list", stubOut)
applyDescFilter({ "strict_setup", "strict_teardown" }, "list", stubOut)
applyDescFilter({ "it", "pending" }, "list", stubOut)
