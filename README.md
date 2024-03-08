<div align="center">
  <br />
  <h1>neotest-busted</h1>
  <p>🚧 Highly experimental 🚧</p>
  <p>
    <img src="https://img.shields.io/badge/version-0.1.0-blue?style=flat-square" />
    <a href="https://luarocks.org/modules/misanthropicbit/neotest-busted">
        <img src="https://img.shields.io/luarocks/v/misanthropicbit/neotest-busted?style=flat-square&logo=lua&logoColor=%2351a0cf&color=purple" />
    </a>
    <a href="/.github/workflows/tests.yml">
        <img src="https://img.shields.io/github/actions/workflow/status/MisanthropicBit/neotest-busted/tests.yml?branch=master&style=flat-square" />
    </a>
    <a href="/LICENSE">
        <img src="https://img.shields.io/github/license/MisanthropicBit/neotest-busted?style=flat-square" />
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

## Requirements

Neovim 0.9.0+ for the [`-l`](https://neovim.io/doc/user/starting.html#-l) option.

## Configuration

Setup with neotest. Leave values as `nil` to leave them unspecified.

```lua
require("neotest").setup({
    adapters = {
        require("neotest-busted")({
            -- Leave as nil to let neotest-busted automatically find busted
            busted_command = "<path to a busted executable>",
            -- Extra arguments to busted
            busted_args = { "--shuffle-files" },
            -- List of paths to add to package.path in neovim before running busted
            busted_paths = { "my/custom/path/?.lua" },
            -- List of paths to add to package.cpath in neovim before running busted
            busted_cpaths = { "my/custom/path/?.so" },
            -- Custom script to load via -u. If nil, will look for a 'minimal_init.lua' file
            minimal_init = "custom_init.lua",
        }),
    },
})
```

## Luarocks and Busted

Install luarocks from the [website](https://luarocks.org/). `neotest-busted`
will try to find a `busted` executable automatically at the different locations
listed below and in that priority (i.e. a directory-local install takes
precedence over a global install). You can check the installation by running
`luarocks list busted`.

### Directory-local install

You can install busted in your project's directory by running the following commands.

```shell
> cd <your_project>
> luarocks init
> luarocks config --scope project lua_version 5.1
> luarocks install busted
```

### User home directory install

The following command will install busted in your home directory.

```shell
> luarocks install --local busted
```

### Global install

```shell
> luarocks install busted
```

## FAQ

#### Q: Can I run async tests with neotest-busted?

Yes and no. [Busted removed support for async testing in version
2](https://github.com/lunarmodules/busted/issues/545#issuecomment-282085568)
([even though the docs still mention
it](https://lunarmodules.github.io/busted/#async-tests)) so you could install
busted v1 but I haven't tested that.

There's also an [experimental branch](https://github.com/MisanthropicBit/neotest-busted/tree/async-tests) for async support.

## Inspired by

* [Using Neovim as Lua interpreter with Luarocks](https://zignar.net/2023/01/21/using-luarocks-as-lua-interpreter-with-luarocks/)
* [nlua](https://github.com/mfussenegger/nlua)
* [Test your Neovim plugins with luarocks & busted](https://mrcjkb.dev/posts/2023-06-06-luarocks-test.html)
