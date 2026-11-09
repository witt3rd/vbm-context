## Landing (direct to main, no PRs)
- Work in a worktree off a fresh origin/main. Diff ≤150 production lines, ≤45 min without a passing build; over either, stop and write a decomposition plan.
- Commit locally with Conventional Commits. Land only with `scripts/land-direct`; never push main yourself, never force-push it, never open a PR.
- New behaviour lands behind a flag that defaults OFF. Interface changes: add beside the old, migrate callers, delete at zero references.
- Everything runs before the push, once (Tier 1 on the rebased tree); nothing runs after it. If main is ever red, whoever sees it reverts the offending commit with `git revert` and lands the revert; the author fixes forward in a new worktree. A landing must not add a failure.
- `scripts/land/` and `scripts/land-direct` are a pinned copy of vbm-land: never edit them (`scripts/land/bin/land-check` fails the gate). Change the tool upstream, then `scripts/land/bin/land-update <tag>`.
- Decide anything reversible and log it. Escalate only money, data loss, secrets, publishing, or harm to a third party; say so in one line and stop.

## Principles (the VBM + HVTBD family)
- Everything runs before the push, once, on the commit rebased onto main. Nothing runs after the push.
- Proofs, not tests. A test exists only for what the proofs do not cover (the boundary), never for the development tooling.
- A failure is a root-cause question, never a reason to add a check, gate, script or document. Nothing is added to the process without deleting something.
- The worker owns its change: when the lander refuses it, the worker fixes it and lands again until it converges.

# AGENTS.md: vbm-context

Verified typed agent state, written once in Lean 4 and machine-checked: a typed state (goal, obligations, facts with provenance, open questions, working set) that replaces a transcript, typed patches the model writes back, and a total, deterministic, idempotent compaction. Agent-built, no human code review. **Public from day one** (no private name, host or path anywhere: `scripts/lint-public` fails Tier 1). The standard is VBM (verified bare metal); libraries are `vbm-<name>`. `README.md` is the public face (plain words, for outside readers); this file is the agent file. Design: `docs/decisions/0001-vbm-context.md` (read first).

**Scope.** Pure data and total functions over `Init`. No model call, no HTTP, no network, no prices, no model names, no tokenizer. What is proved is the state machine; that a model succeeds with it is empirical and is never claimed proved.

## Status
Slices: C1 `State`, `Patch`, `apply`, `compact`, `step` with the preservation, idempotence and size theorems (landed with the scaffold). Planned: a deterministic rendering with a stable prefix and `parse (render s) = s`; provenance validity and redaction; a per-step spend bound (prices a parameter). What has landed: `git log`. Toolchain: Lean 4.35.0 pinned in `mise.toml` and `lean-toolchain` (no elan). Run everything as `mise exec -- ...`; the gate is `mise exec -- scripts/tier1.sh`.


## Hard rules
- **Forbidden anywhere in Lean:** `sorry`, `admit`, `axiom`, `unsafe`, `implemented_by`, `csimp` (Tier 1 scans for them; a comment may mention one only on a line marked `tier1-allow`). A proof is hard? Decompose it; never weaken the statement.
- **Spec first.** Behaviour lands as a specification and its proofs. There is no vectors gate (removed: its reference was the author's own reading; to be REINSTATED as a compiled-versus-kernel differential in the slice that first ships the compiled path to a consumer, see `docs/decisions/0001-vbm-context.md`). No unproved claim called verified.
- **Ran-evidence.** A gate or test that runs zero cases fails: every test script ends with `ran: NAME: N cases` (N > 0) and every concurrent gate reports its own count (`scripts/ran-gates.txt`). A refused tool, a `SKIPPED` line or an early exit is never a pass. Every gate has a negative self-test that must be shown able to fail in the same run.
- **Nothing runs after the push.** Everything runs before it, once, in Tier 1 on the rebased tree; there is no workflow and no runner in this repository, and none is registered for it.
- **Public-ready, always.** No private name, no path of ours, no number of ours, no e-mail anywhere; write generic ("a verified agent harness"). Names are kept as hashes (`scripts/public-banned-hashes.txt`).
- **Small diffs** and Conventional Commits; TTL 45 minutes without a passing build: abort and decompose.
- **Land with `scripts/land-direct`**, never a PR, never push or force-push `main`. Any file of the repository, spec and scripts and docs and this file included, lands like any change when Tier 1 passes; no approval is needed. Only the lander's own files (`scripts/land/`) and the signing keys are read-only.
- **No secrets in the repository.** No paid model call and no network call from a test or a gate.

## Library rules
- **Module roots:** `VbmContext` imports `Init` and itself only (Tier 1 scans the imports); `VbmContextProofs` may import `Std` and `Lean` and is never linked, and nothing in `VbmContext` may import it.
- **Preservation first:** any new `Patch` or compaction rule must keep `Keeps` (`VbmContextProofs/State.lean`): the goal, each obligation (met only rises) and each pinned fact survive.

## Gates
**Tier 1** (`scripts/tier1.sh`): forbidden-constructs scan, import scan, pipefail lint, the vendored lander's drift check, zero-warning build, axiom gate, public-readiness lint, ran-evidence self-tests. It runs before every landing, on the commit rebased onto main; nothing runs after the push. If main is ever red, whoever sees it reverts the offending commit with `git revert` and lands the revert; the author fixes forward in a new worktree.

## Layout
`VbmContext/` spec and code · `VbmContextProofs/` proofs (never linked) · `docs/decisions/` design · `scripts/` gates, lints and their self-tests, `scripts/land.d/` the lander's hooks, the pinned lander.
