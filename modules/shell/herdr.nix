{ ... }:

# herdr: agent-aware terminal multiplexer, run alongside tmux (not as a
# replacement -- see modules/shell/tmux.nix). It is kept for the multi-agent
# case: it reads every pane and marks each agent working / blocked / idle in a
# sidebar, which is the one thing tmux cannot report.
#
# The module writes $XDG_CONFIG_HOME/herdr/config.toml and runs
# `herdr server reload-config` on change, so a switch applies to the running
# server without restarting it.
#
# Only the keys that diverge from herdr's defaults are set. Its defaults
# already match the tmux bindings in tmux.nix: prefix+h/j/k/l to focus panes,
# prefix+c for a new tab, prefix+z to zoom, prefix+x to close. Full reference:
# `herdr --default-config`.

{
  programs.herdr = {
    enable = true;

    settings = {
      # Same prefix as tmux (tmux.nix rebinds C-b -> C-Space), so the muscle
      # memory carries over and neither tool needs relearning.
      keys = {
        prefix = "ctrl+space";
        # herdr defaults detach to prefix+q; tmux uses prefix+d.
        detach = "prefix+d";
      };

      # Matches the catppuccin mocha palette used by tmux and ghostty.
      # auto_switch is off: the terminal is dark-only here, and letting herdr
      # follow the host appearance would flip it to latte on a system change.
      theme = {
        name = "catppuccin";
        auto_switch = false;
      };

      terminal = {
        # Inherit the source pane's directory on split, like tmux's
        # default-path behavior with the bindings in tmux.nix.
        new_cwd = "follow";
      };
    };
  };
}
