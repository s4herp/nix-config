-- render-markdown.nvim
-- Renders markdown with nice formatting directly in the buffer.
-- Shows raw markdown only when entering insert mode.
-- https://github.com/MeanderingProgrammer/render-markdown.nvim

return {
  'MeanderingProgrammer/render-markdown.nvim',
  ft = { 'markdown' },
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    'nvim-tree/nvim-web-devicons',
  },
  opts = {
    render_modes = { 'n', 'c', 't' },
    anti_conceal = {
      enabled = false,
    },
  },
}
