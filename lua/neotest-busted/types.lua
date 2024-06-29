---@class neotest-busted.Config
---@field busted_command string?
---@field busted_args string[]?
---@field busted_paths string[]?
---@field busted_cpaths string[]?
---@field minimal_init string?
---@field local_luarocks_only boolean?

---@class neotest-busted.BustedCommandConfig
---@field type "config" | "project" | "user" | "global"
---@field command string[]
---@field lua_paths string[]
---@field lua_cpaths string[]

---@class neotest-busted.TestCommandOptions
---@field busted_output_handler string?
---@field busted_output_handler_options string[]?
---@field quote_strings boolean

---@class neotest-busted.TestCommandConfig
---@field nvim_command string
---@field arguments string[]
---@field paths string[]
---@field cpaths string[]

---@class neotest-busted.BustedTrace
---@field what string
---@field short_src string
---@field lastlinedefined integer
---@field traceback string
---@field message string
---@field source string
---@field currentline integer
---@field linedefined integer

---@class neotest-busted.BustedElement
---@field name string
---@field descriptor string
---@field attributes unknown
---@field starttick number
---@field starttime number
---@field endtick number
---@field endtime number
---@field duration number
---@field trace neotest-busted.BustedTrace

---@class neotest-busted.BustedResult
---@field name string
---@field trace neotest-busted.BustedTrace
---@field element neotest-busted.BustedElement

---@class neotest-busted.BustedFailureResult
---@field name string
---@field message string
---@field trace neotest-busted.BustedTrace
---@field element neotest-busted.BustedElement

---@class neotest-busted.BustedErrorResult
---@field isError true
---@field message string
---@field name string

---@class neotest-busted.BustedResultObject
---@field errors neotest-busted.BustedFailureResult[]
---@field pendings neotest-busted.BustedResult[]
---@field successes neotest-busted.BustedResult[]
---@field failures neotest-busted.BustedFailureResult[]
