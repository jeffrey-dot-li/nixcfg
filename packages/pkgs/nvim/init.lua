
vim.api.nvim_create_augroup("fish_fmt", { clear = true })

vim.api.nvim_create_autocmd("BufWritePre", {
  group = "fish_fmt",
  pattern = "*.fish",
  command = "silent! %!fish_indent",
})