local util = {}

local lib = require("neotest.lib")

local trim_chars = { "'", '"' }

--- Trim quotes from a string
---@param value string
---@return string
function util.trim_quotes(value)
    for _, trim_char in ipairs(trim_chars) do
        if value:sub(1, 1) == trim_char and value:sub(#value, #value) == trim_char then
            return value:sub(2, #value - 1)
        end
    end

    if vim.startswith(value, "[[") and vim.endswith(value, "]]") then
        return value:sub(3, #value - 3)
    end

    return value
end

---@param ... string
---@return string
function util.create_path(...)
    return table.concat({ ... }, lib.files.sep)
end

---@param path string
---@return string[]
function util.glob(path)
    return vim.fn.glob(path, false, true)
end

---@param ... string
---@return string
function util.normalize_and_create_lua_path(...)
    return table.concat(vim.tbl_map(vim.fs.normalize, { ... }), ";")
end

---@param package_path string lua package path type
---@param paths string[] string to add to the lua package path
---@return string[]
function util.create_package_path_argument(package_path, paths)
    if paths and #paths > 0 then
        local _path = util.normalize_and_create_lua_path(unpack(paths))

        return { "-c", ([[lua %s = '%s;' .. %s]]):format(package_path, _path, package_path) }
    end

    return {}
end

---@param position_id string
---@return string[]
function util.split_position_id(position_id)
    return vim.split(position_id, "::")
end

--- Create a busted test key ("describe 1 test 1") from a neotest position
--- id ("path::describe 1::test 1")
---@param position_id string
---@param concat string?
---@return string
---@return string
function util.strip_position_id(position_id, concat)
    local parts = util.split_position_id(position_id)
    local path = parts[1]
    local _concat = concat or " "
    local stripped = table.concat(vim.tbl_map(util.trim_quotes, vim.list_slice(parts, 2)), _concat)

    return path, stripped
end

---@return string
local function plugin_path()
    local str = debug.getinfo(2, "S").source:sub(2)

    return str:match(util.create_path("(.*", ")"))
end

---@param filename string
---@return string
function util.get_path_to_plugin_file(filename)
    return table.concat({ plugin_path(), filename })
end

return util
