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

local function deepcopy(obj)
    if type(obj) ~= "table" then
        return obj
    end
    local res = {}
    for k, v in pairs(obj) do
        res[k] = deepcopy(v)
    end
    return res
end

return function(options)
    local busted = require("busted")
    local handler = require("busted.outputHandlers.base")()

    -- Copy options and remove arguments so the utfTerminal handler can parse
    -- them without error
    local utf_terminal_options = deepcopy(options)
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
            -- Functions cannot be encoded into json
            test.element.attributes.default_fn = nil
        end

        local test_results = {
            pendings = handler.pendings,
            successes = handler.successes,
            failures = handler.failures,
            errors = handler.errors,
            duration = handler.getDuration(),
        }

        local ok, result = pcall(json.encode, test_results)

        if ok then
            file:write(result)
            file:close()
        else
            io_write("Failed to encode test results to json: " .. result .. "\n")
            io_flush()
        end

        return nil, true
    end

    busted.subscribe({ "suite", "end" }, handler.suiteEnd)

    return handler
end
