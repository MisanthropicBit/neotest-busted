local help_message = [[test-runner [...options] [...test_files] [-- [...busted_options]

Run tests using neotest-busted from the commandline. Options given after '--'
are forwarded to busted.

Usage:

    -h, --help   Show this help message.
]]

---@class ParsedArgs
---@field help boolean
---@field paths string[]
---@field busted_args string[]

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
    [vim.log.levels.OFF] = {
        name = "",
        color = Color.Reset,
        hl_group = "",
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
    local _level = level or vim.log.levels.OFF
    local options = level_options[_level]
    local prefix = ""

    if is_headless() then
        if _level ~= vim.log.levels.OFF then
            prefix = ("%s%s%s: "):format(
                color_code(options.color),
                options.name,
                color_code(Color.Reset)
            )
        end

        io.stderr:write(("%s%s\n"):format(prefix, message))
    else
        if _level ~= vim.log.levels.OFF then
            prefix = ("[neotest-busted:%s]: "):format(options.name)
        end

        vim.api.nvim_echo({
            { prefix, options.hl_group },
            { message },
        }, true, {})
    end
end

local function find_minimal_init()
    local glob_matches = vim.fn.glob("**/minimal_init.lua", false, true)

    if #glob_matches == 0 then
        print_level("Could not find minimal_init.lua", vim.log.levels.ERROR)
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

---@return ParsedArgs
local function parse_args()
    local parsed_args = {
        help = false,
        paths = {},
        busted_args = {},
    }

    for idx, arg in ipairs(_G.arg) do
        if arg == "-h" or arg == "--help" then
            parsed_args.help = true
        elseif arg == "--" then
            vim.list_extend(parsed_args.busted_args, _G.arg, idx + 1)
            break
        else
            table.insert(parsed_args.paths, arg)
        end
    end

    return parsed_args
end

---@return string[]
local function collect_tests()
    local tests = {}
    local util = require("neotest-busted.util")

    vim.list_extend(tests, util.glob("test/**/*_spec.lua"))
    vim.list_extend(tests, util.glob("tests/**/*_spec.lua"))
    vim.list_extend(tests, util.glob("spec/**/*_spec.lua"))

    return tests
end

local function run()
    if not is_headless() then
        print_level("Script must be run from the command line", vim.log.levels.ERROR)
        return
    end

    local minimal_init = find_minimal_init()

    if not minimal_init then
        print_level("Could not find a minimal_init.lua file", vim.log.levels.ERROR)
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

    local parsed_args = parse_args()

    if parsed_args.help then
        print_level(help_message)
        return
    end

    local paths = parsed_args.paths or collect_tests()

    local busted = adapter_or_error.create_busted_command(nil, paths, {}, {
        output_handler = "utfTerminal",
        output_handler_options = { "--color" },
        -- If we don't add --ignore-lua the subsequent busted command (run via
        -- neovim) will use the .busted config file and use the 'lua' option
        -- for running the tests which will cause an infinite process spawning
        -- loop
        extra_busted_args = vim.list_extend({ "--ignore-lua" }, parsed_args.busted_args),
    })

    if not busted then
        print_level("Could not find a busted executable", vim.log.levels.ERROR)
        return
    end

    io.stdout:write(
        vim.fn.system(table.concat(vim.tbl_map(vim.fn.shellescape, busted.command), " "))
    )
end

run()
