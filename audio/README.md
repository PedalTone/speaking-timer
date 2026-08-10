# Audio clips

Recorded human voices for the encouragement phrases. Empty by default — the
app falls back to the computer voice whenever a pool has no clips, so this
directory can stay empty.

- `hype/` — encouragement, played during a workout
- `completion/` — sign-offs, played when a timer or workout finishes
- `manifest.json` — generated; a static site can't list a directory

## Adding recordings

Send someone `RECORDING-SCRIPT.md`. When their recording comes back:

    ./tools/process-recordings.sh their-recording.m4a theirname hype
    ./tools/build-manifest.sh

The first command splits the recording on the pauses between phrases, trims
and level-matches each one, and writes `theirname-01.m4a` and so on. Listen
through, delete any duds, then rebuild the manifest and commit.

Clips are picked at random from the whole pool, so speakers get mixed together
and nobody has to record every phrase.
