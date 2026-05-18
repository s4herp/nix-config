# op inject template — pointers only, safe to commit (no secret values).
# Resolved on demand by `secrets-refresh` (op inject) into a 0600 cache
# OUTSIDE the nix store and VCS. Never sourced at shell startup.
export SHORTCUT_API_KEY="op://Personal/SHORTCUT_API_KEY/password"
export GITHUB_PERSONAL_ACCESS_TOKEN="op://Personal/GITHUB_PERSONAL_ACCESS_TOKEN/password"
export OPENAI_API_KEY="op://Personal/OPENAI_API_KEY/password"
