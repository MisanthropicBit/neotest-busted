local config = {}

---@type neotest-busted.Config
local default_config = {
    busted_command = nil,
    busted_args = nil,
    busted_paths = nil,
    busted_cpaths = nil,
    minimal_init = nil,
}

local _user_config = default_config

local function is_non_empty_string(value)
    return value == nil or (type(value) == "string" and #value > 0)
end

local function is_optional_string_list(value)
    if value == nil then
        return true
    end

    if type(value) ~= "table" then
        return false
    end

    for idx, item in ipairs(value) do
        if type(item) ~= "string" then
            return false, "at index " .. tostring(idx)
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
            "expected optional non-empty string"
        },
        busted_args = {
            _config.busted_args,
            is_optional_string_list,
            "expected an optional string list",
        },
        busted_paths = {
            _config.busted_paths,
            is_optional_string_list,
            "expected an optional string list",
        },
        busted_cpaths = {
            _config.busted_cpaths,
            is_optional_string_list,
            "expected an optional string list",
        },
        minimal_init = {
            _config.minimal_init,
            is_non_empty_string,
            "expected optional non-empty string"
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

function config.configure(user_config)
    _user_config = vim.tbl_deep_extend("keep", user_config or {}, default_config)

    local ok, error = config.validate(_user_config)

    if not ok then
        -- message.error("Errors found in config: " .. error)
    end

    return ok
end

return setmetatable(config, {
    __index = function(_, key)
        return _user_config[key]
    end,
})
