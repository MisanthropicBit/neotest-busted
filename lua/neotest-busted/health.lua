local health = {}

local adapter = require("neotest-busted")
local config = require("neotest-busted.config")

local min_neovim_version = "0.9.0"

local report_start = vim.health.report_start
local report_ok = vim.health.report_ok
local report_error = vim.health.report_error
local report_warn = vim.health.report_warn

if vim.fn.has("nvim-0.10") == 1 then
    report_start = vim.health.start
    report_ok = vim.health.ok
    report_error = vim.health.error
    report_warn = vim.health.warn
end

---@param module_name string
local function check_module_installed(module_name)
    local installed, _ = pcall(require, module_name)

    if installed then
        report_ok(("`%s` is installed"):format(module_name))
    else
        report_error(("`%s` is not installed"):format(module_name))
    end
end

function health.check()
    report_start("neotest-busted")

    if vim.fn.has("nvim-" .. min_neovim_version) == 1 then
        report_ok(("has neovim %s+"):format(min_neovim_version))
    else
        report_error("neotest-busted requires at least neovim " .. min_neovim_version)
    end

    -- NOTE: We cannot check the neotest version because it isn't advertised as
    -- part of its public api
    check_module_installed("neotest")
    check_module_installed("nio")

    local ok, error = config.validate(config)

    if ok then
        report_ok("found no errors in config")
    else
        report_error("config has errors: " .. error)
    end

    -- We skip looking for a local luarocks installation as the healthcheck
    -- could have been invoked from anywhere
    local busted = adapter.find_busted_command(true)

    if busted then
        report_ok(("found `busted` (type: %s)"):format(busted.type))
    else
        report_warn(
            "could not find busted executable globally or in user home folder",
            "if not already installed locally, please install busted using luarocks (https://luarocks.org/)"
        )
    end
end

return health
