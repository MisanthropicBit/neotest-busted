# neotest-busted

Highly experimental `neotest` adapter for running tests using `busted`.

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
        }),
    },
})
```

Inspired by:

* [Using Neovim as Lua interpreter with Luarocks](https://zignar.net/2023/01/21/using-luarocks-as-lua-interpreter-with-luarocks/)
* [nlua](https://github.com/mfussenegger/nlua)
* [Test your Neovim plugins with luarocks & busted](https://mrcjkb.dev/posts/2023-06-06-luarocks-test.html)
