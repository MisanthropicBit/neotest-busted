# neotest-busted

🚧 Highly experimental 🚧 [`neotest`](https://github.com/nvim-neotest/neotest) adapter
for running tests using [`busted`](https://github.com/lunarmodules/busted/) with
neovim as the lua interpreter.

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

```lua
require("neotest").setup({
    adapters = {
        require("neotest-busted")({
            busted_command = "<path to a busted executable>",
            busted_args = { "--shuffle-files" }, -- Extra arguments to busted
            busted_path = "", -- Custom semi-colon separated path to load in neovim before running busted
            busted_cpath = "", -- Custom semi-colon separated cpath to load in neovim before running busted
        }),
    },
})
```

Inspired by:

* [Using Neovim as Lua interpreter with Luarocks](https://zignar.net/2023/01/21/using-luarocks-as-lua-interpreter-with-luarocks/)
* [nlua](https://github.com/mfussenegger/nlua)
* [Test your Neovim plugins with luarocks & busted](https://mrcjkb.dev/posts/2023-06-06-luarocks-test.html)
