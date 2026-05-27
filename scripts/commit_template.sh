#!/usr/bin/env bash
# Commit + push template for capability-portrait repos.
#
# Bakes in two Polish-Phase5 lessons:
#   * Lχ (zsh BANG_HIST):   commit messages use heredoc, never inline -m "..."
#                           with possible '!' or '$!' that zsh would expand.
#   * Lτ (pre-push gate):   client-side CJK + ruff + pytest gates before
#                           push, so we don't waste CI round-trips on
#                           catchable mistakes.
#
# How to adopt for a real day-N commit:
#   1. Copy this file to scripts/commit_dayN.sh
#   2. Update FILES_TO_STAGE and the heredoc commit message
#   3. Run: bash scripts/commit_dayN.sh
#
# The script is tolerant of missing dev deps locally (ruff, pytest) —
# CI is the canonical gate; client-side is best-effort.
set -euo pipefail
cd "$(dirname "$0")/.."

# ---------------------------------------------------------------------------
# EDIT THESE FOR YOUR COMMIT
# ---------------------------------------------------------------------------
FILES_TO_STAGE=(
  "src/<package>/<module>.py"
  "tests/test_<module>.py"
  "audit/<artifact>.md"
)
# ---------------------------------------------------------------------------

echo "=== Pre-commit checks ==="
if python3 -c "import ruff" 2>/dev/null || command -v ruff >/dev/null 2>&1; then
  python3 -m ruff check "${FILES_TO_STAGE[@]}" 2>/dev/null \
    || ruff check "${FILES_TO_STAGE[@]}" \
    || { echo "ruff failed — fix before commit"; exit 1; }
else
  echo "  (ruff not installed locally — CI will run it remotely)"
fi
if python3 -c "import pytest" 2>/dev/null; then
  PYTHONPATH=src python3 -m pytest -q || { echo "pytest failed — fix before commit"; exit 1; }
else
  echo "  (pytest not installed locally — CI will run the test suite remotely)"
fi

echo "=== Pre-push CJK gate (Lτ) ==="
# Run the scaffold's own scanner against tracked + staged files.
python3 scripts/check_english_only.py

echo "=== Staging files ==="
git add "${FILES_TO_STAGE[@]}"

echo "=== Commit (Lχ-safe heredoc) ==="
git commit -F- <<'MSG'
<short subject line — imperative mood>

<one-paragraph context: what changed, why now>

<file-by-file detail if it helps reviewers>
- src/<package>/<module>.py: what this file's change does
- tests/test_<module>.py: what's tested
- audit/<artifact>.md: what's audited

<honest-scope: what is NOT done, known caveats, future work>
MSG

echo "=== Push ==="
git push origin main

echo "=== CI status (30 sec settle) ==="
sleep 30
gh run list --branch main --limit 4 || true
