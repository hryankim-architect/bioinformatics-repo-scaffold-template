# What is out of scope

This file is **required** in every repo created from the scaffold template.
The CI lint job verifies that this file exists; the PR template references
it as part of the review checklist.

## Why this file exists

A demo repo's value comes from being small and complete. The single largest
risk is the steady accumulation of "while we're here, let's also..." additions.
This file is the scope-boundary ledger. If a PR proposes something on this
list, the PR template asks the contributor to answer one question:

> Why is this still out of scope?

If the answer is good, edit this file in the same PR. If the answer is not
good, the PR does not land.

## Default out-of-scope items

(Copy and edit these into the derived repo's `what-is-out-of-scope.md`.)

- **Statistical-power claims**. The demo uses a tiny public subset; effect
  sizes and p-values are illustrative, not conclusive.
- **Full-cohort reproduction**. Adding samples beyond the manifest cap
  requires editing both `data/manifest.yaml` and the README's
  "minimum subset" claim.
- **Multi-cohort meta-analysis**. Out of scope unless this repo's capability
  *is* meta-analysis.
- **Production hardening** (HA, RBAC, multi-tenant). The substrate provides
  the foundation; this repo does not re-implement it.
- **Cost optimization for cloud deployment**. The demo runs on a single
  workstation; cloud cost is by definition out of scope.

## Per-project out-of-scope items

Replace this section in the derived repo with a list specific to that project.
Write it at v0.1 and amend it as PRs land.

Example items (replace with your own):

- Capability or analysis not relevant to this repo's stated goal.
- Scaling to production data volumes (demo uses a public subset).
- Cross-repo or cross-cohort comparisons (out of scope for a single demo).

## How to add an item

Open a PR that:

1. Adds the item to the appropriate section above.
2. Adds a one-sentence reason in italics.
3. Links to the upstream PR or issue where the item was proposed.

Adding a scoped item requires a PR. That friction is by design.
