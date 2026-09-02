# Audio clips

Recorded human voices for the encouragement phrases. The app falls back to the
computer voice whenever a pool is empty or a clip won't load, so this directory
can be empty and everything still works.

- `hype/` — encouragement, played during a workout
- `completion/` — sign-offs, played when a timer or workout finishes
- `manifest.json` — generated; a static site can't list a directory

Clips are picked at random from the whole pool, so every speaker gets mixed
together and nobody has to record every phrase. Adding a new person needs no
code change — process their file, rebuild the manifest, commit.

## Adding a recording

Send them `RECORDING-SCRIPT.md`, then:

    ./tools/process-recordings.sh raw/theirname.m4a theirname hype
    ./tools/build-manifest.sh

Keep raw recordings in `raw/`, which is gitignored — only the split clips
belong in the repo.

The split runs on the pauses between phrases, trims each clip, and normalises
loudness to a common target so one speaker isn't louder than the rest.

## Sorting the two batches

People are asked to record encouragement first, say a marker out loud, then the
finishing lines. Everything lands in `hype/` initially; move the finishing ones:

    git mv audio/hype/name-41.m4a audio/completion/   # and the rest of the tail
    ./tools/build-manifest.sh

**Delete the marker clips.** They get split out as if they were phrases. Mom's
recording had two — one opening the during-workout batch, one before the
finishing lines — and both would otherwise have played as encouragement.

Finding the boundary is easier if the speaker mentions roughly where they
switched. Pause length alone is not a reliable signal: the longest silence in
Mom's recording was in the middle of the finishing lines, not at the boundary.
What identified the real marker was it being both the longest clip *and* the
only one with long silences on either side.

## If the split looks wrong

Check the clip count against how many phrases you expect before committing.

- **Too few clips** — phrases merged. Raise the threshold: `SILENCE_DB=-30dB`
- **Too many, or clips cut mid-word** — lower it: `SILENCE_DB=-45dB`
- **Sentences split at internal pauses** — raise `MIN_PAUSE=1.4`

Both are environment variables:

    SILENCE_DB=-30dB MIN_PAUSE=1.2 ./tools/process-recordings.sh raw/x.m4a name hype

To check for duds without listening to every file, look for clips that are
near-silent or suspiciously short:

    for f in audio/hype/*.m4a; do
      printf "%s %ss " "$(basename $f)" \
        "$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$f")"
      ffmpeg -hide_banner -i "$f" -af volumedetect -f null - 2>&1 | grep mean_volume
    done
