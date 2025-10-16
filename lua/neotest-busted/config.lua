local config = {}

local compat = require("neotest-busted.compat")

---@type neotest-busted.Config
local default_config = {
    busted_command = nil,
    busted_args = nil,
    busted_paths = nil,
    busted_cpaths = nil,
    minimal_init = nil,
    local_luarocks_only = true,
    parametric_test_discovery = false,
    no_nvim = false,
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

    if not compat.tbl_islist(value) then
        return false, "must be a list-like table"
    end

    for idx, item in ipairs(value) do
        if type(item) ~= "string" then
            return false, "item at index " .. tostring(idx)
        end
    end

    return true
end

---@param value any
---@return boolean
---@return string?
local function is_optional_string_list_or_function(value)
    if value == nil then
        return true
    end

    if type(value) == "function" then
        local status, ret_val = pcall(value)
        if not status then
            return false, "function call failed: " .. ret_val
        else
            value = ret_val
        end
    end

    if not compat.tbl_islist(value) then
        return false, "must be a list-like table or a function returning a list-like table"
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
---@param skip_executable_check? boolean
---@return boolean
---@return any?
function config.validate(_config, skip_executable_check)
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
            is_optional_string_list_or_function,
            "an optional string list or function returning a string list",
        },
        busted_cpaths = {
            _config.busted_cpaths,
            is_optional_string_list_or_function,
            "an optional string list or function returning a string list",
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
        parametric_test_discovery = {
            _config.parametric_test_discovery,
            "boolean"
        },
        no_nvim = {
            _config.no_nvim,
            "boolean"
        },
    })
    -- stylua: ignore end

    if not ok then
        return ok, error
    end

    if not skip_executable_check and type(_config.busted_command) == "string" then
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

    -- Skip checking the executable when running setup to avoid the error
    -- message as neotest loads all adapters so users will see an error in a
    -- non-lua/neovim directory with a relative path in `busted_command`
    local ok, error = config.validate(_user_config, true)

    if not ok then
        vim.notify_once(
            "[neotest-busted]: Invalid config: " .. tostring(error),
            vim.log.levels.ERROR
        )
    end

    return ok, error
end

return setmetatable(config, {
    __index = function(_, key)
        if type(_user_config[key]) == "function" then
            local status, ret_value = pcall(_user_config[key])
            if not status then
                vim.notify_once(
                    "[neotest-busted]: Issue calling function in configuration: " .. ret_value,
                    vim.log.levels.ERROR
                )
                return nil
            end
            return ret_value
        end
        return _user_config[key]
    end,
})
