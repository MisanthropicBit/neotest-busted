---@enum Color
local Color = {
    Red = 31,
    Yellow = 33,
    White = 37,
    Reset = 0,
}

---@alias vim.log.levels 0 | 1 | 2 | 3 | 4 | 5

---@class LogLevelOptions
---@field name string
---@field color integer
---@field hl_group string

---@alias LevelOptions table<vim.log.levels, LogLevelOptions>

---@type LevelOptions
local level_options = {
    [vim.log.levels.ERROR] = {
        name = "Error",
        color = Color.Red,
        hl_group = "ErrorMsg",
    },
    [vim.log.levels.WARN] = {
        name = "Warning",
        color = Color.Yellow,
        hl_group = "WarningMsg",
    },
    [vim.log.levels.INFO] = {
        name = "Info",
        color = Color.White,
        hl_group = "MoreMsg",
    },
}

local function is_headless()
    return #vim.api.nvim_list_uis() == 0
end

---@param color integer
---@return string
local function color_code(color)
    return ("\x1b[%dm"):format(color)
end

---@param message string
---@param level vim.log.levels?
local function print_level(message, level)
    local options = level_options[level] or level_options[vim.log.levels.ERROR]

    if is_headless() then
        io.stderr:write(("%s%s%s: %s\n"):format(color_code(options.color), options.name, color_code(Color.Reset), message))
    else
        vim.api.nvim_echo({
            { options.name, options.hl_group },
            { " " .. message },
        }, true, {})
    end
end

---@param module_name string
---@return any
local function require_checked(module_name)
    local ok, module_or_error = pcall(require, module_name)

    if not ok then
        print_level(
            module_name .. " could not be loaded. Set up 'runtimepath' or provide a minimal configuration via '-u': " .. module_or_error,
            vim.log.levels.ERROR
        )
        return nil
    end

    return module_or_error
end

---@param commandline string[]
---@return string[]
local function parse_paths(commandline)
    local paths = {}

    for idx, item in ipairs(commandline) do
        if item == "--" then
            paths = vim.list_slice(commandline, idx + 1)
            break
        end
    end

    return paths
end

local function collect_tests()
    local tests = {}
    local util = require("neotest-busted.util")

    vim.list_extend(tests, util.glob("test/**/*_spec.lua"))
    vim.list_extend(tests, util.glob("tests/**/*_spec.lua"))
    vim.list_extend(tests, util.glob("spec/**/*_spec.lua"))

    return tests
end

vim.api.nvim_create_user_command("NeotestBusted", function()
    if not is_headless() then
        print_level("NeotestBusted must be run with the --headless option")
        return
    end

    local adapter = require_checked("neotest-busted")

    if not adapter then
        vim.cmd.quitall()
    end

    local paths = parse_paths(vim.v.argv)

    if not paths or #paths == 0 then
        paths = collect_tests()
    end

    local busted = adapter.create_busted_command(
        nil,
        paths,
        {},
        {
            output_handler = "utfTerminal",
            output_handler_options = { "--color" },
        }
    )

    if not busted then
        io.stdout:write("\x1b[31mError:\x1b[0m Could not find a busted executable\n")
        return
    end

    io.stdout:write(
        vim.fn.system(
            table.concat(
                vim.tbl_map(vim.fn.shellescape, busted.command),
                " "
            )
        )
    )

    vim.cmd.quitall()
end, {
    nargs = "*",
    range = false,
    desc = "",
})
