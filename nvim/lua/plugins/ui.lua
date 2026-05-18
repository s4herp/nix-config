-- [[ UI Plugins ]]
-- Theme, bufferline, statusline, and visual enhancements

return {
  -- Colorscheme
  {
    'folke/tokyonight.nvim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('tokyonight').setup {
        styles = {
          comments = { italic = false }, -- Disable italics in comments
        },
      }

      -- Load the colorscheme here.
      -- Like many other themes, this one has different styles, and you could load
      -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
      vim.cmd.colorscheme 'tokyonight-night'
    end,
  },

  -- Bufferline (tabs)
  {
    'akinsho/bufferline.nvim',
    version = '*',
    dependencies = 'nvim-tree/nvim-web-devicons',
    event = 'BufReadPost', -- Load after first buffer is read
    keys = {
      -- Buffer management
      { '<leader>bp', '<cmd>BufferLineTogglePin<cr>', desc = 'Pin Buffer' },
      { '<leader>bP', '<cmd>BufferLineGroupClose ungrouped<cr>', desc = 'Close non-pinned buffers' },
      { '<leader>br', '<cmd>BufferLineCloseRight<cr>', desc = 'Close buffers to the right' },
      { '<leader>bl', '<cmd>BufferLineCloseLeft<cr>', desc = 'Close buffers to the left' },
    },
    opts = {
      options = {
        close_command = 'bdelete! %d',
        right_mouse_command = 'bdelete! %d',
        left_mouse_command = 'buffer %d',

        -- Icons and appearance
        indicator = {
          icon = '▎',
          style = 'icon',
        },
        buffer_close_icon = '󰅖',
        modified_icon = '●',
        close_icon = '',
        left_trunc_marker = '',
        right_trunc_marker = '',

        -- Sizes
        max_name_length = 30,
        max_prefix_length = 30,
        tab_size = 21,

        -- Diagnostics in tabs
        diagnostics = 'nvim_lsp',
        diagnostics_update_in_insert = false,

        -- Appearance
        show_buffer_icons = true,
        show_buffer_close_icons = true,
        show_close_icon = true,
        show_tab_indicators = true,
        persist_buffer_sort = true,
        separator_style = 'slant', -- 'slant', 'thick', 'thin', 'slope'
        enforce_regular_tabs = true,
        always_show_bufferline = true,

        -- Hover
        hover = {
          enabled = true,
          delay = 200,
          reveal = { 'close' },
        },
      },
    },
  },

  -- Mini.nvim (statusline and text objects)
  {
    'echasnovski/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup { n_lines = 500 }

      -- Simple and easy statusline.
      --  You could remove this setup call if you don't like it,
      --  and try some other statusline plugin
      local statusline = require 'mini.statusline'
      -- set use_icons to true if you have a Nerd Font
      statusline.setup { use_icons = vim.g.have_nerd_font }

      -- You can configure sections in the statusline by overriding their
      -- default behavior. For example, here we set the section for
      -- cursor location to LINE:COLUMN
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        return '%2l:%-2v'
      end

      -- ... and there is more!
      --  Check out: https://github.com/echasnovski/mini.nvim
    end,
  },

  -- Which-key (keymap helper)
  {
    'folke/which-key.nvim',
    event = 'VimEnter', -- Sets the loading event to 'VimEnter'
    opts = {},
  },

  -- Highlight todo, notes, etc in comments
  {
    'folke/todo-comments.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = { signs = false },
  },
}
