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

[`Neotest`](https://github.com/nvim-neotest/neotest) adapter
for running tests using [`busted`](https://github.com/lunarmodules/busted/) with
neovim as the lua interpreter.

![screenshot 1](https://github.com/MisanthropicBit/neotest-busted/assets/1846147/d2f81d89-9ce6-4c27-8a11-bf86072e9888)
![screenshot 2](https://github.com/MisanthropicBit/neotest-busted/assets/1846147/45804359-1e88-4d48-8ad6-9a31da78145e)
![screenshot 3](https://github.com/MisanthropicBit/neotest-busted/assets/1846147/cd947151-4008-47e5-89a4-42cc83094a0d)

## Requirements

Neovim 0.9.0+ for the [`-l`](https://neovim.io/doc/user/starting.html#-l) option.

## Configuration

`neotest-busted` will try to find a `busted` executable automatically. You can
have it find a directory-local executable by running the following commands.

```shell
> cd <your_project>
> luarocks init
> luarocks config --scope project lua_version 5.1
> luarocks install busted
```

Setup with neotest. Leave values as `nil` to disable them.

```lua
require("neotest").setup({
    adapters = {
        require("neotest-busted")({
            -- Leave as nil to let neotest-busted automatically find busted
            busted_command = "<path to a busted executable>",
            -- Extra arguments to busted
            busted_args = { "--shuffle-files" },
            -- Custom semi-colon separated path to load in neovim before running busted
            busted_path = "my/custom/path/?.lua;...",
            -- Custom semi-colon separated cpath to load in neovim before running busted
            busted_cpath = "my/custom/path/?.lua;...",
        }),
    },
})
```

Inspired by:

* [Using Neovim as Lua interpreter with Luarocks](https://zignar.net/2023/01/21/using-luarocks-as-lua-interpreter-with-luarocks/)
* [nlua](https://github.com/mfussenegger/nlua)
* [Test your Neovim plugins with luarocks & busted](https://mrcjkb.dev/posts/2023-06-06-luarocks-test.html)
