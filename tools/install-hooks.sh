#!/usr/bin/env bash
#
# Installs a pre-commit hook that stamps the version before each commit, so the
# version on screen can never drift from what was actually deployed.
#
# Hooks live in .git/hooks, which git doesn't track, so this has to be run once
# per clone:  ./tools/install-hooks.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/.git/hooks/pre-commit"

cat > "$HOOK" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
"$ROOT/tools/stamp-version.sh" >/dev/null
# Re-stage only if the stamp actually changed something.
git add "$ROOT/index.html"
EOF

chmod +x "$HOOK"
echo "installed $HOOK"
