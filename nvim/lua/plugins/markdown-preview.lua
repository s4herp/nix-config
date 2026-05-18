-- markdown-preview.nvim
-- Preview markdown files in the browser with live reload.
-- Supports Mermaid diagrams, KaTeX math, and more.
-- https://github.com/iamcco/markdown-preview.nvim

return {
  'iamcco/markdown-preview.nvim',
  cmd = { 'MarkdownPreviewToggle', 'MarkdownPreview', 'MarkdownPreviewStop' },
  ft = { 'markdown' },
  build = 'cd app && npx --yes yarn install',
  init = function()
    vim.g.mkdp_filetypes = { 'markdown' }
  end,
}
