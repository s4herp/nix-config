-- [[ Core Options ]]
-- Basic Neovim options and settings
-- See `:help vim.o` and `:help option-list`

-- Set <space> as the leader key
-- NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- Provider configurations
vim.g.python3_host_prog = vim.fn.expand('~/.asdf/shims/python')
vim.g.ruby_host_prog = vim.fn.expand('~/.asdf/shims/ruby')
vim.g.loaded_perl_provider = 0

-- Core options
vim.o.autoread = true -- Automatically reload files when changed outside of Neovim
vim.o.number = true -- Make line numbers default
vim.o.relativenumber = true -- Add relative line numbers

-- Enable mouse mode, can be useful for resizing splits for example!
vim.o.mouse = 'a'

-- Don't show the mode, since it's already in the status line
vim.o.showmode = false

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.o.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250

-- Decrease mapped sequence wait time
vim.o.timeoutlen = 300

-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'` and `:help 'listchars'`
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'

-- Show which line your cursor is on
vim.o.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.o.scrolloff = 10

-- Enable 24-bit RGB color in the TUI
vim.o.termguicolors = true

-- Ensure nvim-treesitter parser install dir is in runtimepath
vim.opt.runtimepath:append(vim.fn.stdpath('data') .. '/site')

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s)
-- See `:help 'confirm'`
vim.o.confirm = true

-- ARM M2 macOS optimizations
if vim.fn.has 'macunix' == 1 and vim.fn.system('uname -m'):match 'arm64' then
  -- Optimize for Apple Silicon
  vim.opt.shell = '/bin/zsh'

  vim.opt.synmaxcol = 200
  vim.opt.updatetime = 100
  vim.opt.backupskip = '/tmp/*,/private/tmp/*'
end
