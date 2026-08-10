#!/usr/bin/env bash
#
# Regenerates audio/manifest.json from whatever clips are in audio/hype/ and
# audio/completion/. A static site can't list a directory, so the app reads
# this file to learn which clips exist. Run after adding or deleting clips.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

python3 - <<'PY'
import json, os

manifest = {}
for pool in ("hype", "completion"):
    d = os.path.join("audio", pool)
    files = sorted(
        f"{pool}/{n}" for n in os.listdir(d)
        if n.lower().endswith((".m4a", ".mp3", ".wav")) and not n.startswith(".")
    ) if os.path.isdir(d) else []
    manifest[pool] = files
    print(f"{pool}: {len(files)} clips")

os.makedirs("audio", exist_ok=True)
with open("audio/manifest.json", "w") as f:
    json.dump(manifest, f, indent=1)
    f.write("\n")
print("wrote audio/manifest.json")
PY
