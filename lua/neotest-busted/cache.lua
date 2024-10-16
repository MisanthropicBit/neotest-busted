-- NOTE: Generic classes are not yet supported by luals:
-- https://github.com/LuaLS/lua-language-server/issues/1861

---@class neotest-busted.Cache
---@field _cache table<string, unknown>
local Cache = {}

Cache.__index = Cache

---@param values table<string, unknown>?
---@return neotest-busted.Cache
function Cache.new(values)
    local cache = setmetatable({
        _cache = values or {},
    }, Cache)

    return cache
end

---@param key string
---@param value unknown
function Cache:update(key, value)
    self._cache[key] = value
end

---@param key string
function Cache:get(key)
    return self._cache[key]
end

function Cache:clear()
    self._cache = {}
end

-- NOTE: __len on tables requires 5.2 or luajit/5.1 compiled to support it
function Cache:size()
    return vim.tbl_count(self._cache)
end

function Cache:__pairs(tbl)
    return pairs(tbl)
end

return Cache
