# `bioinformatics-repo-scaffold-template`

![ci](https://github.com/hryankim-architect/bioinformatics-repo-scaffold-template/actions/workflows/ci.yml/badge.svg)

> **One principle, applied here.** Pick the smallest, most interpretable representation that could carry the signal; measure it against an honest baseline; report the verdict faithfully — whether the compact choice wins, ties, or loses. *That last step is why AI safety is needed: knowing a capability is real rather than a flattering benchmark.*
>
> In this repo: **representation** the shared substrate scaffold every capability repo inherits → **baseline** ad-hoc, unaudited demos → **verdict** the scaffold makes the principle *reproducible*: audit + MLflow + canary + honest-scope README by default.

> **Scaffold template for scope-bounded bioinformatics demos.**
> Click *Use this template* to start a new repo with the same shared substrate:
> NDJSON audit ledger, MLflow tracking, scope-discipline
> guardrails, and a single `make run` entry point that reproduces the demo
> end-to-end in under a couple of minutes on a standard laptop or lab node.

A house style for reproducible bioinformatics R&D.

---

## What this template gives you

A new repo created from this template ships with:

- **One-command demo**: `make run` reproduces the pipeline on a tiny public-data subset.
- **Substrate hooks**: every run emits a hash-chained NDJSON audit entry, tracks
  parameters and metrics to MLflow, and exposes a canary smoke test that the
  `lab_semantic_check.py` can probe.
- **Scope-discipline guardrails**: required `docs/what-is-out-of-scope.md`,
  CI runtime budget, and `data/manifest.yaml` cap that forces explicit friction
  when adding samples.
- **Reproducibility baseline**: pinned dependencies via `pyproject.toml`,
  containerless `uv` workflow, no external services required for the demo.
- **Scope note in README**: CI checks that the new repo's README contains
  a `## Caveats` section (or equivalent scope note). Exact wording is up
  to the repo author.

---

## The scope note (write your own, in the new repo's README)

Every repo created from this template must include a short data-scope note
near the top of its README. Describe the scope in your own words — do not
copy a fixed sentence. The goal is to tell a reader what the demo data covers
and does not cover, so each repo's note will differ.

Example phrasings (pick none of these verbatim; write one that fits your
project):

- "Public data is subsetted to chromosome 22 for demo runtime; full-cohort
  results are out of scope here."
- "Demo uses 50 TCGA samples. Findings are illustrative, not statistically
  powered."
- "This repo exercises the method on a small public cohort. Production-scale
  runs used proprietary data not included here."

Place the note in a `## Caveats` section, or inline in the opening
description — wherever it reads naturally. Vary the wording per repo so repos
do not all read identically.

CI checks that a scope note is present (looks for a `## Caveats` section or
the word "scope" in the README). It does not require any specific string.

---

## Layout

```
.
├── README.md                # This file (replaced per new repo)
├── LICENSE                  # MIT
├── Makefile                 # data | run | test | report | clean
├── pyproject.toml           # uv-managed; pinned versions
├── .github/
│   └── workflows/
│       └── ci.yml           # ruff + pytest + scope-note check + canary
├── data/
│   ├── .gitignore           # raw data never committed
│   └── manifest.yaml        # public URLs + checksums for the tiny subset
├── src/bioscaffold/
│   ├── __init__.py
│   ├── pipeline.py          # CLI entry; demonstrates audit + tracking pattern
│   ├── audit.py             # NDJSON hash-chained ledger emit
│   ├── tracking.py          # MLflow run wrapper
│   └── canary.py            # smoke test interface for lab_semantic_check.py
├── tests/
│   ├── test_pipeline.py
│   └── test_canary.py
├── notebooks/
│   └── demo.ipynb           # rendered output committed alongside .ipynb
├── docs/
│   ├── architecture.md      # substrate integration diagram
│   └── what-is-out-of-scope.md  # required scope-boundary page
└── scripts/
    └── run_lab.sh           # one-liner to execute on a lab node
```

Rename `src/bioscaffold/` to your project package name when creating the new
repo. The substrate modules (`audit.py`, `tracking.py`, `canary.py`) are
designed to be copy-and-edit, not pip-installed, so each capability repo can
diverge as needed without coordinating releases.

---

## Quickstart (in a new repo created from this template)

```bash
# 1. Install deps
uv sync

# 2. Run the demo end-to-end
make run

# 3. Run tests
make test

# 4. Produce the HTML report
make report
```

The demo prints an audit entry to `audit/local-demo.ndjson` and (if the
`AUDIT_HOST` env var is set) posts it to the substrate audit-API. MLflow runs
appear at `MLFLOW_TRACKING_URI` if configured.

---

## Substrate environment variables

The substrate hooks read these at runtime; the defaults are no-ops, so the
demo works without the substrate present:

| Var | Default | What it does |
|---|---|---|
| `AUDIT_HOST` | unset | If set, audit entries are POSTed to `http://${AUDIT_HOST}/events`. |
| `MLFLOW_TRACKING_URI` | unset | If set, MLflow runs are tracked at this URI. |
| `BIOSCAFFOLD_CANARY_FIXTURE` | `tests/fixtures/canary.json` | Path used by `canary.py` for the deterministic smoke test. |
| `BIOSCAFFOLD_RUN_NAME` | derived | Overrides the run name in audit + MLflow entries. |

On a lab node, `scripts/run_lab.sh` sets these to the lab
defaults before invoking `make run`.

---

## What this template intentionally does not do

- It does not install a package globally; each repo owns its own deps.
- It does not enforce a directory structure beyond the substrate hooks.
- It does not gate the demo on cloud credentials.
- It does not commit raw data, only manifests, checksums, and licenses.
- It does not impose a specific deconvolution / segmentation / annotation
  tool, those are project-level choices.

---

## License

MIT. See [`LICENSE`](LICENSE).
