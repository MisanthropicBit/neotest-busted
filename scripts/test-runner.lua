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
        io.stderr:write(
            ("%s%s%s: %s\n"):format(
                color_code(options.color),
                options.name,
                color_code(Color.Reset),
                message
            )
        )
    else
        vim.api.nvim_echo({
            { ("[neotest-busted:%s]: "):format(options.name), options.hl_group },
            { message },
        }, true, {})
    end
end

---@return string?
local function find_minimal_init()
    -- NOTE: Do not use util.glob as we haven't loaded neotest-busted at this point
    local glob_matches = vim.fn.glob("**/minimal_init.lua", false, true)

    if #glob_matches == 0 then
        print_level("Could not find minimal_init.lua")
        return
    end

    return glob_matches[1]
end

---@param module_name string
---@return any
local function require_checked(module_name)
    local ok, module_or_error = pcall(require, module_name)

    if not ok then
        return nil
    end

    return module_or_error
end

---@return string[]
local function parse_paths()
    return _G.arg
end

local function collect_tests()
    local tests = {}
    local util = require("neotest-busted.util")

    vim.list_extend(tests, util.glob("./test/**/*_spec.lua"))
    vim.list_extend(tests, util.glob("./tests/**/*_spec.lua"))
    vim.list_extend(tests, util.glob("./spec/**/*_spec.lua"))

    return tests
end

local function run()
    if not is_headless() then
        print_level("Script must be run from the command line")
        return
    end

    local minimal_init = find_minimal_init()

    if not minimal_init then
        print_level("Could not find a minimal_init.lua file")
        return
    end

    vim.cmd.source(minimal_init)

    local adapter_or_error = require_checked("neotest-busted")

    if not adapter_or_error then
        print_level(
            "neotest-busted could not be loaded. Set up 'runtimepath', provide a minimal configuration via '-u', or create a 'minimal_init.lua' file: "
                .. adapter_or_error,
            vim.log.levels.ERROR
        )
        return
    end

    local paths = parse_paths() or collect_tests()

    local busted = adapter_or_error.create_busted_command(nil, paths, {}, {
        output_handler = "utfTerminal",
        output_handler_options = { "--color" },
    })

    if not busted then
        print_level("Could not find a busted executable")
        return
    end

    io.stdout:write(
        vim.fn.system(table.concat(vim.tbl_map(vim.fn.shellescape, busted.command), " "))
    )
end

run()
