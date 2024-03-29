local health = {}

local adapter = require("neotest-busted")
local config = require("neotest-busted.config")

local min_neovim_version = "0.9.0"

local function check_module_installed(module_name, not_installed_reporter)
    local installed, _ = pcall(require, module_name)

    if installed then
        vim.health.report_ok(module_name .. " is installed")
    else
        local _not_installed_reporter = not_installed_reporter or vim.health.report_ok
        _not_installed_reporter(module_name .. " is not installed")
    end
end

function health.check()
    vim.health.report_start("neotest-busted")

    if vim.fn.has("nvim-" .. min_neovim_version) == 1 then
        vim.health.report_ok(("has neovim %s+"):format(min_neovim_version))
    else
        vim.health.report_error("neotest-busted requires at least neovim " .. min_neovim_version)
    end

    -- NOTE: We cannot check the neotest version because it isn't avertised as
    -- part of its public api
    check_module_installed("neotest")
    check_module_installed("nio", vim.health.report_warn)

    local ok, error = config.validate(config)

    if ok then
        vim.health.report_ok("found no errors in config")
    else
        vim.health.report_error("config has errors: " .. error)
    end

    local busted = adapter.find_busted_command()

    if not busted then
        vim.health.report_error("could not find busted executable")
    else
        vim.health.report_ok(
            ("found busted (type: `%s`) at\n%s"):format(
                busted.type,
                vim.loop.fs_realpath(busted.command)
            )
        )
    end
end

return health
