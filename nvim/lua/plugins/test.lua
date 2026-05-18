-- [[ nvim-test ]]
-- Async test runner for multiple languages
-- https://github.com/klen/nvim-test

return {
  'klen/nvim-test',
  config = function()
    require('nvim-test').setup {
      run = true, -- run tests file on write
      commands_create = true, -- create commands (TestFile, TestLast, ...)
      filename_modifier = ':.',       -- modify filenames before tests run (:h filename-modifiers)
      silent = false,                  -- less notifications
      term = 'split',                  -- how to run tests
      termOpts = {
        direction = 'vertical',   -- 'vertical', 'horizontal', 'tab', 'float'
        width = 96,               -- applies to vertical/horizontal direction
        height = 24,              -- applies to vertical/horizontal direction
        go_back = false,          -- return focus to original window after executing
        stopinsert = 'auto',      -- exit from insert mode (true/false/'auto')
        keep_one = true,          -- keep only one terminal for testing
      },
      runners = {
        elixir = 'nvim-test.runners.mix',
      },
    }
  end,
  keys = {
    { '<leader>t', '', desc = '+test' },
    { '<leader>tt', '<cmd>TestFile<cr>', desc = 'Run test file' },
    { '<leader>tn', '<cmd>TestNearest<cr>', desc = 'Run nearest test' },
    { '<leader>tl', '<cmd>TestLast<cr>', desc = 'Run last test' },
    { '<leader>ts', '<cmd>TestSuite<cr>', desc = 'Run test suite' },
    { '<leader>tv', '<cmd>TestVisit<cr>', desc = 'Visit test file' },
  },
}