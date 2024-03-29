local config = require("neotest-busted.config")

describe("config", function()
    it("handles invalid configs", function()
        local invalid_configs = {
            {
                busted_command = 1,
            },
            {
                busted_command = "",
            },
            {
                busted_args = { 1, 2, 3 },
            },
            {
                busted_args = 1,
            },
            {
                busted_paths = { 1, 2, 3 },
            },
            {
                busted_paths = 1,
            },
            {
                busted_cpaths = { 1, 2, 3 },
            },
            {
                busted_cpaths = 1,
            },
            {
                minimal_init = false,
            },
            {
                minimal_init = "",
            },
        }

        for _, invalid_config in ipairs(invalid_configs) do
            local ok = config.configure(invalid_config)

            if ok then
                vim.print(invalid_config)
            end

            assert.is_false(ok)
        end
    end)

    it("throws no errors for a valid config", function()
        local ok = config.configure({
            busted_command = nil,
            busted_args = { "--shuffle-tests" },
            busted_paths = { "some/path" },
            busted_cpaths = {},
            minimal_init = "some_init_file.lua",
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
