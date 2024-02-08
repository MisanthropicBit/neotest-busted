local util = {}

local lib = require("neotest.lib")

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

---@param ... unknown
---@return string
function util.expand_and_create_lua_path(...)
    return table.concat(vim.tbl_map(vim.fn.expand, ...), ";")
end

---@param package_path string lua package path type
---@param path string | string[] string to add to the lua package path
---@return string[]
function util.create_package_path_argument(package_path, path)
    if path and #path > 0 then
        local _path = path

        if type(path) ~= "string" then
            _path = util.expand_and_create_lua_path(path)
        end

        return { "-c", ([[lua %s = '%s;' .. %s]]):format(package_path, _path, package_path) }
    end

    return {}
end

return util
