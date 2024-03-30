local health = {}

local adapter = require("neotest-busted")
local config = require("neotest-busted.config")

local min_neovim_version = "0.9.0"

---@param module_name string
local function check_module_installed(module_name)
    local installed, _ = pcall(require, module_name)

    if installed then
        vim.health.report_ok(("`%s` is installed"):format(module_name))
    else
        vim.health.report_error(("`%s` is not installed"):format(module_name))
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
    check_module_installed("nio")

    local ok, error = config.validate(config)

    if ok then
        vim.health.report_ok("found no errors in config")
    else
        vim.health.report_error("config has errors: " .. error)
    end

    local busted = adapter.find_busted_command()

    if busted then
        vim.health.report_ok(
            ("found `busted` (type: %s) at\n%s"):format(
                busted.type,
                vim.loop.fs_realpath(busted.command)
            )
        )
    else
        vim.health.report_error(
            "could not find busted executable",
            "please install busted using luarocks (https://luarocks.org/)"
        )
    end
end

return health
