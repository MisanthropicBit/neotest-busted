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
    install = {
        bin = {
            neobusted = "scripts/neobusted",
        },
    },
}

test = {
    type = "command",
    command = "./tests/run_tests.sh",
}
