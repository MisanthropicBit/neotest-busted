rockspec_format = "3.0"
package = "neotest-busted"
version = "scm-1"

description = {
    summary = "Highly experimental neotest adapter for running tests using busted.",
    detailed = [[]],
    labels = {
        "neovim",
        "plugin",
        "neotest",
        "adapter",
        "busted",
    },
    homepage = "https://github.com/MisanthropicBit/neotest-busted",
    license = "BSD 3-Clause",
}

dependencies = {
    "lua == 5.1",

    -- Neotest does not have a rockspec so list its dependeicies manually. We
    -- cannot list plenary.nvim as it isn't published on luarocks.org
    "neotest >= 5.8.0, < 6.0.0",
    "nvim-nio >= 1.10.1, < 2.0.0",
}

source = {
    url = "git+https://github.com/MisanthropicBit/neotest-busted",
}

build = {
    type = "builtin",
    copy_directories = {
        "doc",
        "scripts",
    },
}

test = {
    type = "command",
    command = "./tests/run_tests.sh",
}
