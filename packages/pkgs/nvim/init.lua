
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


-- 1. Import the whole module first
local terminal_msg = require("toggleterm.terminal")
-- 2. Grab the Terminal class from it
local Terminal = terminal_msg.Terminal 

local function toggleterm_single(id)
  -- Close any visible ToggleTerm windows
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "toggleterm" then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end

  -- FIX: Use 'terminal_msg.get' (the module function), not 'Terminal.get'
  local term = terminal_msg.get(id)
  
  if term == nil then
    term = Terminal:new({ count = id, direction = "horizontal" })
  end
  
  term:open()
end

vim.api.nvim_create_user_command("ToggleTermSingle", function(opts)
  local id = tonumber(opts.args) or 1
  toggleterm_single(id)
end, { nargs = "?", desc = "Open ToggleTerm in a single bottom pane" })