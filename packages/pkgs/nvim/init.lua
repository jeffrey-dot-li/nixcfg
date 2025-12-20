
vim.api.nvim_create_augroup("fish_fmt", { clear = true })

vim.api.nvim_create_autocmd("BufWritePre", {
  group = "fish_fmt",
  pattern = "*.fish",
  command = "silent! %!fish_indent",
})

vim.api.nvim_create_user_command("SwapRegisters", function()
  local unnamed = vim.fn.getreg('"')
  local unnamed_type = vim.fn.getregtype('"')

  local plus = vim.fn.getreg('+')
  local plus_type = vim.fn.getregtype('+')

  vim.fn.setreg('"', plus, plus_type)
  vim.fn.setreg('+', unnamed, unnamed_type)
end, { desc = "Swap unnamed and system clipboard registers" })




vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local session = vim.fn.getcwd() .. "/Session.vim"
    if vim.fn.filereadable(session) == 1 then
      vim.cmd("source " .. session)
    end
  end,
})


vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    local session = vim.fn.getcwd() .. "/Session.vim"
    if vim.fn.filereadable(session) == 1 then
      vim.cmd("mksession! Session.vim")
    end
  end,
})