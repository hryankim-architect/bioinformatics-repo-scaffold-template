# Architecture

This template imposes a small, deliberate architecture. Every repo derived
from the scaffold has the same shape, so a reviewer can orient themselves in
under a minute. Repos may adapt this document to reflect their own project
structure.

## Entry point

`make run` (or `scripts/run_lab.sh` on a lab node) calls
`bioscaffold.pipeline.run_pipeline`. That function runs three things in
parallel: the audit emit, the MLflow tracking context, and the project body.
When the body finishes, it writes an artifact JSON and posts metrics.

## Substrate contract

The scaffold connects to a shared substrate through three loosely-coupled
channels. Each channel degrades silently to a no-op when the substrate is
absent, so `make run` succeeds on a laptop with no external services.

| Channel | Module | Env var | Substrate endpoint |
|---|---|---|---|
| Audit | `bioscaffold.audit` | `AUDIT_HOST` | `http://${AUDIT_HOST}/events` |
| Tracking | `bioscaffold.tracking` | `MLFLOW_TRACKING_URI` | configurable |
| Canary | `bioscaffold.canary` | `BIOSCAFFOLD_CANARY_FIXTURE` | invoked by `lab_semantic_check.py` |

When `AUDIT_HOST` is unset, audit entries are written only to the local
NDJSON file. When `MLFLOW_TRACKING_URI` is unset, the tracking wrapper runs
but records nothing remotely. The canary reads a local fixture file;
`BIOSCAFFOLD_CANARY_FIXTURE` overrides the default path.

## Audit channel: hash-chained NDJSON

Each audit entry carries a `prev_hash` field set to the SHA-256 of the
canonical (sorted keys, controlled separators) JSON of the previous entry.
Modifying any entry in the chain invalidates the hash of every entry that
follows. `audit.verify()` walks the chain and returns `(ok, n_entries,
first_bad_ts)`.

On reference hardware this runs at roughly 6.19 µs per entry up to 10 000
entries, with a full-chain tamper-detect taking around 6 ms. Derived repos
rarely need that scale; they inherit the format so any compatible verifier
(such as `gatk_audit.py`) can validate entries from any repo using this
scaffold.

## Tracking channel: MLflow wrapper

The MLflow wrapper serves three purposes:

1. Parameters and metrics are version-controlled alongside the run, making
   the demo reproducible.
2. All repos posting to the same MLflow server lets a reviewer compare runs
   across projects without custom tooling.
3. The no-op fallback means `make run` works without an MLflow server, so
   cloning the repo on a plain laptop is enough to run the demo.

## Canary channel: deterministic daily probe

`lab_semantic_check.py` calls the canary daily. The canary contract is:

- Input is fixture-driven and fully deterministic.
- Completes in under 30 seconds.
- Exits 0 on success, non-zero on any deviation.
- Requires no external services.

A daily-green canary across all repos using this scaffold gives
substrate-level monitoring without each project needing its own alerting.

## What this architecture intentionally omits

- No microservices.
- No async runtime.
- No process supervisor.
- No container per pipeline (single Python process).
- No built-in data-validation framework; add Pydantic models per project if needed.
- No DAG engine; tools like Nextflow or Airflow belong inside the project
  body when a specific project needs them, not in the scaffold.

The scaffold is the contract. The implementation is up to each derived repo.
