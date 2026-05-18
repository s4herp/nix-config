{ pkgs, lib, config, ... }:

# Native Home Manager rewrite of ~/.config/git/config (decision D3: full
# native rewrite). This is the ONE module with NO source dotfile in the repo:
# github.com/s4herp/dotfiles deliberately excludes ~/.config/git/config and
# the per-identity .gitconfig-shinkansen / .gitconfig-mudango plus the GPG
# key (excluded as secrets — dossier §4). So every value here is HAND-WRITTEN
# from the spec §6.3 / dossier text, never derived from the dotfiles repo.
#
# Spec §6.3 git.nix bullet (authoritative):
#   "programs.git con firma GPG (signing.signByDefault), includes/includeIf
#    para identidades condicionales por directorio (shinkansen / mudango),
#    init.defaultBranch, url.insteadOf SSH, excludes globales."
# Dossier §5.3: "init.defaultBranch=main".
# Dossier §4 (l.72-73): "firma GPG BF390DAAE816840D, identidades
#   condicionales shinkansen/mudango".
#
# Values the spec/dossier do NOT pin down are left as explicit
# TODO(spec §6.3) markers below rather than invented: the dotfiles repo that
# would carry the exact strings was deliberately emptied of them (dossier
# §4, "Vacío deliberado").

{
  programs.git = {
    enable = true;

    # --- GPG signing -------------------------------------------------------
    # Key id from dossier §4 (l.72-73, 133): "firma GPG BF390DAAE816840D".
    # signByDefault from spec §6.3: "firma GPG (signing.signByDefault)".
    signing = {
      key = "BF390DAAE816840D";
      signByDefault = true;
    };

    # --- init.defaultBranch ------------------------------------------------
    # Dossier §5.3 git.nix bullet: "init.defaultBranch=main".
    extraConfig = {
      init.defaultBranch = "main";

      # --- url.insteadOf SSH rewrites -------------------------------------
      # Spec §6.3: "url.insteadOf SSH". The bullet states the SSH rewrite
      # exists but does not enumerate which hosts/prefixes are rewritten.
      # The exact rewrite pairs lived only in the excluded ~/.config/git/
      # config (dossier §4, "Vacío deliberado"); not inventing them.
      #
      # TODO(spec §6.3): confirm exact url.insteadOf rewrite pairs (e.g.
      # url."git@github.com:".insteadOf = "https://github.com/"). Source the
      # real values from the live ~/.config/git/config on the macOS host,
      # since they are absent from both the dotfiles repo and the spec.

      # --- global excludes ------------------------------------------------
      # Spec §6.3: "excludes globales". The bullet asserts a global
      # excludesfile exists but does not list its contents, and the file
      # itself is not in the dotfiles repo.
      #
      # TODO(spec §6.3): confirm the global excludes (core.excludesFile
      # target and/or its entries) from the live macOS ~/.config/git/config
      # and its referenced excludesfile.
    };

    # --- Conditional identities (includeIf, by directory) -----------------
    # Spec §6.3: "includes/includeIf para identidades condicionales por
    # directorio (shinkansen / mudango)". Dossier §4/§5.3 confirm two
    # directory-scoped identities named shinkansen and mudango. The spec
    # pins the MECHANISM (gitdir-conditional includes) and the two identity
    # NAMES, but not the concrete gitdir paths nor the user.name/user.email
    # each identity sets — those lived only in the excluded
    # .gitconfig-shinkansen / .gitconfig-mudango (dossier §4).
    includes = [
      {
        # Shinkansen identity, active under the shinkansen worktree dir.
        #
        # TODO(spec §6.3): confirm exact gitdir condition path for the
        # shinkansen identity (e.g. "gitdir:~/dev/shinkansen/"). Path not
        # pinned by spec; read it from the live macOS ~/.config/git/config.
        condition = "gitdir:~/dev/shinkansen/"; # TODO(spec §6.3): confirm path
        contents = {
          # TODO(spec §6.3): confirm shinkansen user.name / user.email /
          # signing key. The session-known email
          # saher.pinero@shinkansen.finance is a strong candidate but is NOT
          # stated by spec §6.3, so it is NOT hardcoded here. Source from the
          # excluded .gitconfig-shinkansen on the macOS host.
          user = {
            # name = "TODO(spec §6.3): confirm shinkansen user.name";
            # email = "TODO(spec §6.3): confirm shinkansen user.email";
          };
        };
      }
      {
        # Mudango identity, active under the mudango worktree dir.
        #
        # TODO(spec §6.3): confirm exact gitdir condition path for the
        # mudango identity. Path not pinned by spec; read it from the live
        # macOS ~/.config/git/config.
        condition = "gitdir:~/dev/mudango/"; # TODO(spec §6.3): confirm path
        contents = {
          # TODO(spec §6.3): confirm mudango user.name / user.email /
          # signing key from the excluded .gitconfig-mudango on the macOS
          # host. No value for the mudango identity appears anywhere in the
          # spec or dossier, so nothing is invented here.
          user = {
            # name = "TODO(spec §6.3): confirm mudango user.name";
            # email = "TODO(spec §6.3): confirm mudango user.email";
          };
        };
      }
    ];
  };
}
