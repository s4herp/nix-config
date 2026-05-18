-- [[ Elixir Development ]]
-- Comprehensive Elixir support with elixir-tools.nvim
-- https://github.com/elixir-tools/elixir-tools.nvim

return {
  {
    'elixir-tools/elixir-tools.nvim',
    version = '*',
    event = { 'BufReadPre *.ex', 'BufReadPre *.exs' },
    config = function()
      local elixir = require('elixir')
      local elixirls = require('elixir.elixirls')

      elixir.setup {
        nextls = { enable = false }, -- Use ElixirLS instead of Next LS
        elixirls = {
          enable = true,
          settings = elixirls.settings {
            dialyzerEnabled = false,
            enableTestLenses = false,
          },
        },
        projectionist = {
          enable = true,
        },
      }
    end,
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
  },
}