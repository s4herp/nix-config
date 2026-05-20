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
  # Build-time guard: fail the HM build if `path` does not exist. Returns
  # `path` as a string on success so it can be inlined into source-file /
  # run-shell directives below. Rationale: tmux silently no-ops a missing
  # source-file / run-shell target (the error only shows under `tmux -v`),
  # which is how the broken `rtpFilePath = "tmux-easymotion.tmux"` (upstream
  # renamed the file to `easymotion.tmux`) stayed undetected. Any future
  # upstream rename now breaks `home-manager switch` loudly instead.
  assertFile = path:
    let
      str = toString path;
      checked = pkgs.runCommandLocal "tmux-assert-${baseNameOf str}" { } ''
        if [ ! -e "${str}" ]; then
          echo "tmux config references missing file: ${str}" >&2
          exit 1
        fi
        touch $out
      '';
    in
    builtins.seq checked.outPath str;

  # Vendored plugin. mkTmuxPlugin emits a `run-shell` referencing
  # `$out/share/tmux-plugins/$pluginName/$rtpFilePath`; if that file is not
  # in `src`, tmux silently skips it. The postBuild assertion below makes
  # that mismatch a hard build error.
  tmux-easymotion = (pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "tmux-easymotion";
    version = "0-unstable-2026-05-18";
    rtpFilePath = "easymotion.tmux";
    src = pkgs.fetchFromGitHub {
      owner = "ddzero2c";
      repo = "tmux-easymotion";
      # Pinned commit; bump deliberately. Hash must be updated alongside rev
      # (nix store prefetch-file --unpack on the archive).
      rev = "c295db09a92e3f6db1e10879b8bc4d351d8917eb";
      hash = "sha256-3Yn8/W13Zr7HzUdRlsjBS+/WtoG0JsyTEWKePhny9bI=";
    };
  }).overrideAttrs (old: {
    postBuild = (old.postBuild or "") + ''
      target="$out/share/tmux-plugins/tmux-easymotion/easymotion.tmux"
      if [ ! -e "$target" ]; then
        echo "mkTmuxPlugin: rtpFilePath does not exist in plugin output: $target" >&2
        exit 1
      fi
    '';
  });
  # catppuccin v2 conf dir (sourced directly; its run-shell wrapper is broken
  # under tmux 3.6a). Mirrors what catppuccin.tmux does: source options then
  # the main conf (which itself sources themes/catppuccin_<flavor>_tmux.conf).
  catppuccinDir =
    "${pkgs.tmuxPlugins.catppuccin}/share/tmux-plugins/catppuccin";
  # battery / online-status replace #{battery_*}/#{online_status} placeholders
  # in status-right ONCE when their .tmux runs. HM runs plugin run-shell
  # BEFORE extraConfig, so they must instead be sourced AFTER status-right is
  # set (end of extraConfig), not listed as plugins.
  batteryTmux =
    "${pkgs.tmuxPlugins.battery}/share/tmux-plugins/battery/battery.tmux";
  onlineTmux =
    "${pkgs.tmuxPlugins.online-status}/share/tmux-plugins/online-status/online_status.tmux";
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

      # tmux-online-status + tmux-battery are NOT plugin entries: they
      # string-replace placeholders in status-right and HM would run them
      # before status-right is set. Sourced at the end of extraConfig instead
      # (see batteryTmux/onlineTmux).

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
      # Only the @thm_* palette is needed; status line is hand-rolled below
      # (the legacy look). status_background none keeps catppuccin from
      # overriding our own status-style.
      set -g @catppuccin_flavor "mocha"
      set -g @catppuccin_status_background "none"
      source-file ${assertFile "${catppuccinDir}/catppuccin_options_tmux.conf"}
      source-file ${assertFile "${catppuccinDir}/catppuccin_tmux.conf"}

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

      # ---- status bar base (legacy look, de-nested for tmux 3.6a) ----
      # tmux 3.6a does not expand the v1 `#{#[...]}` wrapper; the legacy
      # strings are reproduced verbatim with `#{#[STYLE]TEXT}` -> `#[STYLE]TEXT`.
      set -g status-position bottom
      set -g status-style "bg=#{@thm_bg}"
      set -g status-justify "absolute-centre"

      # ---- status left (legacy lines 66-74, de-nested) ----
      set -g status-left-length 100
      set -g status-left ""
      # Commas inside #[...] are the ternary separator at depth 0 in tmux's
      # #{?,,} parser, so styles inside a conditional must be split into
      # comma-free #[..] chains (#[a,b,c] -> #[a]#[b]#[c]).
      set -ga status-left "#{?client_prefix,#[bg=#{@thm_red}]#[fg=#{@thm_bg}]#[bold]  #S ,#[bg=#{@thm_bg}]#[fg=#{@thm_green}]  #S }"
      set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_overlay_0},none]│"
      set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_maroon}]  #{pane_current_command} "
      set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_overlay_0},none]│"
      set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_blue}]  #{=/-32/...:#{s|$USER|~|:#{b:pane_current_path}}} "
      set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_overlay_0},none]#{?window_zoomed_flag,│,}"
      set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_yellow}]#{?window_zoomed_flag,  zoom ,}"

      # ---- status right (legacy lines 77-83, de-nested) ----
      set -g status-right-length 100
      set -g status-right ""
      set -ga status-right "#{?#{e|>=:10,#{battery_percentage}},#[bg=#{@thm_red}]#[fg=#{@thm_bg}],#[bg=#{@thm_bg}]#[fg=#{@thm_pink}]} #{battery_icon} #{battery_percentage} "
      set -ga status-right "#[bg=#{@thm_bg},fg=#{@thm_overlay_0}, none]│"
      set -ga status-right "#[bg=#{@thm_bg}]#{?#{==:#{online_status},ok},#[fg=#{@thm_mauve}] 󰖩 on ,#[fg=#{@thm_red}]#[bold]#[reverse] 󰖪 off }"
      set -ga status-right "#[bg=#{@thm_bg},fg=#{@thm_overlay_0}, none]│"
      set -ga status-right "#[bg=#{@thm_bg},fg=#{@thm_blue}] 󰭦 %Y-%m-%d 󰅐 %H:%M "

      # ---- pane border look and feel (legacy lines 90-94) ----
      setw -g pane-border-status top
      setw -g pane-border-format ""
      setw -g pane-active-border-style "bg=#{@thm_bg},fg=#{@thm_overlay_0}"
      setw -g pane-border-style "bg=#{@thm_bg},fg=#{@thm_surface_0}"
      setw -g pane-border-lines single

      # ---- window look and feel (legacy lines 97-108) ----
      set -wg automatic-rename on
      set -g automatic-rename-format "Window"
      set -g window-status-format " #I#{?#{!=:#{window_name},Window},: #W,} "
      set -g window-status-style "bg=#{@thm_bg},fg=#{@thm_rosewater}"
      set -g window-status-last-style "bg=#{@thm_bg},fg=#{@thm_peach}"
      set -g window-status-activity-style "bg=#{@thm_red},fg=#{@thm_bg}"
      set -g window-status-bell-style "bg=#{@thm_red},fg=#{@thm_bg},bold"
      set -gF window-status-separator "#[bg=#{@thm_bg},fg=#{@thm_overlay_0}]│"
      set -g window-status-current-format " #I#{?#{!=:#{window_name},Window},: #W,} "
      set -g window-status-current-style "bg=#{@thm_peach},fg=#{@thm_bg},bold"

      # ---- battery + online-status: source AFTER status-right is set so
      # their one-shot placeholder substitution applies (legacy icons) ----
      set -g @online_icon "ok"
      set -g @offline_icon "nok"
      run-shell ${assertFile onlineTmux}
      run-shell ${assertFile batteryTmux}
    '';
  };
}
