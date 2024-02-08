---@class neotest-busted.Config
---@field busted_command false | string?
---@field busted_args string[]?
---@field busted_path string?
---@field busted_cpath string?
---@field minimal_init string?

---@class neotest-busted.BustedCommand
---@field command string
---@field path string | string[]
---@field cpath string | string[]

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
--
---@class neotest-busted.BustedFailureResult
---@field name string
---@field message string
---@field trace neotest-busted.BustedTrace
---@field element neotest-busted.BustedElement

---@class neotest-busted.BustedResultObject
---@field errors neotest-busted.BustedFailureResult[]
---@field pendings neotest-busted.BustedResult[]
---@field successes neotest-busted.BustedResult[]
---@field failures neotest-busted.BustedFailureResult[]
