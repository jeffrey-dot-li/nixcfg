vim.api.nvim_create_user_command("SwapRegisters", function()
  local unnamed = vim.fn.getreg('"')
  local unnamed_type = vim.fn.getregtype('"')

  local plus = vim.fn.getreg('+')
  local plus_type = vim.fn.getregtype('+')

  vim.fn.setreg('"', plus, plus_type)
  vim.fn.setreg('+', unnamed, unnamed_type)

  -- Notify
  local ok, notify = pcall(require, "notify")
  if ok then
    notify(
      'Swapped registers: " ↔ +',
      "info",
      { title = "Registers" }
    )
  else
    vim.notify('Swapped registers: " ↔ +', vim.log.levels.INFO)
  end
end, { desc = 'Swap unnamed (") and system clipboard (+) registers' })

vim.keymap.set('n', '<leader>y', '<cmd>SwapRegisters<CR>', { desc = "Swap registers" })