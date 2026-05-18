-- Custom snippets for Elixir/Phoenix development
local ls = require('luasnip')
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

-- ExUnit snippets
ls.add_snippets('elixir', {
  s('desc', {
    t('describe "'), i(1, 'function_name/arity'), t('" do'),
    t({ '', '  ' }), i(2),
    t({ '', 'end' }),
  }),

  s('test', {
    t('test "'), i(1, 'does something'), t('" do'),
    t({ '', '  ' }), i(2),
    t({ '', 'end' }),
  }),

  s('testctx', {
    t('test "'), i(1, 'does something'), t('", %{'), i(2, 'conn: conn'), t('} do'),
    t({ '', '  ' }), i(3),
    t({ '', 'end' }),
  }),

  s('setup', {
    t('setup do'),
    t({ '', '  ' }), i(1),
    t({ '', '  {:ok, ' }), i(2, 'key: value'), t('}'),
    t({ '', 'end' }),
  }),

  s('assert', {
    t('assert '), i(1, 'expression'),
  }),

  s('refute', {
    t('refute '), i(1, 'expression'),
  }),

  s('assertm', {
    t('assert {:ok, '), i(1, 'result'), t('} = '), i(2, 'expression'),
  }),
})

-- Elixir core snippets
ls.add_snippets('elixir', {
  s('defmod', {
    t('defmodule '), i(1, 'Module'), t(' do'),
    t({ '', '  ' }), i(2),
    t({ '', 'end' }),
  }),

  s('def', {
    t('def '), i(1, 'function_name'), t('('), i(2), t(') do'),
    t({ '', '  ' }), i(3),
    t({ '', 'end' }),
  }),

  s('defp', {
    t('defp '), i(1, 'function_name'), t('('), i(2), t(') do'),
    t({ '', '  ' }), i(3),
    t({ '', 'end' }),
  }),

  s('pipe', {
    i(1, 'value'), t({ '', '|> ' }), i(2, 'function()'),
  }),

  s('case', {
    t('case '), i(1, 'expression'), t(' do'),
    t({ '', '  ' }), i(2, 'pattern'), t(' ->'),
    t({ '', '    ' }), i(3, 'result'),
    t({ '', 'end' }),
  }),

  s('with', {
    t('with '), i(1, '{:ok, result}'), t(' <- '), i(2, 'expression'), t(' do'),
    t({ '', '  ' }), i(3),
    t({ '', 'else' }),
    t({ '', '  ' }), i(4, '{:error, reason}'), t(' -> '), i(5, '{:error, reason}'),
    t({ '', 'end' }),
  }),

  s('genserver', {
    t('defmodule '), i(1, 'MyServer'), t(' do'),
    t({ '', '  use GenServer', '' }),
    t({ '', '  # Client API', '' }),
    t({ '', '  def start_link(opts) do' }),
    t({ '', '    GenServer.start_link(__MODULE__, opts, name: __MODULE__)' }),
    t({ '', '  end', '' }),
    t({ '', '  # Server Callbacks', '' }),
    t({ '', '  @impl true' }),
    t({ '', '  def init(' }), i(2, 'state'), t(') do'),
    t({ '', '    {:ok, ' }), i(3, 'state'), t('}'),
    t({ '', '  end' }),
    t({ '', 'end' }),
  }),
})

-- Phoenix snippets
ls.add_snippets('elixir', {
  s('schema', {
    t('schema "'), i(1, 'table_name'), t('" do'),
    t({ '', '  field :' }), i(2, 'name'), t(', :'), i(3, 'string'),
    t({ '', '  timestamps()' }),
    t({ '', 'end' }),
  }),

  s('changeset', {
    t('def changeset('), i(1, 'struct'), t(', attrs) do'),
    t({ '', '  ' }), i(2, 'struct'),
    t({ '', '  |> cast(attrs, [' }), i(3, ':field'), t('])'),
    t({ '', '  |> validate_required([' }), i(4, ':field'), t('])'),
    t({ '', 'end' }),
  }),

  s('liveview', {
    t('defmodule '), i(1, 'AppWeb.PageLive'), t(' do'),
    t({ '', '  use ' }), i(2, 'AppWeb'), t(', :live_view'),
    t({ '', '' }),
    t({ '', '  @impl true' }),
    t({ '', '  def mount(_params, _session, socket) do' }),
    t({ '', '    {:ok, socket}' }),
    t({ '', '  end', '' }),
    t({ '', '  @impl true' }),
    t({ '', '  def render(assigns) do' }),
    t({ '', '    ~H"""' }),
    t({ '', '    <div>' }),
    t({ '', '      ' }), i(3),
    t({ '', '    </div>' }),
    t({ '', '    """' }),
    t({ '', '  end' }),
    t({ '', 'end' }),
  }),

  s('controller', {
    t('defmodule '), i(1, 'AppWeb.PageController'), t(' do'),
    t({ '', '  use ' }), i(2, 'AppWeb'), t(', :controller'),
    t({ '', '' }),
    t({ '', '  def ' }), i(3, 'index'), t('(conn, _params) do'),
    t({ '', '    ' }), i(4, 'render(conn, :index)'),
    t({ '', '  end' }),
    t({ '', 'end' }),
  }),

  s('migration', {
    t('def change do'),
    t({ '', '  create table(:' }), i(1, 'table_name'), t(') do'),
    t({ '', '    add :' }), i(2, 'column'), t(', :'), i(3, 'string'),
    t({ '', '    timestamps()' }),
    t({ '', '  end' }),
    t({ '', 'end' }),
  }),
})

return {}
