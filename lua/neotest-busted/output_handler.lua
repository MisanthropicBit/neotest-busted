local json = require("dkjson")

local io_write = io.write
local io_flush = io.flush

-- return function(options)
--      local utfTerminalHandler = require("busted.outputHandlers.utfTerminal")(options)
--      utfTerminalHandler:subscribe(options)

--      table.insert(options.arguments, 1, "test-output.json")
--      local jsonOutputHandler = require("busted.outputHandlers.json")(options)
--      jsonOutputHandler:subscribe(options)

--      return jsonOutputHandler
--  end

return function(options)
    local busted = require("busted")
    local handler = require("busted.outputHandlers.base")()

    -- Copy options and remove arguments so the utfTerminal handler can parse
    -- them without error
    local utf_terminal_options = vim.deepcopy(options)
    utf_terminal_options.arguments = {}

    -- Initialise the utfTerminal handler
    local utfTerminalHandler = require("busted.outputHandlers.utfTerminal")(utf_terminal_options)
    utfTerminalHandler:subscribe(utf_terminal_options)

    local output_file ---@type string

    if type(options.arguments) == "table" then
        output_file = options.arguments[1]
    end

    if not output_file then
        io.stderr:write("No valid json output file passed to output handler\n")
        os.exit(1)
    end

    handler.suiteEnd = function()
        local file, err_message = io.open(output_file, "w")

        if not file then
            io_write(
                ("Failed to open file '%s' for writing json results: %s"):format(
                    output_file,
                    err_message
                )
            )
            os.exit(1)
        end

        for _, test in ipairs(handler.pendings) do
            test.element.attributes.default_fn = nil -- functions cannot be encoded into json
        end

        local test_results = {
            pendings = handler.pendings,
            successes = handler.successes,
            failures = handler.failures,
            errors = handler.errors,
            duration = handler.getDuration(),
        }

        local ok, result = pcall(json.encode, test_results, {
            exception = function(reason, value, state, default_reason)
                local state_short = table.concat(state.buffer, "")
                state_short = "..."
                    .. state_short:sub(#state_short - 100)
                    .. tostring(state.exception)
                io.stderr:write(default_reason .. "(" .. state_short .. ")")
            end,
        })

        if ok then
            file:write(result)
            file:close()
        else
            io_write("Failed to encode test results to json: " .. result .. "\n")
            io_flush()
            os.exit(1)
        end

        return nil, true
    end

    busted.subscribe({ "suite", "end" }, handler.suiteEnd)

    return handler
end
