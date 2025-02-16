# Contributing

1. Fork this repository.
2. Make changes.
3. Make sure tests and styling checks are passing.
   * Run tests by running `./tests/run_tests.sh` in the project directory. Running the tests requires [`plenary.nvim`](https://github.com/nvim-lua/plenary.nvim), [`neotest`](https://github.com/nvim-neotest/neotest), [`nvim-nio`](https://github.com/nvim-neotest/nvim-nio), and [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter). You may need to update the paths in `./tests/minimal_init.lua` to match those of your local installations to be able to run the tests. A `busted` executable is also needed to run the tests so set it up as per the instructions in the [README](/README.md).
   * Install [stylua](https://github.com/JohnnyMorganz/StyLua) and check styling using `stylua --check lua/ tests/ test_files/`. Omit `--check` in order to fix styling.
4. Submit a pull request.
5. Get it approved.
