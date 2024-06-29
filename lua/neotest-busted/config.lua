local config = {}

---@type neotest-busted.Config
local default_config = {
    busted_command = nil,
    busted_args = nil,
    busted_paths = nil,
    busted_cpaths = nil,
    minimal_init = nil,
    local_luarocks_only = true,
}

local _user_config = default_config

---@param value any
---@return boolean
local function is_non_empty_string(value)
    return value == nil or (type(value) == "string" and #value > 0)
end

---@param value any
---@return boolean
---@return string?
local function is_optional_string_list(value)
    if value == nil then
        return true
    end

    if not vim.tbl_islist(value) then
        return false, "must be a list-like table"
    end

    for idx, item in ipairs(value) do
        if type(item) ~= "string" then
            return false, "item at index " .. tostring(idx)
        end
    end

    return true
end

--- Validate a config
---@param _config neotest-busted.Config
---@return boolean
---@return any?
function config.validate(_config)
    -- stylua: ignore start
    local ok, error = pcall(vim.validate, {
        busted_command = {
            _config.busted_command,
            is_non_empty_string,
            "optional non-empty string"
        },
        busted_args = {
            _config.busted_args,
            is_optional_string_list,
            "an optional string list",
        },
        busted_paths = {
            _config.busted_paths,
            is_optional_string_list,
            "an optional string list",
        },
        busted_cpaths = {
            _config.busted_cpaths,
            is_optional_string_list,
            "an optional string list",
        },
        minimal_init = {
            _config.minimal_init,
            is_non_empty_string,
            "optional non-empty string"
        },
        local_luarocks_only = {
            _config.local_luarocks_only,
            "boolean",
        },
    })
    -- stylua: ignore end

    if not ok then
        return ok, error
    end

    if type(_config.busted_command) == "string" then
        if vim.fn.executable(_config.busted_command) == 0 then
            return false, "busted command in configuration is not executable"
        end
    end

    return ok
end

---@param user_config table<string, any>?
---@return boolean
---@return any?
function config.configure(user_config)
    _user_config = vim.tbl_deep_extend("keep", user_config or {}, default_config)

    local ok, error = config.validate(_user_config)

    if not ok then
        vim.api.nvim_echo({
            { "[neotest-busted]: ", "ErrorMsg" },
            { "Invalid config: " },
            { error },
        }, true, {})
    end

    return ok, error
end

return setmetatable(config, {
    __index = function(_, key)
        return _user_config[key]
    end,
})
