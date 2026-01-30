<div align="center">
  <br />
  <h1>neotest-busted</h1>
  <p>
    <img src="https://img.shields.io/github/v/release/MisanthropicBit/neotest-busted?style=flat-square" />
    <a href="/.github/workflows/tests.yml">
        <img src="https://img.shields.io/github/actions/workflow/status/MisanthropicBit/neotest-busted/tests.yml?branch=master&style=flat-square" />
    </a>
    <a href="/LICENSE">
        <img src="https://img.shields.io/github/license/MisanthropicBit/neotest-busted?style=flat-square&color=purple" />
    </a>
  </p>
  <br />
</div>

<div align="center">

[`Neotest`](https://github.com/nvim-neotest/neotest) adapter
for running tests using [`busted`](https://github.com/lunarmodules/busted/) with
neovim as the lua interpreter.

</div>

<div align="center">
    <img width="80%" src="https://github.com/MisanthropicBit/neotest-busted/assets/1846147/d2f81d89-9ce6-4c27-8a11-bf86072e9888" />
    <img width="80%" src="https://github.com/MisanthropicBit/neotest-busted/assets/1846147/45804359-1e88-4d48-8ad6-9a31da78145e" />
    <img width="80%" src="https://github.com/MisanthropicBit/neotest-busted/assets/1846147/cd947151-4008-47e5-89a4-42cc83094a0d" />
</div>

<!-- panvimdoc-ignore-start -->

# Table of contents

- [Requirements](#requirements)
- [Configuration](#configuration)
- [Defining tests](#defining-tests)
  - [Async tests](#async-tests)
  - [Parametric tests](#parametric-tests)
- [Debugging tests](#debugging-tests)
- [Luarocks and Busted](#luarocks-and-busted)
  - [Directory-local install](#directory-local-install)
  - [User home directory install](#user-home-directory-install)
  - [Global install](#global-install)
- [Contributing](#contributing)
- [FAQ](#faq)

<!-- panvimdoc-ignore-end -->

## Requirements

* Neovim 0.9.0+ for the [`-l`](https://neovim.io/doc/user/starting.html#-l) option.
* [Neotest](https://github.com/nvim-neotest/neotest) 4.0.0+ (which requires neovim 0.9.0+).
* [`busted`](https://github.com/lunarmodules/busted) installed (in a project-local, user, or global location, see [here](#luarocks-and-busted)).

## Configuration

Setup with neotest. Leave values as `nil` to leave them unspecified.

```lua
require("neotest").setup({
    adapters = {
        require("neotest-busted")({
            -- Leave as nil to let neotest-busted automatically find busted
            busted_command = "<path to a busted executable>",
            -- Do not use nvim to run busted, but run busted directly
            no_nvim = false,
            -- Extra arguments to busted
            busted_args = { "--shuffle-files" },
            -- List of paths to add to lua path lookups before running
            -- busted, or a function returning a list of such paths
            busted_paths = { "my/custom/path/?.lua" },
            -- List of paths to add to lua cpath lookups before running
            -- busted, or a function returning a list of such paths
            busted_cpaths = { "my/custom/path/?.so" },
            -- Custom config to load via -u to set up testing.
            -- If nil, will look for a 'minimal_init.lua' file
            minimal_init = "custom_init.lua",
            -- Only use a luarocks installation in the project's directory. If
            -- true, installations in $HOME and global installations will be
            -- ignored. Useful for isolating the test environment
            local_luarocks_only = true,
            -- Find parametric tests
            parametric_test_discovery = false,
        }),
    },
})
```

## Defining tests

Please refer to the [official busted documentation](https://lunarmodules.github.io/busted/).

### Async tests

`neotest-busted` supports [`nvim-nio`](https://github.com/nvim-neotest/nvim-nio)
asynchronous tests. You can set `PLENARY_TEST_TIMEOUT` to a numerical value to
control async timeouts.

```lua
local control = require("neotest.async").control
local async = require("nio.tests")

describe("async", function()
    before_each(function()
        vim.print("before_each")
    end)

    async.it("async test", function()
        local timer = vim.uv.new_timer()
        local event = control.event()

        -- Print a message after 2 seconds
        timer:start(2000, 0, function()
            timer:stop()
            timer:close()
            vim.print("Hello from async test")
            event.set()
        end)

        -- Wait for the timer to complete
        event.wait()
    end)
end)
```

If you are not using `nvim-nio`, `neotest-butsed` also comes with builtin
support for async tests. Just use `require("neotest-busted.async")` instead of
`require("nio.tests")` then wrap the test function in a call to `async`.
This also works for `before_each` and `after_each`.

```lua
local async = require("neotest-busted.async")
local control = require("neotest.async").control

describe("async", function()
    before_each(async(function()
        vim.print("async before_each")
    end))

    it("async test", async(function()
        -- Same as above
    end))
end)
```

The `async` function takes an optional second timeout argument in milliseconds.
If omitted, uses the numerical value of either the
`NEOTEST_BUSTED_ASYNC_TEST_TIMEOUT` or `PLENARY_TEST_TIMEOUT` environment
variables (in that order) or a default timeout of 2000 milliseconds.

### Parametric tests

> [!IMPORTANT]
> Supporting parametric tests requires extra computation to discover them so
> support is disabled by default. You need to set `parametric_test_discovery` to
> `true` if you want neotest-busted to find parametric tests.

> [!WARNING]
> There was a bug in neovim 0.9.0 that was [fixed in
> 0.9.2](https://github.com/neovim/neovim/pull/24216) which shortened the output
> generated by lua scripts run using `nvim -l`. This is used internally to list
> all tests via busted for discovering parametric tests so if you experience
> issues, try upgrading.

`neotest-busted` supports parametric tests that are generated at runtime as
opposed to being defined entirely at source-level as shown below. `describe`'s
can also be parametric and are also supported.

Due to technical limitations, parametric tests won't be shown in the neotest
summary until they have been run.

```lua
describe("parametric tests", function()
    for i = 1, 3 do
        it(("test %d"):format(i), function()
            assert.are.same(i, i)
        end)
    end
end)
```

## Debugging tests

`neotest-busted` has support for debugging tests via [`local-lua-debugger-vscode`](https://github.com/tomblind/local-lua-debugger-vscode)
which can be set up via [`nvim-dap`](https://github.com/mfussenegger/nvim-dap/wiki/Debug-Adapter-installation#lua). Once set up, you can set a breakpoint and run the test with the `dap` strategy. Please refer to the [`neotest`](https://github.com/nvim-neotest/neotest) documentation for more information.

## Luarocks and Busted

Install luarocks from the [website](https://luarocks.org/). `neotest-busted`
will try to find a `busted` executable automatically at the different locations
listed below and in that priority (i.e. a directory-local install takes
precedence over a global install). You can check the installation by running
`luarocks list busted`.

> [!WARNING]
> If you have set `busted_command` to a non-nil value in the `setup` function,
> `neotest-busted` will not know where to look for appropriate lua paths and
> will not look for installations as specified below to avoid setting up paths
> for a different busted installation.
>
> In this case, you should set `busted_paths` and `busted_cpaths` to appropriate
> paths.

### Directory-local install

You can install busted in your project's directory by running the following commands.

```shell
> cd <your_project>
> luarocks init
> luarocks config --scope project lua_version 5.1
> luarocks install busted
```

### User home directory install

> [!IMPORTANT]
> You need to set `local_luarocks_only` to `false` for `neotest-busted` to find
> your home directory installation.

The following command will install busted in your home directory.

```shell
> luarocks install --local busted
```

### Global install

> [!IMPORTANT]
> You need to set `local_luarocks_only` to `false` for `neotest-busted` to find
> your global installation.

```shell
> luarocks install busted
```

## Contributing

Thanks for considering to contribute. Please see the instructions [here](/CONTRIBUTING.md).

## FAQ

#### Q: Can I run async tests with neotest-busted?

Yes. Please see the instructions [here](#async-tests).

[Busted removed support for async testing in version 2](https://github.com/lunarmodules/busted/issues/545#issuecomment-282085568)
([even though the docs still mention it](https://lunarmodules.github.io/busted/#async-tests)) so you could install
busted v1 but I haven't tested that.

#### Q: Why is `neotest-busted` tested using plenary?

The test could be run via `neotest-busted` itself but I decided to use plenary
instead to use another test runner so that bugs in `neotest-busted` won't affect
its own tests.

#### Q: Why do I keep getting "Failed to list tests via busted" errors?

This can happen if you have `parametric_test_discovery = true`. In order to
discover parametric (runtime-only) tests, `neotest-busted` runs a `busted`
command to list the tests in a test file. If you have a syntax error in that
file, busted cannot correctly parse the test and the command fails.

#### Q: Why do I keep getting "Encountered output line that could not be parsed" errors?

As explained above, `neotest-busted` runs a `busted` command to list the tests
in a test file. If you have print statements in that file (not output from tests
but e.g. bare `vim.print` statements), those lines will appear in the output and
`neotest-busted` will try to parse it and fail.

## Inspiration

* [Using Neovim as Lua interpreter with Luarocks](https://zignar.net/2023/01/21/using-Luarocks-as-lua-interpreter-with-luarocks/)
* [nlua](https://github.com/mfussenegger/nlua)
* [Test your Neovim plugins with luarocks & busted](https://mrcjkb.dev/posts/2023-06-06-luarocks-test.html)
