local test_utils = {}

-- A copy of the base handler's getFullName function except that it uses
-- "::" as a separator instead of spaces and also preprends the full path
---@param element neotest-busted.BustedElement
---@return string
function test_utils.position_id_from_busted_element(element)
    local busted = require("busted")
    local parent = busted.parent(element)
    local names = { element.name or element.descriptor }

    while parent and (parent.name or parent.descriptor) and parent.descriptor ~= "file" do
        table.insert(names, 1, parent.name or parent.descriptor)
        parent = busted.parent(parent)
    end

    table.insert(names, 1, element.trace.source:sub(2))
    table.insert(names, tostring(element.trace.currentline))

    -- TODO: Use another separator in case test name contains "::"?
    -- TODO: Output line number as well for finding matching source-level test
    return table.concat(names, "::")
end

--- Call this outisde an async context to force a load of the vim.treesitter
--- modules so that any side-effects are not executed inside an async context.
--- This way the next call to a vim.treesitter module will work in an async
--- context.
---
--- See https://github.com/neovim/neovim/issues/35071 for more details
function test_utils.prepare_vim_treesitter()
    if vim.fn.has("nvim-0.11.0") == 1 then
        vim.treesitter.language.get_lang("lua")
    end
end

return test_utils
