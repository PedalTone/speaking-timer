#!/usr/bin/env bash
#
# Writes the current date and time into the version line at the bottom of the
# app, so what's on screen identifies the build you're actually running.
#
# Run before committing. The pre-commit hook installed by tools/install-hooks.sh
# does this automatically; this script is here for running it by hand.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Date-based rather than a commit hash: the hash of the commit being made isn't
# knowable while making it, and a date sorts naturally when comparing builds.
STAMP="v$(date +%Y.%m.%d).$(date +%H%M)"

python3 - "$STAMP" <<'PY'
import re, sys
stamp = sys.argv[1]
path = "index.html"
src = open(path).read()
new, n = re.subn(
    r'(<div class="version" id="version">)[^<]*(</div>)',
    lambda m: m.group(1) + stamp + m.group(2),
    src,
    count=1,
)
if n != 1:
    sys.exit("could not find the version element in index.html")
if new != src:
    open(path, "w").write(new)
print(f"stamped {stamp}")
PY
