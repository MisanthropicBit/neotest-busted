-- NOTE: Generic classes are not just supported by luals:
-- https://github.com/LuaLS/lua-language-server/issues/1861

---@class Cache
---@field _cache table<string, unknown>
local Cache = {}

Cache.__index = Cache

---@param values table<string, unknown>?
---@return Cache
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

function Cache:size()
    return vim.tbl_count(self._cache)
end

function Cache:__pairs(tbl)
    return pairs(tbl)
end

return Cache
