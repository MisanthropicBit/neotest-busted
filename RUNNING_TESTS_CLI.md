There are several ways to run your tests from the command line.

> [!WARNING]
> Running busted with neovim as the lua interpreter means that the same neovim
> instance is used in all your tests which could break test isolation. For
> example, setting `_G.foo = 10` in a test that runs before a test containing
> `vim.print(_G.foo)` will print 10.

# Using plenary.nvim

This repo uses [`plenary.nvim`](https://github.com/nvim-lua/plenary.nvim) to run
its tests so feel free to use the setup in your own projects.

Running tests this way has the benefit that a separate neovim instance is used
for each test file giving better test isolation than running busted with neovim
as the lua interpreter.

See `plenary.nvim`'s GitHub repo or run `:help plenary-test` if you already have it
installed.

# Using a busted configuration file

You can provide a `.busted` config file and run your tests using busted.
Learn more about busted configuration files from the [official
docs](https://lunarmodules.github.io/busted/#usage).

```lua
return {
    _all = {
        -- Use neovim as the lua interpreter for all tasks
        lua = "nvim -l",
        -- Ensures that your plugin and test files will be found
        lpath = "lua/?.lua;lua/?/init.lua;tests/?.lua",
    },
    -- Default task to run if no task was specified
    default = {
        -- Runs your minimal init file (if any) so package dependencies can be found
        helper = "./tests/minimal_init.lua",
    },
    -- Some other task
    integration = {
        tags = "integration",
        shuffle_files = true,
    },
}
```

Then run your tests using either `busted <test_dir>` or use `luarocks test
--test-type busted <test_dir>` (or omit `--test-type busted` if you set up a
test command in the rockspec, see below).

Pass extra arguments to `neotest` to run a specific task. For example, to run
the `"integration"` task in a test file:

```lua
"neotest".run.run({ vim.fn.expand("%"), extra_args = { "--run", "integration" } })
```

# Using luarocks

Luarocks allows you to specify a test command in the rockspec which can be run
using `luarocks test`. Additionally, you can specify `test_dependencies` and
they will automatically be installed before running tests.

If your tests do not need to run in a neovim context the rockspec below should
suffice, otherwise you can use a `.busted` config file to setup this up (see
above).

```lua
rockspec_format = "3.0"
package = "rockspec-example.nvim"
version = "scm-1"

description = {
  summary = "Example rockspec",
}

-- More definitions...

test_dependencies = {
    "busted >= 2.2.0, < 3.0.0",
}

test = {
    type = "busted",
}
```

This will work if you use a [user-](#user-home-directory-install) or
[system-level](#global-install) luarocks installation but if you want to use a
[project-level](#directory-local-install) luarocks installation, you can use
this small script to correctly set up the paths.

```lua
---@param command_name string
---@param args string[]
---@return string
local function run_command(command_name, args)
    local command = vim.list_extend({ command_name }, args)
    local result = vim.fn.system(command)

    if vim.v.shell_error ~= 0 then
        error(("Failed to run command: '%s'"):format(command))
    end

    return result
end

-- Path for the plugin being tested
vim.opt.rtp:append(".")

local lua_path = run_command("luarocks", { "path", "--lr-path" })
local lua_cpath = run_command("luarocks", { "path", "--lr-cpath" })

-- Paths for the project-local luarocks packages
package.path = package.path .. ";" .. lua_path

-- Paths for the project-local shared libraries
package.cpath = package.cpath .. ";" .. lua_cpath

require("busted.runner")({ standalone = false })
```

Then change the test command in your rockspec to the following.

```lua
test = {
    type = "command",
    command = "nvim -l ./run-tests.lua",
}
```

# Using lazy.nvim

The `lazy.nvim` package manager directly provides a way to run busted tests.
Please see the [official docs](https://lazy.folke.io/developers#minit-minimal-init).
