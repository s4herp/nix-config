-- [[ Utility Plugins ]]
-- Miscellaneous utility plugins

return {
  -- GitHub Copilot
  {
    'github/copilot.vim',
    event = 'InsertEnter',
  },

  -- Copilot Chat
  {
    'CopilotC-Nvim/CopilotChat.nvim',
    dependencies = {
      { 'github/copilot.vim' }, -- or zbirenbaum/copilot.lua
      { 'nvim-lua/plenary.nvim', branch = 'master' }, -- for curl, log and async functions
    },
    build = 'make tiktoken', -- Only on MacOS or Linux
    opts = {
      -- See Configuration section for options
    },
    -- See Commands section for default commands if you want to lazy load on them
  },

  -- Vim Coach
  {
    'shahshlok/vim-coach.nvim',
    dependencies = {
      'folke/snacks.nvim',
    },
    config = function()
      require('vim-coach').setup()
    end,
    keys = {
      { '<leader>?', '<cmd>VimCoach<cr>', desc = 'Vim Coach' },
    },
  },

  -- Spectre (search and replace)
  {
    'nvim-pack/nvim-spectre',
    keys = {
      {
        '<leader>sR',
        function()
          require('spectre').open()
        end,
        desc = '[S]earch [R]eplace (Spectre)',
      },
    },
    opts = {},
  },
}