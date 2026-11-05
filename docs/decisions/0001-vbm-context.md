# 0001: vbm-context, verified typed agent state

## 1. What and why
An agent that carries a growing transcript pays for it every step and can lose its task inside it. This library specifies the alternative as data and total functions: a **typed state** (the goal verbatim, the done-when obligations, facts with provenance, open questions, a working set of handles into the journal) that replaces the transcript; **typed patches** the model writes back instead of a whole new state; a **total, deterministic, idempotent compaction** that bounds the size and can never drop the goal, an obligation or a pinned fact.

Proved is the *machine*; whether a model succeeds with it is **empirical, never claimed proved**. What a patch means (that an obligation really is met) is the model's claim; a checker script can verify a mechanical one.

## 2. Design choices
- **Patches, not rewrites.** The model returns `List Patch`. A patch is a typed event (add a fact, meet an obligation, set the plan, ask, touch a handle); "obligation met" is an explicit, checkable event, and the output the model must write per step is small.
- **Compaction is a projection**, not a re-summary: it caps each list and keeps the protected parts, so applying it twice equals applying it once.
- **Pinned facts** are protected: a pinned fact survives compaction and a rewrite of its key stays pinned. The size bound therefore reads `4n + pinned facts`: pinning is the caller's budget decision, stated in the theorem.
- **History is retrievable, not carried.** Facts keep a `src` handle into the journal and the working set holds handles, so what compaction drops stays reachable outside the state. The journal itself is out of scope here.
- **Scope.** Pure data and functions over Lean's `Init`. No model call, no network, no prices, no model names, no tokenizer (`State.size` counts items; a byte-level size needs a rendering, a later slice).

## 3. Slices
C1 (landed with the scaffold): `State`, `Patch`, `apply`, `compact`, `step`; claims: goal, obligations and pinned facts kept by any patch list and any compaction (`step_keeps`), `compact_idem`, `compact_size`. Next, not started: the rendering with a stable prefix and `parse (render s) = s`; provenance validity and redaction; a per-step spend bound with prices as a parameter; the key-distinct invariant.

## 4. Ran-evidence (the gate rule)
A check that never ran must not pass. Every test script prints `ran: NAME: N cases` (N > 0, the checks that were evaluated and held) and every concurrent gate prints its own count (`scripts/ran-gates.txt`); `scripts/run-tests-parallel.sh` and `scripts/ran-evidence.sh` fail a script or gate that exits 0 without it, with a zero count, or with a `SKIPPED` line, and a refused tool (exit 126, 127, 124, a guard message) is never a pass. The shared negative test is `scripts/test_ran_evidence.sh`. Honest weakness: a count proves a count was printed, not that every case was meaningful.

## 5. Public from day one
The repository is public and runs on GitHub-hosted runners only: `scripts/lint-workflows.py` fails Tier 1 on a `self-hosted` runner (`.github/visibility` says `public`), on `pull_request_target` and on any secret other than the read-only default token; `scripts/lint-public` fails it on a private name or a path of ours anywhere in the tree (names are kept as hashes).
