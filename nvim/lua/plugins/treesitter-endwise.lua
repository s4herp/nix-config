-- nvim-treesitter-endwise
-- Automatically add 'end' after if, do, def, etc. in Ruby/Elixir
-- https://github.com/RRethy/nvim-treesitter-endwise

return {
  'RRethy/nvim-treesitter-endwise',
  ft = { 'ruby', 'elixir' },
  dependencies = { 'nvim-treesitter/nvim-treesitter' },
  config = function()
    require('nvim-treesitter.configs').setup {
      endwise = {
        enable = true,
      },
    }
  end,
}