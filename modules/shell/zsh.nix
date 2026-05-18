{ pkgs, lib, config, ... }:

# Native Home Manager rewrite of ~/.zshrc + ~/.zshenv + ~/.zprofile + the
# antidote plugin set (decision D3: full native rewrite, no antidote at
# runtime). Source of truth: github.com/s4herp/dotfiles (on macOS the files
# already live in $HOME, origin of the legacy ~/.cfg bare-repo).
#
# Machine/tool-specific bits (asdf, brew, conda/nvm lazy-load, OrbStack,
# iTerm2, JetBrains, libpq, cargo, lmstudio) are preserved as guarded
# conditionals: they no-op when the tool is absent, so the same module works
# on macOS now and Bazzite later. asdf coexists with the monorail toolchain
# (not replaced here; see dossier M4).

{
  # Vendored Powerlevel10k config (1641 lines, p10k configure wizard output).
  # Not in the dotfiles repo nor ~/.cfg; vendored here to close the
  # reproducibility hole (Bazzite would otherwise have no prompt config).
  # zsh.nix's initContent already sources ~/.p10k.zsh if present.
  home.file.".p10k.zsh".source = ../../p10k.zsh;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = false; # managed explicitly below for plugin order
    syntaxHighlighting.enable = false; # must be sourced LAST, see plugins list

    history = {
      share = true; # SHARE_HISTORY
      ignoreAllDups = true; # HIST_IGNORE_ALL_DUPS
      expireDuplicatesFirst = true; # HIST_EXPIRE_DUPS_FIRST
      findNoDups = true; # HIST_FIND_NO_DUPS
      saveNoDups = true; # HIST_SAVE_NO_DUPS
      extended = true;
    };

    setOptions = [
      "AUTO_CD"
      "AUTO_PUSHD"
      "PUSHD_IGNORE_DUPS"
      "PUSHD_MINUS"
      "EXTENDED_GLOB"
      "NULL_GLOB"
      "AUTO_MENU"
      "AUTO_LIST"
    ];

    # Plugin order is significant and mirrors .zsh_plugins.txt:
    # powerlevel10k -> completions(fpath) -> autosuggestions -> fzf-tab ->
    # syntax-highlighting (LAST).
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
      {
        name = "zsh-autosuggestions";
        src = pkgs.zsh-autosuggestions;
        file = "share/zsh-autosuggestions/zsh-autosuggestions.zsh";
      }
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
      {
        name = "zsh-syntax-highlighting";
        src = pkgs.zsh-syntax-highlighting;
        file = "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
      }
    ];

    shellAliases = {
      # eza
      ls = "eza --icons";
      ll = "eza -la --icons";
      lt = "eza --tree --icons";
      # neovim
      vim = "nvim";
      vi = "nvim";
      v = "nvim";
      nvvr = "nvim --server ~/.nvimpipe --remote-tab";
      # tmux
      tma = "tmux attach-session -t";
      tmn = "tmux new-session -s";
      tml = "tmux list-sessions";
      tmk = "tmux kill-session -t";
      # zoxide
      j = "z";
      ji = "zi";
      # legacy bare-repo management (kept until ~/.cfg is archived in M6)
      config = "git --git-dir=$HOME/.cfg/ --work-tree=$HOME";
    };

    initContent = lib.mkMerge [
      # ---- TOP: instant prompt + early return (must be first) ----
      (lib.mkBefore ''
        case $ZSH_EVAL_CONTEXT in
          *:file) return ;;
        esac

        typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
        if [[ -o interactive ]] && [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi

        unsetopt BEEP

        # zsh-completions definitions on fpath (replaces antidote kind:fpath)
        fpath=(${pkgs.zsh-completions}/share/zsh/site-functions $fpath)
      '')

      # ---- MAIN ----
      ''
        # 3. ENVIRONMENT VARIABLES
        export GPG_TTY=$TTY
        export NVM_DIR="$HOME/.nvm"
        export EDITOR="nvim"
        export VISUAL="nvim"
        export MANPAGER='nvim +Man!'

        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_DEFAULT_OPTS='--height 60% --layout=reverse --border --ansi --color=16'
        export FZF_TMUX=1
        export FZF_TMUX_OPTS='-p80%,60%'

        ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE="20"
        ZSH_AUTOSUGGEST_USE_ASYNC=1
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#663399,standout"
        ZSH_AUTOSUGGEST_STRATEGY=(history completion)
        ZSH_AUTOSUGGEST_MANUAL_REBIND=1
        ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=(end-of-line vi-end-of-line vi-add-eol)

        # 4. PATH
        [ -d "$HOME/.lmstudio/bin" ] && export PATH="$PATH:$HOME/.lmstudio/bin"
        [ -d "$HOME/.local/bin" ] && export PATH="$PATH:$HOME/.local/bin"
        [ -d "/opt/homebrew/opt/libpq/bin" ] && export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

        # 5. COMPLETION STYLES
        [[ ! -d ~/.zsh/cache ]] && mkdir -p ~/.zsh/cache
        zstyle ':completion:*' use-cache on
        zstyle ':completion:*' cache-path ~/.zsh/cache
        zstyle ':completion:*' accept-exact '*(N)'
        zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
        zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
        zstyle ':completion:*' menu no
        zstyle ':completion:*:descriptions' format '[%d]'

        # asdf (coexists with monorail toolchain; not replaced here)
        if [ -f "$HOME/.asdf/asdf.sh" ]; then
          . "$HOME/.asdf/asdf.sh"
          fpath=(''${ASDF_DIR}/completions $fpath)
        fi

        # 7. FZF-TAB CONFIG (plugin already sourced above)
        zstyle ':fzf-tab:*' fzf-command fzf
        zstyle ':fzf-tab:*' switch-group '<' '>'
        zstyle ':fzf-tab:*' continuous-trigger '/'
        zstyle ':fzf-tab:*' fzf-flags \
          --height=60% --layout=reverse --border --ansi \
          --color=fg:8,fg+:15,bg:0,bg+:0 \
          --color=hl:3,hl+:11,info:6,marker:9,prompt:4,spinner:6,pointer:15,header:6 \
          --bind=tab:down,shift-tab:up,ctrl-space:toggle

        # 8. FZF-TAB PREVIEWS
        if command -v eza &> /dev/null; then
          zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons $realpath 2>/dev/null || ls -la --color=always $realpath'
        else
          zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -la --color=always $realpath'
        fi
        zstyle ':completion:*:git-checkout:*' command 'git for-each-ref --format="%(refname:short)" --sort=-committerdate refs/heads/ refs/remotes/'
        zstyle ':fzf-tab:complete:git-checkout:*' fzf-preview 'git log --oneline --color=always -10 $word 2>/dev/null || echo "No commits found"'
        zstyle ':fzf-tab:complete:git-add:*' fzf-preview 'git diff --color=always $word 2>/dev/null || bat --color=always $word 2>/dev/null || cat $word'
        zstyle ':fzf-tab:complete:git-log:*' fzf-preview 'git log --color=always --oneline -10 $word'
        zstyle ':fzf-tab:complete:git-diff:*' fzf-preview 'git diff --color=always $word'
        if command -v bat &> /dev/null; then
          zstyle ':fzf-tab:complete:(vim|nvim|vi|nano|cat|bat):*' fzf-preview 'bat --color=always --line-range :50 $realpath 2>/dev/null || cat $realpath'
        fi
        zstyle ':fzf-tab:complete:docker-exec:*' fzf-preview 'docker inspect --format "{{.Config.Image}}\n{{.State.Status}}\n{{.NetworkSettings.IPAddress}}" $word'

        # 9. TOOL INIT
        if command -v brew &> /dev/null; then
          eval "$(brew shellenv)"
        elif [ -x /opt/homebrew/bin/brew ]; then
          eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
          eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi
        # brew shellenv prepends Homebrew to PATH; re-prepend the Nix profile
        # so nix-pinned tools (neovim/D4, cli.nix set) win over Homebrew.
        # `typeset -U path` (HM header) dedupes, keeping the front entry.
        path=("$HOME/.nix-profile/bin" /nix/var/nix/profiles/default/bin $path)
        if [ -f "$HOME/.atuin/bin/env" ]; then
          . "$HOME/.atuin/bin/env"
          eval "$(atuin init zsh)"
        fi
        [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
        # direnv hook is owned by modules/direnv.nix (programs.direnv injects
        # `direnv hook zsh` into HM's zsh integration). Do NOT re-add it here.
        if command -v zoxide &> /dev/null; then
          eval "$(zoxide init zsh)"
        fi

        # 10. KEY BINDINGS
        if [[ -o interactive ]]; then
          bindkey '^I' fzf-tab-complete
          bindkey '^[[C' autosuggest-accept
          bindkey '^[[1;3C' autosuggest-accept
          bindkey '^[[Z' reverse-menu-complete
          bindkey '^[[1;5C' forward-word
          bindkey '^[[1;5D' backward-word
          bindkey '^[[H' beginning-of-line
          bindkey '^[[F' end-of-line
          bindkey '^[^[[D' backward-word
          bindkey '^[^[[C' forward-word
        fi

        # 11. CUSTOM FUNCTIONS
        fcd() {
          local dir
          dir=$(find ''${1:-.} -path '*/\.*' -prune -o -type d -print 2> /dev/null | fzf +m) &&
          cd "$dir"
        }
        fgb() {
          local branches branch
          branches=$(git for-each-ref --format='%(refname:short)' --sort=-committerdate refs/heads/) &&
          branch=$(echo "$branches" | fzf --preview 'git log --oneline --color=always -10 {}' +m) &&
          git checkout "$branch"
        }
        fv() {
          local files
          files=$(fd --type f --hidden --follow --exclude .git | fzf --preview 'bat --color=always --line-range :50 {}' --multi)
          [ -n "$files" ] && echo "$files" | xargs nvim
        }
        fkill() {
          local pid
          pid=$(ps -ef | sed 1d | fzf -m | awk '{print $2}')
          if [ "x$pid" != "x" ]; then
            echo $pid | xargs kill -''${1:-9}
          fi
        }
        ftm() {
          local session
          session=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | fzf --preview "tmux capture-pane -pt {}")
          [ -n "$session" ] && tmux attach-session -t "$session"
        }
        tts() {
          "$HOME/Dev/tts-reader/.venv/bin/python" "$HOME/Dev/tts-reader/read_aloud.py" "$@"
        }

        # 12. LAZY LOADING
        conda() {
          unset -f conda
          local conda_bin="''${CONDA_HOME:-$HOME/miniconda3}/bin/conda"
          __conda_setup="$("$conda_bin" 'shell.zsh' 'hook' 2> /dev/null)"
          if [ $? -eq 0 ]; then
            eval "$__conda_setup"
          else
            local conda_sh="''${CONDA_HOME:-$HOME/miniconda3}/etc/profile.d/conda.sh"
            if [ -f "$conda_sh" ]; then
              . "$conda_sh"
            else
              export PATH="''${CONDA_HOME:-$HOME/miniconda3}/bin:$PATH"
            fi
          fi
          unset __conda_setup
          conda "$@"
        }
        nvm() {
          unset -f nvm
          npm config delete prefix 2>/dev/null
          [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
          [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
          nvm "$@"
        }

        # 13. TMUX INTEGRATION
        if [[ -o interactive ]] && command -v tmux &> /dev/null && [ -z "$TMUX" ] && [ -z "$INSIDE_EMACS" ] && [ -z "$VIM" ] && [ -z "$VSCODE_INJECTION" ] && [[ -t 0 ]]; then
          if tmux list-sessions &>/dev/null; then
            exec tmux attach-session
          else
            exec tmux new-session -s main
          fi
        fi

        # tmux alias depends on terminal program
        if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
          alias tm='tmux -CC new -A -s main'
        else
          alias tm='tmux new -A -s main'
        fi

        # .zprofile content (login-shell env, kept inline; guarded)
        _jb_scripts="$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
        [ -d "$_jb_scripts" ] && export PATH="$PATH:$_jb_scripts"
        [ -f "$HOME/.orbstack/shell/init.zsh" ] && source "$HOME/.orbstack/shell/init.zsh"
        [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
      ''

      # ---- BOTTOM: theme + secrets (must be after main) ----
      (lib.mkAfter ''
        if [[ -o interactive ]]; then
          [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
          if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
            export ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX=YES
            test -e "''${HOME}/.iterm2_shell_integration.zsh" && source "''${HOME}/.iterm2_shell_integration.zsh"
          fi
        fi

        # Secrets cache (§7): sourced if present; shell never breaks if absent.
        # The cache is materialized on demand by secrets-refresh (M3), never
        # declared in HM, never in the nix store, never in VCS.
        [ -r "''${TMPDIR:-/tmp}/ring/secrets" ] && source "''${TMPDIR:-/tmp}/ring/secrets"
        [ -r "$HOME/.cache/ring/secrets" ] && source "$HOME/.cache/ring/secrets"
        # ~/.zsh_secrets retired: secrets now come from the op-injected cache
        # above (M3). ~/.zshrc.local kept as a local non-secret override.
        [ -f ~/.zshrc.local ] && source ~/.zshrc.local
      '')
    ];
  };
}
