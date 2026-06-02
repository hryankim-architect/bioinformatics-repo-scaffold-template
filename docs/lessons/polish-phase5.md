# Polish-Phase5 lessons, scaffold-level canon

Public-form engineering judgment captured during multi-week capability-portrait
development. Each lesson follows the Symptom / Cause / Fix / Generalizing form
that maps a single bug or near-miss into a substrate pattern future repos can
inherit.

This file ships only the lessons that have been promoted to scaffold level,
i.e. those a future capability portrait inheriting from this template should
pick up automatically. Internal-only lessons (~132 total across the substrate)
remain outside the public scaffold.

Promotions to date:

| Lesson | Title | Substrate impact |
|---|---|---|
| Lχ | heredoc commit messages (no inline `-m`) | `scripts/commit_template.sh` |
| Lτ | pre-push CJK gate | `scripts/check_english_only.py` invoked from commit scripts |
| Lψ | dev-tool tolerance in commit scripts | `scripts/commit_template.sh` |
| Lω | defensive vocabulary handling against upstream public datasets | `src/bioscaffold/vocab.py` (v0.4) |
| Lσ | saturation as substrate primitive | `src/bioscaffold/saturation.py` (v0.4) |
| Lς | stale `.git/index.lock` cascade failure (ghost-shipped tag) | `scripts/commit_template.sh` (v0.5), `docs/commit-script-pattern.md` |

Lχ, Lτ, and Lς are documented in detail in `docs/commit-script-pattern.md`.
The three additions below (Lψ / Lω / Lσ) joined the canon in v0.3. Lς
joined in v0.5.

---

## Lψ, dev-tool tolerance in commit scripts (don't block on missing local installs)

### Symptom

A `commit_dayN.sh` helper runs `ruff` and `pytest` as pre-commit gates. The
user runs it from the base conda environment, which doesn't include these dev
deps. The script fails immediately with `No module named ruff` / `No module
named pytest`, blocking the commit even though the change itself is fine.

### Cause

Pre-commit shell gates treat lint and test as hard requirements. In reality,
they are *redundant* with the CI workflows that run remotely on every push.
The CI environment is the canonical lint / test gate; the local pre-commit
runs are an *optimization* (catch issues without burning a CI round-trip),
not a *requirement*.

When the local environment lacks the tool, the gate's correct behavior is to
emit a notice and proceed, CI will still catch any actual problem.

### Fix

Probe for each dev tool before invoking it, and fall through with a message
if not installed:

```bash
if python3 -c "import ruff" 2>/dev/null || command -v ruff >/dev/null 2>&1; then
  python3 -m ruff check FILES_TO_STAGE \
    || ruff check FILES_TO_STAGE \
    || { echo "ruff failed, fix before commit"; exit 1; }
else
  echo "  (ruff not installed locally, CI will run it remotely)"
fi

if python3 -c "import pytest" 2>/dev/null; then
  PYTHONPATH=src python3 -m pytest -q || { echo "pytest failed"; exit 1; }
else
  echo "  (pytest not installed locally, CI will run the test suite remotely)"
fi
```

Note that `set -e` still aborts on actual failures from installed tools,
this pattern only changes the behavior for *missing* tools, not failing
ones.

### Generalizing

For any CI-canonical gate, the corresponding client-side gate should be
*best-effort*: probe first, run if available, gracefully skip otherwise.
The exception is gates that have no CI equivalent (e.g. local secret
scanning), those should remain hard requirements.

This pattern is baked into `scripts/commit_template.sh` in v0.2.

---

## Lω, defensive vocabulary handling against upstream public datasets

### Symptom

Day-3 cohort selection script raises `KeyError: 'group'` on a line that
should not normally fail. Traceback shows that `build_cohort()` returned
an empty DataFrame because the inner row-filter never matched any row.
The error surfaces a hundred lines downstream of the actual problem, with
no informative message about *why* the filter produced zero rows.

### Cause

The filter compared a clinical column (e.g. PAM50 subtype) against a
hardcoded vocabulary (`{"LumA", "LumB", "Basal"}`). The upstream dataset's
matching column used different value strings (`"Luminal A"`, `"Luminal B"`,
`"Basal-like"`), so no row matched. Empty filter → empty rows list → empty
DataFrame with no columns → KeyError on `cohort["group"]`.

Two failure modes combined:

1. Hardcoded vocabulary diverged from the upstream's actual value strings.
2. The downstream summary code assumed at least one row would match.

### Fix

Two patterns, both required:

**1. Primary + fallback columns when vocabularies disagree across datasets.**

```python
PAM50_LONG_TO_SHORT = {
    "Luminal A": "LumA",
    "Luminal B": "LumB",
    "Basal-like": "Basal",
    ...
}

def normalize_pam50(row):
    # Try the short-form column first.
    short = str(row.get("PAM50Call_RNAseq", "")).strip()
    if short and short.lower() != "nan":
        return short
    # Fall back to the long-form column, normalized.
    long_form = str(row.get("PAM50_mRNA_nature2012", "")).strip()
    return PAM50_LONG_TO_SHORT.get(long_form, "")
```

**2. Fail loudly when no rows match, with a diagnostic message that points
   at the likely cause.**

```python
if cohort.empty:
    raise ValueError(
        f"No patients matched {label_a} or {label_b} criteria. "
        "Check PAM50/ER/PR/HER2 column values in clinical matrix — "
        "did the upstream dataset change the value vocabulary?"
    )
```

Empty-result errors that surface only as KeyError ten frames downstream
waste 5–30 minutes per occurrence to track back to the actual cause.

### Generalizing

When a pipeline filters against an *external* vocabulary (TCGA / GDC / Xena /
ENCODE / Ensembl / any upstream public dataset), assume the vocabulary may
drift or differ across mirrors. Always:

- Code a primary + fallback column / vocabulary path.
- `raise ValueError(...)` on empty filter results with a message pointing at
  the upstream column likely to be wrong.
- Surface the unmatched rows count in logs/audit MD so quiet drift is
  visible later.

This applies equally to gene symbol overlaps, sample-ID conventions
(TCGA short-id vs Xena sample-id formats), file-format header drift, etc.
The substrate's audit ledger already records the unmatched-row count in
the cohort_summary.md template, that's the visible-drift mechanism.

---

## Lσ, saturation as substrate primitive

### Symptom

Day-4 baseline reports AUROC = 1.000 ± 0.000 across every (feature_set,
model) combination. The audit MD's normal "Scope" section reads
as if this is a healthy result. Recruiter / reviewer takes it at face
value. The PI takes a second look and realizes the task is too easy.

### Cause

`AUROC = 1.0` is structurally ambiguous: it means either *perfect
classifier* OR *task is too easy / has data leakage / label is derivable
from features by construction*. The latter is far more common in
discrimination tasks where the label was originally *derived from one
of the input modalities* (e.g. PAM50 labels derived from RNA-seq, then
RNA-seq used as features).

A baseline pipeline that reports saturation without flagging it lets
the result slip past quality control and produces a misleading audit
trail.

### Fix

Detect saturation in the baseline driver and emit a different audit-MD
section when it triggers:

```python
auc_means = [stats["auc_mean"] for stats in agg.values()]
is_saturated = all(a >= 0.99 for a in auc_means)
if is_saturated:
    honest_scope = (
        "## Saturation finding\n\n"
        "Every (feature_set, model) combination hits AUROC >= 0.99 in 5-fold CV.\n"
        "This is **not** a successful baseline, it means the task is too easy:\n"
        "- Was the label derived from one of the input modalities?\n"
        "- Are the two classes biologically very distinct cell types?\n"
        "- Without baseline headroom, the next-step model cannot demonstrate value.\n\n"
        "**Next step**: re-scope to a harder discrimination target on the\n"
        "same cohort.\n"
    )
else:
    honest_scope = (
        "## Scope\n\n"
        "Simple sklearn baselines on the dual-modality cohort. The point is to\n"
        "record a non-trivial comparison anchor before the next-step model runs\n"
        "against the same cohort + same CV folds.\n"
    )
```

The audit MD now contains a structurally-different section under saturation
that explicitly says "this is a negative finding" and points at the
re-scope decision. Future readers cannot mistake it for a healthy result.

### Generalizing

For any pipeline output that has a *too-good-to-be-true* edge case (perfect
AUROC, perfect F1, zero variance, deterministic ranking), the pipeline
itself should detect that case and emit a structurally-different audit
section. Saturation detection is a substrate primitive, not a per-project
nuance.

Other substrate primitives in the same category:

- *Class imbalance >= 99%*: model predicts majority class always.
- *MAE = 0.0*: integer regression target predicted by integer feature.
- *Single feature explains 100% variance*: probably an ID column leaked.

The v0.3 scaffold documents the pattern. v0.4 plans to ship a reusable
`src/scaffold/saturation.py` helper with `check_saturation()` returning
a `SaturationReport` dataclass, plus suggested re-scope alternatives.

---

## Lesson promotion process

A lesson moves from internal capture to scaffold-level promotion when **all
three** are true:

1. It has been re-encountered in **at least two** capability-portrait sprints
   (one occurrence is "an interesting bug"; two is "a pattern").
2. The fix has a substrate-level expression, a shared script, doc, or
   helper module, not just a per-project code change.
3. The fix has been **field-tested on at least one CI-green commit cycle**
   in a downstream capability portrait, so the migration path is known.

Lψ, Lω, Lσ all cleared this bar during the DMOI POC Week-1 sprint
(2026-05-26 → 2026-05-27), which is why they ship in v0.3.
