local io_write = io.write
local io_flush = io.flush

local status_to_test_object_name = {
    success = "successes",
    pending = "pendings",
    failure = "failures",
    error = "errors",
}

return function(options)
    local busted = require("busted")
    local json = require("dkjson")
    local handler = require("busted.outputHandlers.base")()

    --- A copy of the "getFullName" function in busted's base output handler that
    --- separates the full test name by the neotest position id separator "::"
    ---@param element neotest-busted.BustedElement
    local function get_full_neotest_name(element)
        local parent = busted.parent(element)
        local names = { (element.name or element.descriptor) }

        while parent and (parent.name or parent.descriptor) and
            parent.descriptor ~= "file" do

            table.insert(names, 1, parent.name or parent.descriptor)
            parent = busted.parent(parent)
        end

        return table.concat(names, "::")
    end

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

    -- Inject a neotest_name (separated by "::") into the test element
    ---@diagnostic disable-next-line: unused-local
    handler.testEnd = function(element, parent, status, trace)
        local test_object_name = status_to_test_object_name[status]
        local test_element = handler[test_object_name][#handler[test_object_name]]

        test_element.neotest_name = get_full_neotest_name(element)

        return nil, true
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

    busted.subscribe({ "test", "end" }, handler.testEnd, { predicate = handler.cancelOnPending })
    busted.subscribe({ "suite", "end" }, handler.suiteEnd)

    return handler
end
