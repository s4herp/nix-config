{ ... }:

# Native Home Manager rewrite of the live ~/.gitconfig (decision D3). The
# dotfiles repo deliberately excludes git config + per-identity files + the
# GPG key (dossier §4, "Vacío deliberado"), so the spec §6.3 only pins the
# MECHANISM. The concrete values below were read from the live macOS host:
#   ~/.gitconfig, ~/.gitconfig-shinkansen, ~/.gitconfig-mudango,
#   ~/.gitignore_global
# as the dossier instructs ("read the real values from the live host").
#
# NOTE: credential.helper=osxkeychain previously came from Homebrew's system
# config /opt/homebrew/etc/gitconfig. The PATH fix makes the Nix git win,
# which does NOT read that file, so the helper is declared here explicitly or
# credential storage silently breaks.
#
# HM 25.05+ renamed:
#   programs.git.userName    -> programs.git.settings.user.name
#   programs.git.userEmail   -> programs.git.settings.user.email
#   programs.git.extraConfig -> programs.git.settings
# `signing.{key,signByDefault}` remain top-level options. `signing.format`
# must be set explicitly (GPG no longer default for stateVersion >= 25.05).

{
  programs.git = {
    enable = true;

    # Single GPG key for both identities (the only key present).
    signing = {
      format = "openpgp";
      key = "BF390DAAE816840D";
      signByDefault = true; # commit.gpgsign / tag.gpgsign = true
    };

    # core.excludesfile = ~/.gitignore_global (contents: .DS_Store).
    # HM manages this via its own excludes file.
    ignores = [ ".DS_Store" ];

    settings = {
      # Global identity = personal (default outside ~/dev/shinkansen/).
      user = {
        name = "Saher Piñero";
        email = "saherp145@gmail.com";
      };
      init.defaultBranch = "main";
      tag.sort = "-version:refname";
      branch.sort = "-committerdate";
      completion.sort = false;
      # SSH rewrite: clone https URLs over SSH.
      url."git@github.com:".insteadOf = "https://github.com/";
      # Was provided by Homebrew's system gitconfig; declared here so the
      # Nix git keeps using the macOS keychain credential helper.
      credential.helper = "osxkeychain";
      # Sourcetree diff/merge integration, preserved verbatim from
      # ~/.gitconfig (no-op unless those tools are invoked).
      difftool.sourcetree.cmd = "opendiff";
      difftool.sourcetree.path = "";
      mergetool.sourcetree.cmd =
        "~/Applications/Sourcetree.app/Contents/Resources/opendiff-w.sh";
      mergetool.sourcetree.trustExitCode = true;
    };

    # Work identity, scoped to the shinkansen worktree dir (mudango removed,
    # no longer working there). Same GPG key, work email.
    includes = [
      {
        condition = "gitdir:~/dev/shinkansen/";
        contents.user = {
          name = "Saher Piñero";
          email = "saher.pinero@shinkansen.finance";
          signingKey = "BF390DAAE816840D";
        };
      }
    ];
  };
}
