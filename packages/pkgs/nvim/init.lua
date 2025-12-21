
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
-- 2. Update function to take 'start_insert' bool
local function toggleterm_single(id, start_insert)
  -- Default to false if not provided
  start_insert = start_insert or false

  -- Close any visible ToggleTerm windows
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "toggleterm" then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end

  -- Get (or create) the terminal
  local term = terminal_msg.get(id)
  
  if term == nil then
    term = Terminal:new({ count = id, direction = "horizontal" })
  end
  
  term:open()

  -- Conditionally enter insert mode
  if start_insert then
    vim.cmd("startinsert")
  end
end
-- 3. Update the User Command (Optional: parses args like "1 true")
vim.api.nvim_create_user_command("ToggleTermSingle", function(opts)
  -- Split args by space (e.g., ":ToggleTermSingle 1 true")
  local args = vim.split(opts.args, " ")
  local id = tonumber(args[1]) or 1
  local start_insert = args[2] == "true" -- simple string check

  toggleterm_single(id, start_insert)
end, { nargs = "*", desc = "Open ToggleTerm. Args: [id] [true/false]" })


-- When we search a file make sure it opens the fold
-- Don't do this this doesn't actually work, just do `zv` after search it is the same thing
-- vim.opt.foldopen:append({ "search", "jump", "mark" })