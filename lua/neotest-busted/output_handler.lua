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
    local function createNeotestPositionId(context)
        local parent = busted.parent(context)
        local names = { double_quote(context.name or context.descriptor) }

        while parent and (parent.name or parent.descriptor) and parent.descriptor ~= "file" do
            table.insert(names, 1, double_quote(parent.name or parent.descriptor))
            parent = busted.parent(parent)
        end

        table.insert(names, 1, context.trace.source:sub(2))

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
        local pos_id = createNeotestPositionId(element)
        local insertTable

        if status == "success" then
            insertTable = handler.successes
            handler.successesCount = handler.successesCount + 1
        elseif status == "pending" then
            insertTable = handler.pendings
            handler.pendingsCount = handler.pendingsCount + 1
        elseif status == "failure" then
            -- Failure already saved in failure handler
            handler.failuresCount = handler.failuresCount + 1
            return nil, true
        elseif status == "error" then
            -- Error count already incremented and saved in error handler
            return nil, true
        end

        -- Inject an extra field for the neotest position id as the default
        -- name in the json output using spaces so we cannot reliably split
        -- on space since the full test name itself might contain spaces
        insertTable[#insertTable]["neotestPositionId"] = pos_id
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
