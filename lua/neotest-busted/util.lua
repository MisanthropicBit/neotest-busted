local util = {}

local lib = require("neotest.lib")

--- Trim a character in both ends of a string
---@param value string
---@param char string
---@return string
function util.trim(value, char)
    local start, _end = 1, #value

    for idx = 1, #value do
        if value:sub(idx, idx) ~= char then
            start = idx
            break
        end
    end

    for idx = #value, 1, -1 do
        if value:sub(idx, idx) ~= char then
            _end = idx
            break
        end
    end

    return value:sub(start, _end)
end

---@param ... string
---@return string
function util.create_path(...)
    return table.concat({ ... }, lib.files.sep)
end

---@param path string
---@return string[]
function util.glob(path)
    return vim.fn.split(vim.fn.glob(path, true), "\n")
end

---@param ... string
---@return string
local function normalize_and_create_lua_path(...)
    return table.concat(vim.tbl_map(vim.fs.normalize, { ... }), ";")
end

---@param package_path string lua package path type
---@param paths string[] string to add to the lua package path
---@return string[]
function util.create_package_path_argument(package_path, paths)
    if paths and #paths > 0 then
        local _path = normalize_and_create_lua_path(unpack(paths))

        return { "-c", ([[lua %s = '%s;' .. %s]]):format(package_path, _path, package_path) }
    end

    return {}
end

return util
