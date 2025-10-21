local compat = {}

compat.uv = vim.uv or vim.loop

if vim.fn.has("nvim-0.10") == 1 then
    compat.tbl_islist = vim.islist
    compat.loop = vim.uv
else
    ---@diagnostic disable-next-line: deprecated
    compat.tbl_islist = vim.tbl_islist
    compat.loop = vim.loop
end

return compat
