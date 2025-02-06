local config = require("neotest-busted.config")
local stub = require("luassert.stub")

describe("config", function()
    it("handles invalid configs", function()
        local non_empty_string = "optional non-empty string"
        local optional_string_list = "an optional string list"

        local invalid_config_tests = {
            {
                config = { busted_command = 1 },
                error_message = non_empty_string,
            },
            {
                config = { busted_command = "" },
                error_message = non_empty_string,
            },
            {
                config = { busted_args = { 1, 2, 3 } },
                error_message = optional_string_list,
            },
            {
                config = { busted_args = 1 },
                error_message = optional_string_list,
            },
            {
                config = { busted_paths = { 1, 2, 3 } },
                error_message = optional_string_list,
            },
            {
                config = { busted_paths = 1 },
                error_message = optional_string_list,
            },
            {
                config = { busted_cpaths = { 1, 2, 3 } },
                error_message = optional_string_list,
            },
            {
                config = { busted_cpaths = 1 },
                error_message = optional_string_list,
            },
            {
                config = { minimal_init = false },
                error_message = non_empty_string,
            },
            {
                config = { minimal_init = "" },
                error_message = non_empty_string,
            },
            {
                config = { local_luarocks_only = 1 },
                error_message = "expected boolean, got number",
            },
            {
                config = { parametric_test_discovery = 1 },
                error_message = "expected boolean, got number",
            },
        }

        stub(vim, "notify_once")

        for _, invalid_config_test in ipairs(invalid_config_tests) do
            local ok, error = config.configure(invalid_config_test.config)

            if ok then
                vim.print(invalid_config_test)
            end

            assert.is_false(ok)

            assert
                .stub(vim.notify_once).was
                .called_with("[neotest-busted]: Invalid config: " .. tostring(error), vim.log.levels.ERROR)

            if invalid_config_test.busted_command ~= nil then
                assert.stub(vim.notify_once).was.called_with(
                    "[neotest-busted]: busted_command is deprecated and will be removed in a future version",
                    vim.log.levels.WARN
                )
            end
        end

        ---@diagnostic disable-next-line: undefined-field
        vim.notify_once:revert()
    end)

    it("throws no errors for a valid config", function()
        local ok = config.configure({
            busted_command = nil,
            busted_args = { "--shuffle-tests" },
            busted_paths = { "some/path" },
            busted_cpaths = {},
            minimal_init = "some_init_file.lua",
            local_luarocks_only = false,
            parametric_test_discovery = true,
        })

        assert.is_true(ok)
    end)

    it("throws no errors for empty user config", function()
        assert.is_true(config.configure({}))
    end)

    it("throws no errors for no user config", function()
        assert.is_true(config.configure())
    end)
end)
