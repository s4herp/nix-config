-- [[ Neovim Configuration ]]
-- Modular configuration following kickstart.nvim best practices
-- See: https://github.com/nvim-lua/kickstart.nvim

vim.loader.enable()

-- Core configuration
require 'core.options'    -- Basic vim options and settings
require 'core.autocmds'   -- Basic autocommands

-- Plugin configuration
require 'config.lazy'     -- Plugin manager and plugin loading

-- Load custom keymaps from existing custom directory
-- This maintains backwards compatibility with the existing setup
require('custom.keymaps').setup()

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
