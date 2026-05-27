# Commit script pattern — pre-push gates for capability-portrait repos

The scaffold ships `scripts/commit_template.sh` as a copy-and-customize
template for any `commit_dayN.sh` helper. Two engineering lessons are
baked in, both surfaced during multi-day capability-portrait development.

---

## Lχ — heredoc commit messages (no inline `-m`)

### Symptom

Running `git commit -m "DMOI Day-3 ! results"` in `zsh` errors out with
`zsh: event not found: results`. Similarly, `echo "Download pid=$!, log=..."`
errors with `zsh: event not found: ,`.

### Cause

`zsh` enables `BANG_HIST` by default. Any `!` in a double-quoted string
triggers history expansion at parse time. This affects two common patterns:

1. Commit messages with `!` (exclamation marks, version-bumping notes).
2. `echo` lines that interpolate `$!` (background-process PID) followed by
   punctuation, where `zsh` greedily reads `$!,` as a history reference.

### Fix

Use heredoc input or single-quoted strings for anything containing `!`:

```bash
# WRONG — zsh will mangle this on the spot
git commit -m "Day-3 results: 650 patients!"

# RIGHT — heredoc, no expansion
git commit -F- <<'MSG'
Day-3 results: 650 patients!
MSG

# WRONG — $!, parsed as history reference
echo "Started in background, pid=$!, log=$LOG"

# RIGHT — single quotes (or split the line)
DOWNLOAD_PID=$!
echo 'Started in background. PID + log printed separately.'
echo "  pid=${DOWNLOAD_PID}"
echo "  log=${LOG}"
```

### Generalizing

Any shell wrapper that emits commit messages OR echoes shell-variable
content should use heredoc / single-quoted forms by default. Add
`setopt no_banghist` near the top of `scripts/run_lab.sh` (or any
sourced helper) if you want to disable the expansion entirely for
operator-side scripts.

---

## Lτ — pre-push CJK gate (don't waste a CI round-trip)

### Symptom

Push a commit that accidentally contains CJK characters in a public
artifact (README, audit MD, code comment). CI fails the english-only
job. Round-trip cost: push → wait for CI → fix → push again.

### Cause

The scaffold's english-only enforcement was originally CI-side only
(`.github/workflows/english-only.yml`). The check_english_only.py
script existed locally, but commit helpers never invoked it pre-push.
Mistakes (e.g. a leftover Korean comment) only surfaced after the
push.

### Fix

Every `commit_*.sh` helper runs `python3 scripts/check_english_only.py`
as a pre-push gate. The scanner exits non-zero if it finds any CJK
character in tracked + staged public artifacts. The shell script's
`set -e` aborts the push.

```bash
echo "=== Pre-push CJK gate (Lτ) ==="
python3 scripts/check_english_only.py
```

The scanner's default globs already cover the public surface:

```
README.md
src/**/*.py
tests/**/*.py
docs/**/*.md
audit/**/*.md          # added v0.2; previously not scanned
scripts/**/*.sh
scripts/**/*.py
.github/workflows/**/*.yml
```

### Generalizing

Any policy enforced by CI that's catchable client-side should also have
a client-side gate. Costs ~50ms locally; saves a 30-90s CI round-trip
per catchable mistake. Apply the same pattern to:

- Lint (ruff) — already in commit_template.sh as a tolerant gate
  (skipped if ruff isn't locally installed; CI is canonical).
- Unit tests (pytest) — same tolerance pattern.
- Type checks (mypy) — same pattern if/when added.

---

## How to adopt for a new day-N commit

1. Copy: `cp scripts/commit_template.sh scripts/commit_dayN.sh`
2. Edit `FILES_TO_STAGE` array with the actual paths you're committing.
3. Edit the heredoc commit message between `<<'MSG'` and `MSG`.
4. Run: `bash scripts/commit_dayN.sh`.

The script will run the pre-push gates, abort on failure, otherwise
commit + push + tail the resulting GitHub Actions runs.
