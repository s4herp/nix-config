-- [[ Editor Plugins ]]
-- Telescope, treesitter, completion, and core editing functionality

return {
  -- Telescope (fuzzy finder)
  {
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',

        -- `build` is used to run some command when the plugin is installed/updated.
        -- This is only run then, not every time Neovim starts up.
        build = 'make',

        -- `cond` is a condition used to determine whether this plugin should be
        -- installed and loaded.
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },

      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      -- Telescope is a fuzzy finder that comes with a lot of different things that
      -- it can fuzzy find! It's more than just a "file finder", it can search
      -- many different aspects of Neovim, your workspace, LSP, and more!
      --
      -- The easiest way to use Telescope, is to start by doing something like:
      --  :Telescope help_tags
      --
      -- After running this command, a window will open up and you're able to
      -- type in the prompt window. You'll see a list of `help_tags` options and
      -- a corresponding preview of the help.
      --
      -- Two important keymaps to use while in Telescope are:
      --  - Insert mode: <c-/>
      --  - Normal mode: ?
      --
      -- This opens a window that shows you all of the keymaps for the current
      -- Telescope picker. This is really useful to discover what Telescope can
      -- do as well as how to actually do it!

      -- [[ Configure Telescope ]]
      -- See `:help telescope` and `:help telescope.setup()`
      require('telescope').setup {
        pickers = {
          live_grep = {
            file_ignore_patterns = {
              -- Ignore these files when searching with live_grep
              'node_modules',
              '.git/',
              'vendor/',
              'tmp/',
              'log/',
              'coverage/',
            },
            additional_args = function(_)
              return { '--hidden' }
            end,
          },
          -- You can configure Telescope pickers here.
          --  See `:help telescope.pickers` for more information.
          --  This is where you can set up default options for each picker.
          --
          -- For example, to set the default layout strategy to 'vertical':
          --   defaults = { layout_strategy = 'vertical' }
        },
        -- You can put your default mappings / updates / etc. in here
        --  All the info you're looking for is in `:help telescope.setup()`
        --
        -- defaults = {
        --   mappings = {
        --     i = { ['<c-enter>'] = 'to_fuzzy_refine' },
        --   },
        -- },
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>sF', '<cmd>Telescope find_files hidden=true<cr>', { desc = 'Find all files (including hidden)' })
      vim.keymap.set('n', '<leader>sG', builtin.git_status, { desc = '[S]earch Changed [G]it Files' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

      -- Slightly advanced example of overriding default behavior and theme
      vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to Telescope to change the theme, layout, etc.
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      -- It's also possible to pass additional configuration options.
      --  See `:help telescope.builtin.live_grep()` for information about particular keys
      vim.keymap.set('n', '<leader>s/', function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end, { desc = '[S]earch [/] in Open Files' })

      -- Shortcut for searching your Neovim configuration files
      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
      end, { desc = '[S]earch [N]eovim files' })

      -- ELIXIR/PHOENIX SEARCHES (using <leader>e for "Elixir")
      -- Find files
      vim.keymap.set('n', '<leader>ef', function()
        builtin.find_files {
          find_command = { 'fd', '--type', 'f', '--extension', 'ex', '--extension', 'exs', '--extension', 'heex' },
          prompt_title = 'Find Elixir Files',
        }
      end, { desc = '[E]lixir find [f]iles' })

      vim.keymap.set('n', '<leader>eL', function()
        builtin.find_files {
          search_dirs = { 'lib' },
          prompt_title = 'Phoenix Lib (source)',
        }
      end, { desc = '[E]lixir [L]ib files' })

      vim.keymap.set('n', '<leader>eT', function()
        builtin.find_files {
          search_dirs = { 'test' },
          prompt_title = 'Phoenix Tests',
        }
      end, { desc = '[E]lixir [T]est files' })

      vim.keymap.set('n', '<leader>ec', function()
        builtin.find_files {
          search_dirs = { 'lib' },
          find_command = { 'fd', '--type', 'f', 'controller' },
          prompt_title = 'Phoenix Controllers',
        }
      end, { desc = '[E]lixir [c]ontrollers' })

      vim.keymap.set('n', '<leader>ev', function()
        builtin.find_files {
          find_command = { 'fd', '--type', 'f', '--extension', 'heex' },
          prompt_title = 'Phoenix Templates (heex)',
        }
      end, { desc = '[E]lixir [v]iews/templates' })

      vim.keymap.set('n', '<leader>em', function()
        builtin.find_files {
          search_dirs = { 'priv/repo/migrations' },
          prompt_title = 'Ecto Migrations',
        }
      end, { desc = '[E]lixir [m]igrations' })

      vim.keymap.set('n', '<leader>er', function()
        builtin.find_files {
          find_command = { 'fd', '--type', 'f', 'router' },
          prompt_title = 'Phoenix Router',
        }
      end, { desc = '[E]lixir [r]outer' })

      -- Find/grep excluding tests
      vim.keymap.set('n', '<leader>eo', function()
        builtin.find_files {
          find_command = { 'fd', '--type', 'f', '--exclude', 'test' },
          prompt_title = 'Files (no tests)',
        }
      end, { desc = '[E]lixir files [o]nly (no tests)' })

      vim.keymap.set('n', '<leader>ego', function()
        builtin.live_grep {
          glob_pattern = '!test/**',
          prompt_title = 'Grep (no tests)',
        }
      end, { desc = '[E]lixir [g]rep [o]nly (no tests)' })

      -- Grep in specific directories
      vim.keymap.set('n', '<leader>egl', function()
        builtin.live_grep {
          search_dirs = { 'lib' },
          prompt_title = 'Grep in Lib',
        }
      end, { desc = '[E]lixir [g]rep [l]ib' })

      vim.keymap.set('n', '<leader>egt', function()
        builtin.live_grep {
          search_dirs = { 'test' },
          prompt_title = 'Grep in Tests',
        }
      end, { desc = '[E]lixir [g]rep [t]ests' })

      vim.keymap.set('n', '<leader>egc', function()
        builtin.live_grep {
          search_dirs = { 'config' },
          prompt_title = 'Grep in Config',
        }
      end, { desc = '[E]lixir [g]rep [c]onfig' })
    end,
  },
  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    opts = {},
    keys = {
      {
        's',
        mode = { 'n', 'x', 'o' },
        function()
          require('flash').jump()
        end,
        desc = 'Flash',
      },
      {
        'S',
        mode = { 'n', 'x', 'o' },
        function()
          require('flash').treesitter()
        end,
        desc = 'Flash Treesitter',
      },
      {
        'r',
        mode = 'o',
        function()
          require('flash').remote()
        end,
        desc = 'Remote Flash',
      },
      {
        'R',
        mode = { 'o', 'x' },
        function()
          require('flash').treesitter_search()
        end,
        desc = 'Treesitter Search',
      },
      {
        '<c-s>',
        mode = { 'c' },
        function()
          require('flash').toggle()
        end,
        desc = 'Toggle Flash Search',
      },
    },
  },
  -- Treesitter (syntax highlighting)
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
    opts = {
      ensure_installed = {
        'bash',
        'c',
        'diff',
        'elixir',
        'erlang',
        'heex',
        'html',
        'lua',
        'luadoc',
        'markdown',
        'markdown_inline',
        'query',
        'vim',
        'vimdoc',
        'ruby',
        'javascript',
        'typescript',
        'json',
        'yaml',
      },
      auto_install = true,
    },
    config = function(_, opts)
      require('nvim-treesitter').setup(opts)

      vim.api.nvim_create_autocmd('FileType', {
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
  },

  -- Treesitter Context (shows context of current node)
  {
    'nvim-treesitter/nvim-treesitter-context',
    dependencies = 'nvim-treesitter/nvim-treesitter',
    config = function()
      require('treesitter-context').setup {
        enable = true,
        max_lines = 3,
        mode = 'cursor',
      }
    end,
  },


  -- Autocompletion
  {
    'saghen/blink.cmp',
    event = 'VimEnter',
    version = '1.*',
    dependencies = {
      -- Snippet Engine
      {
        'L3MON4D3/LuaSnip',
        version = '2.*',
        build = (function()
          -- Build Step is needed for regex support in snippets.
          -- This step is not supported in many windows environments.
          -- Remove the below condition to re-enable on windows.
          if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then
            return
          end
          return 'make install_jsregexp'
        end)(),
        dependencies = {
          -- `friendly-snippets` contains a variety of premade snippets.
          --    See the README about individual language/framework/plugin snippets:
          --    https://github.com/rafamadriz/friendly-snippets
          {
            'rafamadriz/friendly-snippets',
            config = function()
              require('luasnip.loaders.from_vscode').lazy_load()
              require 'custom.snippets'
            end,
          },
        },
        opts = {},
      },
      'folke/lazydev.nvim',
    },
    --- @module 'blink.cmp'
    --- @type blink.cmp.Config
    opts = {
      keymap = {
        -- 'default' (recommended) for mappings similar to built-in completions
        --   <c-y> to accept ([y]es) the completion.
        --    This will auto-import if your LSP supports it.
        --    This will expand snippets if the LSP sent a snippet.
        -- 'super-tab' for tab to accept
        -- 'enter' for enter to accept
        -- 'none' for no mappings
        --
        -- For an understanding of why the 'default' preset is recommended,
        -- you will need to read `:help ins-completion`
        --
        -- No, but seriously. Please read `:help ins-completion`, it is really good!
        --
        -- All presets have the following mappings:
        -- <tab>/<s-tab>: move to right/left of your snippet expansion
        -- <c-space>: Open menu or open docs if already open
        -- <c-n>/<c-p> or <up>/<down>: Select next/previous item
        -- <c-e>: Hide menu
        -- <c-k>: Toggle signature help
        --
        -- See :h blink-cmp-config-keymap for defining your own keymap
        preset = 'default',

        -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
        --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
      },

      appearance = {
        -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
        -- Adjusts spacing to ensure icons are aligned
        nerd_font_variant = 'mono',
      },

      completion = {
        -- By default, you may press `<c-space>` to show the documentation.
        -- Optionally, set `auto_show = true` to show the documentation after a delay.
        documentation = { auto_show = false, auto_show_delay_ms = 500 },
      },

      sources = {
        default = { 'lsp', 'path', 'snippets', 'lazydev' },
        providers = {
          lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 },
        },
      },

      snippets = { preset = 'luasnip' },

      -- Blink.cmp includes an optional, recommended rust fuzzy matcher,
      -- which automatically downloads a prebuilt binary when enabled.
      --
      -- By default, we use the Lua implementation instead, but you may enable
      -- the rust implementation via `'prefer_rust_with_warning'`
      --
      -- See :h blink-cmp-config-fuzzy for more information
      fuzzy = { implementation = 'prefer_rust_with_warning' },

      -- Shows a signature help window while you type arguments for a function
      signature = { enabled = true },
    },
  },

  -- Autoformat
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = false,
      formatters_by_ft = {
        lua = { 'stylua' },
        elixir = { 'mix' },
        heex = { 'mix' },
        -- Conform can also run multiple formatters sequentially
        -- python = { "isort", "black" },
        --
        -- You can use 'stop_after_first' to run the first available formatter from the list
        -- javascript = { "prettierd", "prettier", stop_after_first = true },
      },
    },
  },

  -- Indentation detection
  {
    'NMAC427/guess-indent.nvim',
    config = function()
      require('guess-indent').setup {}
    end,
  },
}
