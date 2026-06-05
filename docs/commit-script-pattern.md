# Commit script pattern, pre-push gates for capability-portrait repos

The scaffold ships `scripts/commit_template.sh` as a copy-and-customize
template for any `commit_dayN.sh` helper. Two engineering lessons are
baked in, both surfaced during multi-day capability-portrait development.

---

## Lχ, heredoc commit messages (no inline `-m`)

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
# WRONG, zsh will mangle this on the spot
git commit -m "Day-3 results: 650 patients!"

# RIGHT, heredoc, no expansion
git commit -F- <<'MSG'
Day-3 results: 650 patients!
MSG

# WRONG, $!, parsed as history reference
echo "Started in background, pid=$!, log=$LOG"

# RIGHT, single quotes (or split the line)
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

## Lς, stale `.git/index.lock` cascade failure

### Symptom

You paste a long Mac ship sequence:

```bash
git add ...
git commit -m "..."
git push
git tag -a vX.Y -m "..."
git push --tags
gh release create vX.Y --notes-file RELEASE_NOTES_vX.Y.md
git rm RELEASE_NOTES_vX.Y.md
git commit -m "chore: ..."
git push
```

The `git add`, `git commit`, and `git rm` lines emit
`fatal: Unable to create '.git/index.lock': File exists.` (one line,
easy to miss when scrolling output). The intervening `git push`
outputs `Everything up-to-date` (no new commit so nothing to push).
**But `git tag -a vX.Y` and `git push --tags` succeed**, and so does
`gh release create vX.Y`. End state: the new tag and GitHub Release
exist remotely, but they point at the *prior* HEAD, the v(X.Y-1)
cleanup commit, not the new feature commit. The release page looks
shipped, the code isn't there.

### Cause

`git`'s plumbing commands that mutate the index (`add`, `commit`,
`rm`, `reset`, `merge`, `cherry-pick`, ...) all hold `.git/index.lock`
for the duration of the op. If a previous git process was killed
(editor crash, terminal closed, sandbox tool with `.git`
permissions, cancelled rebase), the lock file is left behind and
every subsequent index-mutating command fails fast with the
`fatal: ... index.lock: File exists` message.

The cascade trap: `git tag`, `git push`, `git push --tags`, and
`gh release` do **not** touch the index, they only read refs and
objects, so they succeed cheerfully on top of the failed
`git add` / `git commit`. Multi-step heredoc-paste sequences with
`set -e` semantics in the *user's* head but not in the shell will
ghost-ship.

### Fix

Always start a ship sequence with:

```bash
rm -f .git/index.lock
git status >/dev/null 2>&1 || { echo "STALE LOCK ABORT"; exit 1; }
```

Or, if you're in a `bash`-style heredoc that's actually piped to
`bash`, use `set -euo pipefail` so failures abort the pipeline
properly. The scaffold's `commit_template.sh` ships both guards.

### Generalizing

The same pattern applies to any tool that *might* leave a lock file:
`flock`, `pip --user`, `make` (intermediate target files), `pytest
--lf` (`.pytest_cache/`), `ruff` (`.ruff_cache/`). If the workflow
is "first command takes the lock, later commands inspect-only":
clear the lock upfront, fast-fail if it's still there for some
other reason.

### Provenance

Surfaced 2026-05-28 during DMOI v0.6 ship. A prior session left
`.git/index.lock` in place. The pasted heredoc Mac sequence silently
ghost-shipped v0.6 (tag + GitHub Release at v0.5 cleanup commit
`8a97d11`). Recovery: `gh release delete v0.6 --cleanup-tag --yes`,
then re-run from `git add` after lock removal. Tag and Release ended
up at the correct commit (`ed38f95`).

---

## How to adopt for a new day-N commit

1. Copy: `cp scripts/commit_template.sh scripts/commit_dayN.sh`
2. Edit `FILES_TO_STAGE` array with the actual paths you're committing.
3. Edit the heredoc commit message between `<<'MSG'` and `MSG`.
4. Run: `bash scripts/commit_dayN.sh`.

The script will clear any stale `.git/index.lock` (Lς), run the
pre-push gates (ruff + pytest), abort on failure, otherwise
commit + push + tail the resulting GitHub Actions runs.
