local compat = {}

if vim.fn.has("nvim-0.10") then
    compat.tbl_islist = vim.islist
    compat.loop = vim.uv
else
    compat.tbl_islist = vim.tbl_islist
    compat.loop = vim.loop
end


return compat
