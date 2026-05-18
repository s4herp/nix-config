-- [[ Custom Keymaps ]]
-- Project-specific and personalized keymaps
-- This module contains Docker commands, Rails navigation, file utilities, etc.

local M = {}

local map = vim.keymap.set

function M.setup()
  -- Clear highlights on search when pressing <Esc> in normal mode
  map('n', '<Esc>', '<cmd>nohlsearch<CR>')

  -- Diagnostic keymaps
  map('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

  -- Exit terminal mode with <Esc><Esc>
  map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

  -- Window navigation with CTRL + hjkl
  map('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
  map('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
  map('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
  map('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

  -- Basic buffer management
  map('n', '<leader>bd', '<cmd>bdelete<cr>', { desc = '[B]uffer [D]elete' })
  map('n', '<leader>bD', '<cmd>bdelete!<cr>', { desc = 'Force buffer [D]elete' })
  map('n', '<leader>bn', '<cmd>enew<cr>', { desc = '[B]uffer [N]ew' })
  map('n', '<leader>bj', '<cmd>bnext<cr>', { desc = '[B]uffer next' })
  map('n', '<leader>bk', '<cmd>bprev<cr>', { desc = '[B]uffer previous' })

  -- Basic editing helpers
  map('n', '<leader>a', 'ggVG', { desc = 'Select [A]ll' })
  -- Enhanced buffer management (beyond basic core keymaps)
  map('n', '<leader>bo', '<cmd>%bd|e#<cr>', { desc = '[B]uffer [O]nly (close others)' })
  map('n', '<leader>bQ', '<cmd>qa<cr>', { desc = '[B]uffer [Q]uit all' })

  -- File path utilities (custom project features)
  map('n', '<leader>yp', function()
    local path = vim.fn.expand '%:.'
    vim.fn.setreg('+', path)
    vim.notify('Copied relative path: ' .. path, vim.log.levels.INFO)
  end, { desc = '[Y]ank relative [P]ath' })

  map('n', '<leader>yP', function()
    local path = vim.fn.expand '%:p'
    vim.fn.setreg('+', path)
    vim.notify('Copied full path: ' .. path, vim.log.levels.INFO)
  end, { desc = '[Y]ank full [P]ath' })

  map('n', '<leader>yf', function()
    local filename = vim.fn.expand '%:t'
    vim.fn.setreg('+', filename)
    vim.notify('Copied filename: ' .. filename, vim.log.levels.INFO)
  end, { desc = '[Y]ank [F]ilename' })

  -- Markdown preview
  map('n', '<leader>mp', '<cmd>MarkdownPreviewToggle<CR>', { desc = '[M]arkdown [P]review toggle' })
end

return M
