{ pkgs, lib, config, ... }:

# Native Home Manager rewrite of ~/.tmux.conf (decision D3: full native
# rewrite, no tpm at runtime). Source of truth: github.com/s4herp/dotfiles
# (on macOS the file already lives in $HOME as ~/.tmux.conf, origin of the
# legacy ~/.cfg bare-repo).
#
# tpm is removed entirely: plugins are pinned by nixpkgs via
# programs.tmux.plugins (pkgs.tmuxPlugins.*). The tpm bootstrap block and the
# trailing `run '~/.tmux/plugins/tpm/tpm'` line of ~/.tmux.conf are
# intentionally NOT carried over -- HM sources every plugin itself.
#
# Ordering note: programs.tmux emits, in order:
#   1. mode-keys / prefix / etc. from the structured options below
#   2. each plugin's `extraConfig` then the plugin's own run-shell
#   3. the top-level `extraConfig` (after all plugins)
# The catppuccin theme must be configured BEFORE it loads (its @thm_*
# variables only exist after its run-shell), and the status-left/right and
# pane/window styling reference those @thm_* variables, so they live in the
# top-level extraConfig which HM places after the plugins.
#
# Plugins absent from nixpkgs are vendored via mkTmuxPlugin from a pinned
# fetchFromGitHub (see ddzero2c/tmux-easymotion below).

let
  tmux-easymotion = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-easymotion";
    version = "0-unstable-2026-05-18";
    rtpFilePath = "tmux-easymotion.tmux";
    src = pkgs.fetchFromGitHub {
      owner = "ddzero2c";
      repo = "tmux-easymotion";
      # Pinned commit; bump deliberately. Hash must be updated alongside rev
      # (nix store prefetch-file --unpack on the archive).
      rev = "c295db09a92e3f6db1e10879b8bc4d351d8917eb";
      hash = "sha256-3Yn8/W13Zr7HzUdRlsjBS+/WtoG0JsyTEWKePhny9bI=";
    };
  };
  # catppuccin v2 conf dir (sourced directly; its run-shell wrapper is broken
  # under tmux 3.6a). Mirrors what catppuccin.tmux does: source options then
  # the main conf (which itself sources themes/catppuccin_<flavor>_tmux.conf).
  catppuccinDir =
    "${pkgs.tmuxPlugins.catppuccin}/share/tmux-plugins/catppuccin";
in
{
  programs.tmux = {
    enable = true;

    # set -g prefix C-Space (line 10)
    prefix = "C-Space";
    # set-window-option -g mode-keys vi (line 38)
    keyMode = "vi";
    # set -g mouse on (line 11)
    mouse = true;
    # set -g base-index 1 (line 13)
    baseIndex = 1;
    # set-option -g history-limit 100000 (line 22)
    historyLimit = 100000;
    # set-option -g focus-events on (line 15)
    focusEvents = true;
    # set -g default-terminal "tmux-256color" (line 1)
    terminal = "tmux-256color";

    plugins = with pkgs.tmuxPlugins; [
      # set -g @plugin 'tmux-plugins/tmux-yank' (line 31)
      yank
      # set -g @plugin 'sainnhe/tmux-fzf' (line 32)
      tmux-fzf

      # set -g @plugin 'ddzero2c/tmux-easymotion' (line 36) + key 's' (line 33)
      {
        plugin = tmux-easymotion;
        extraConfig = ''
          set -g @easymotion-key 's'
        '';
      }

      # Extrakto: lines 45-47. @extrakto_open_tool path is macOS-specific
      # (/usr/bin/open); preserved verbatim. Revisit for Bazzite (xdg-open).
      {
        plugin = extrakto;
        extraConfig = ''
          set -g @extrakto_popup_size "50%"
          set -g @extrakto_open_tool "/usr/bin/open"
        '';
      }

      # set -g @plugin 'tmux-plugins/tmux-resurrect' (line 53)
      resurrect

      # tmux-online-status (line 50) + icons (lines 62-63)
      {
        plugin = online-status;
        extraConfig = ''
          set -g @online_icon "ok"
          set -g @offline_icon "nok"
        '';
      }

      # tmux-battery (line 51). No explicit options in source; consumed by
      # the status-right format string in extraConfig below.
      battery

      # catppuccin/tmux v2 (nixpkgs 2.1.3) is NOT added as a plugin entry:
      # its run-shell wrapper (catppuccin.tmux) fails under tmux 3.6a
      # (`returned 1`, @thm_* palette never set). Verified that sourcing the
      # two confs directly works (@thm_bg resolves). So catppuccin is loaded
      # via explicit source-file from the store path at the TOP of the
      # top-level extraConfig below, before the @thm_*-dependent styling.
    ];

    # Everything not expressible via structured options, preserved verbatim
    # from ~/.tmux.conf. Emitted by HM AFTER all plugins, so the @thm_*
    # references resolve against the loaded catppuccin theme.
    extraConfig = ''
      # ---- catppuccin v2 (sourced directly; run-shell wrapper broken) ----
      # Set options BEFORE sourcing so the theme/status confs pick them up.
      set -g @catppuccin_flavor "mocha"
      set -g @catppuccin_status_background "none"
      set -g @catppuccin_window_status_style "rounded"
      set -g @catppuccin_date_time_text "%Y-%m-%d %H:%M"
      source-file ${catppuccinDir}/catppuccin_options_tmux.conf
      source-file ${catppuccinDir}/catppuccin_tmux.conf

      # ---- terminal overrides (~/.tmux.conf lines 2-4) ----
      # tmux >=3.2 deprecated `Tc`; the RGB terminal-feature is what enables
      # 24-bit color (catppuccin uses hex). Tc kept for old-tmux compat.
      set -as terminal-features ",*:RGB"
      set -ga terminal-overrides ",*:Tc"
      set -as terminal-overrides ',*:Smulx=\E[4::%p1%dm'
      set -as terminal-overrides ',*:Setulc=\E[58::2::%p1%{65536}%/%d::%p1%{256}%/%{255}%&%d::%p1%{255}%&%d%;m'

      # ---- reload binding (HM config path, not the moved legacy file) ----
      unbind r
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"

      # ---- misc options not covered by structured settings ----
      set -g allow-passthrough on              # line 12
      set -g pane-base-index 1                  # line 14

      # ---- pane navigation (lines 17-20) ----
      bind-key h select-pane -L
      bind-key j select-pane -D
      bind-key k select-pane -U
      bind-key l select-pane -R

      # ---- copy-mode-vi selection bindings (lines 40-42) ----
      bind-key -T copy-mode-vi C-v send-keys -X begin-selection \; send-keys -X rectangle-toggle;
      bind-key -T copy-mode-vi v send-keys -X begin-selection;
      bind-key -T copy-mode-vi V send-keys -X select-line;

      # ---- status line via catppuccin v2 native modules ----
      # The legacy hand-rolled status-left/right used the v1 #{#[...]} idiom
      # which tmux 3.6a does not expand (segments rendered blank), and the
      # battery/online vars were never populated. Replaced with catppuccin v2
      # composable modules: set AFTER the plugin is loaded (sourced above).
      # `-agF` on battery so the module's #{battery_*} formats expand
      # (tmux-battery plugin loaded earlier in the plugins list).
      set -g status-position top
      set -g status-justify "left"
      set -g status-left-length 100
      set -g status-right-length 100
      set -g status-left "#{E:@catppuccin_status_session}"
      set -g status-right "#{E:@catppuccin_status_directory}"
      set -agF status-right "#{E:@catppuccin_status_battery}"
      set -ag status-right "#{E:@catppuccin_status_date_time}"

      # window list + pane borders are owned by catppuccin v2
      # (@catppuccin_window_status_style "rounded" set before the source).
      set -wg automatic-rename on
    '';
  };
}
