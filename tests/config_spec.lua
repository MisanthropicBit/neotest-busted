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
        }

        stub(vim.api, "nvim_echo")

        for _, invalid_config_test in ipairs(invalid_config_tests) do
            local ok, error = config.configure(invalid_config_test.config)

            if ok then
                vim.print(invalid_config_test)
            end

            assert.is_false(ok)

            assert.stub(vim.api.nvim_echo).was.called_with({
                { "[neotest-busted]: ", "ErrorMsg" },
                { "Invalid config: " },
                { error },
            }, true, {})
        end

        vim.api.nvim_echo:revert()
    end)

    it("throws no errors for a valid config", function()
        local ok = config.configure({
            busted_command = nil,
            busted_args = { "--shuffle-tests" },
            busted_paths = { "some/path" },
            busted_cpaths = {},
            minimal_init = "some_init_file.lua",
            local_luarocks_only = false,
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
