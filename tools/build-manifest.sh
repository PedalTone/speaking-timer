#!/usr/bin/env bash
#
# Regenerates audio/manifest.json from whatever clips are in
# audio/<style>/<pool>/. A static site can't list a directory, so the app reads
# this file to learn which clips exist. Run after adding or deleting clips.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

python3 - <<'PY'
import json, os

STYLES = ("supportive", "cheeky")
POOLS = ("hype", "completion")

manifest = {}
for style in STYLES:
    manifest[style] = {}
    for pool in POOLS:
        d = os.path.join("audio", style, pool)
        files = sorted(
            f"{style}/{pool}/{n}" for n in os.listdir(d)
            if n.lower().endswith((".m4a", ".mp3", ".wav")) and not n.startswith(".")
        ) if os.path.isdir(d) else []
        manifest[style][pool] = files
        print(f"{style}/{pool}: {len(files)} clips")

os.makedirs("audio", exist_ok=True)
with open("audio/manifest.json", "w") as f:
    json.dump(manifest, f, indent=1)
    f.write("\n")
print("wrote audio/manifest.json")
PY
