-- [[ Core Autocommands ]]
-- Basic autocommands that don't depend on plugins
-- See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- Elixir/Phoenix specific autocommands
local elixir_augroup = vim.api.nvim_create_augroup('elixir-phoenix-config', { clear = true })

-- Set specific options for Elixir files
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'elixir', 'eelixir', 'heex' },
  group = elixir_augroup,
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.expandtab = true
    vim.opt_local.softtabstop = 2
    -- Enable spell checking for comments in Elixir files
    vim.opt_local.spell = true
    vim.opt_local.spelllang = 'en_us'
  end,
})

