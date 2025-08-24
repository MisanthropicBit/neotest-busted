local json = require("dkjson")

return function(options)
    local busted = require("busted")
    local handler = require("busted.outputHandlers.base")()

    ---@param value string
    ---@return string
    local function double_quote(value)
        return ('"%s"'):format(value)
    end

    -- A copy of the base handler's getFullName function except that it uses
    -- "::" as a separator instead of spaces and also preprends the full path
    ---@param element neotest-busted.BustedElement
    ---@return string
    local function createNeotestPositionId(element)
        local parent = busted.parent(element)
        local names = { double_quote(element.name or element.descriptor) }

        while parent and (parent.name or parent.descriptor) and parent.descriptor ~= "file" do
            table.insert(names, 1, double_quote(parent.name or parent.descriptor))
            parent = busted.parent(parent)
        end

        local isThirdPartyAsync = element.trace.source:match("nio/tests.lua$") ~= nil
        local path

        if isThirdPartyAsync then
            -- When the while loop above exits it might be because the parent descriptor
            -- is 'file' in which case its name is the file containing the async test. If
            -- we used element.trace.source below it would give the nio module's tests.lua
            -- file which would not match any position ids in the neotest tree. We could
            -- probably also do this for non-async tests
            path = parent.name or parent.descriptor
        else
            -- Strip the leading '@' from the element's trace source
            path = element.trace.source:sub(2)
        end

        table.insert(names, 1, path)

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

    ---@diagnostic disable-next-line: unused-local
    handler.testEnd = function(element, parent, status)
        local insertTable

        if status == "success" then
            insertTable = handler.successes
        elseif status == "pending" then
            insertTable = handler.pendings
        elseif status == "failure" then
            insertTable = handler.failures
        elseif status == "error" then
            insertTable = handler.errors
        end

        -- Inject an extra field containing the neotest position id as the
        -- default 'name' field in the json output uses spaces so we cannot
        -- reliably split on space since the full test name itself might
        -- contain spaces
        insertTable[#insertTable]["neotestPositionId"] = createNeotestPositionId(element)
    end

    handler.suiteEnd = function()
        local file, err_message = io.open(output_file, "w")

        if not file then
            io.write(
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
            io.write("Failed to encode test results to json: " .. result .. "\n")
            io.flush()
        end

        return nil, true
    end

    busted.subscribe({ "suite", "end" }, handler.suiteEnd)
    busted.subscribe({ "test", "end" }, handler.testEnd)

    return handler
end
