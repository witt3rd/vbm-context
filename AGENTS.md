## Landing (direct to main, no PRs)
- Work in a worktree off a fresh origin/main. Diff ≤150 production lines, ≤45 min without a passing build; over either, stop and write a decomposition plan.
- Commit locally with Conventional Commits. Land only with `scripts/land-direct`; never push main yourself, never force-push it, never open a PR.
- New behaviour lands behind a flag that defaults OFF. Interface changes: add beside the old, migrate callers, delete at zero references.
- Main is RED when the Tier 1 job of its latest push failed. While red or frozen, only a fix or revert lands. Never hotfix on main: pull the revert, reproduce in a new worktree, resubmit.
- `scripts/land/` and `scripts/land-direct` are a pinned copy of vbm-land: never edit them (`scripts/land/bin/land-check` fails the gate). Change the tool upstream, then `scripts/land/bin/land-update <tag>`.
- Decide anything reversible and log it. Escalate only money, data loss, secrets, publishing, or harm to a third party; say so in one line and stop.

# AGENTS.md: vbm-context

Verified typed agent state, written once in Lean 4 and machine-checked: a typed state (goal, obligations, facts with provenance, open questions, working set) that replaces a transcript, typed patches the model writes back, and a total, deterministic, idempotent compaction. Agent-built, no human code review. **Public from day one** (no private name, host or path anywhere: `scripts/lint-public` fails Tier 1). The standard is VBM (verified bare metal); libraries are `vbm-<name>`. `README.md` is the public face (plain words, for outside readers); this file is the agent file. Design: `docs/decisions/0001-vbm-context.md` (read first).

**Scope.** Pure data and total functions over `Init`. No model call, no HTTP, no network, no prices, no model names, no tokenizer. What is proved is the state machine; that a model succeeds with it is empirical and is never claimed proved.

## Status
Slices: C1 `State`, `Patch`, `apply`, `compact`, `step` with the preservation, idempotence and size theorems (landed with the scaffold). Planned: a deterministic rendering with a stable prefix and `parse (render s) = s`; provenance validity and redaction; a per-step spend bound (prices a parameter). What has landed: `git log`. Toolchain: Lean 4.35.0 pinned in `mise.toml` and `lean-toolchain` (no elan). Run everything as `mise exec -- ...`; the gate is `mise exec -- scripts/tier1.sh`.

**Follow-up (dated 2026-11-05):** put `VbmContext/` in the protected list (`scripts/protected-paths.txt`) once the library's theorem set stabilises.

## Hard rules
- **Forbidden anywhere in Lean:** `sorry`, `admit`, `axiom`, `unsafe`, `implemented_by`, `csimp` (Tier 1 scans for them; a comment may mention one only on a line marked `tier1-allow`). A proof is hard? Decompose it; never weaken the statement.
- **Spec first.** Behaviour lands as a specification and its proofs. There is no vectors gate (removed: its reference was the author's own reading; to be REINSTATED as a compiled-versus-kernel differential in the slice that first ships the compiled path to a consumer, see `docs/decisions/0001-vbm-context.md`). No unproved claim called verified.
- **Ran-evidence.** A gate or test that runs zero cases fails: every test script ends with `ran: NAME: N cases` (N > 0) and every concurrent gate reports its own count (`scripts/ran-gates.txt`). A refused tool, a `SKIPPED` line or an early exit is never a pass. Every gate has a negative self-test that must be shown able to fail in the same run.
- **Hosted CI only, never self-hosted.** The repository is public: no `self-hosted` runner, no `pull_request_target`, no secret (`scripts/lint-workflows.py`, `.github/visibility` = `public`). Never register a runner for this repository.
- **Public-ready, always.** No private name, no path of ours, no number of ours, no e-mail anywhere; write generic ("a verified agent harness"). Names are kept as hashes (`scripts/public-banned-hashes.txt`).
- **Small diffs:** at most 150 production lines under `VbmContext/` per landing (a `Diff-Budget:` trailer waives it with a decomposition note). TTL 45 minutes without a passing build: abort and decompose. Conventional Commits.
- **Land with `scripts/land-direct`**, never a PR, never push or force-push `main`. A change to a gate-defining file (`scripts/protected-paths.txt` lists them: the Tier 1 script, the lints, the lander's wiring, the workflows, the toolchain pin) needs the owner's explicit say-so before it lands, and is also judged mechanically: the diff judge after the rebase (`scripts/gate-diff-improving.sh`: Tier 1 only gains plain steps, a masked or removed line fails) and the relabel-attack suite after Tier 1 (`scripts/relabel-attacks.sh`: every attack of `scripts/attacks/` must still be refused by the proposed gates). A removed or changed line of an append-only gate file (`LAND_GATE_APPEND_ONLY`) needs an exact-diff approval already on main (`scripts/land/docs/gate-edit-approvals.md`).
- **No secrets in the repository.** No paid model call and no network call from a test or a gate.

## Library rules
- **Module roots:** `VbmContext` imports `Init` and itself only (Tier 1 scans the imports); `VbmContextProofs` may import `Std` and `Lean` and is never linked, and nothing in `VbmContext` may import it.
- **Preservation first:** any new `Patch` or compaction rule must keep `Keeps` (`VbmContextProofs/State.lean`): the goal, each obligation (met only rises) and each pinned fact survive.

## Gates
**Tier 1** (`scripts/tier1.sh`): forbidden-constructs scan, import scan, pipefail lint, the vendored lander's drift check, zero-warning build, axiom gate, workflow lint, public-readiness lint, ran-evidence self-tests. **Tier 2** (CI, on a schedule): Tier 1 again plus the lander's upstream check. Also in Tier 1: the self-tests of the protected set, the diff judge and the relabel-attack suite (each attack is refused; with its gate stubbed the suite fails). **Not ported yet** from the sibling libraries: the obligation ledger and its baseline, the trust ledger, the scorecard adapter. A test script itself is not in the judged set (an edit that guts one is for the owner to read).

## Layout
`VbmContext/` spec and code · `VbmContextProofs/` proofs (never linked) · `docs/decisions/` design · `scripts/` gates, lints and their self-tests, `scripts/land.d/` the lander's hooks, `scripts/attacks/` the relabel attacks, the pinned lander.
