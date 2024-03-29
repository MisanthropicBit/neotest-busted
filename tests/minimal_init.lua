vim.opt.rtp:append(".")
vim.opt.rtp:append("~/.vim-plug/plenary.nvim")
vim.opt.rtp:append("~/.vim-plug/neotest")
vim.opt.rtp:append("~/.vim-plug/nvim-nio")
vim.opt.rtp:append("~/.vim-plug/nvim-treesitter")

vim.cmd.runtime({ "plugin/plenary.vim", bang = false })
