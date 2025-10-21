local busted = require("busted")

-- A copy of the busted's base handler's getFullName function except that it
-- uses "::" as a separator instead of spaces and also preprends the full path
---@param element neotest-busted.BustedElement
---@return string
local function position_id_from_busted_element(element)
    local parent = busted.parent(element)
    local names = { element.name or element.descriptor }

    while parent and (parent.name or parent.descriptor) and parent.descriptor ~= "file" do
        table.insert(names, 1, parent.name or parent.descriptor)
        parent = busted.parent(parent)
    end

    table.insert(names, 1, element.trace.source:sub(2))
    table.insert(names, tostring(element.trace.currentline))

    -- TODO: Use another separator in case test name contains "::"?
    -- TODO: Output line number as well for finding matching source-level test
    return table.concat(names, "::")
end

---@diagnostic disable-next-line: unused-local
local printTestName = function(element, parent, status)
    if status ~= "pending" then
        print(position_id_from_busted_element(element))
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
