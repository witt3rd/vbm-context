# vbm-context

**Verified typed agent state.** An LLM agent normally carries its whole transcript from step to step. `vbm-context` replaces the transcript with a small, typed state and proves, in Lean 4, what can and cannot happen to it.

> **Status: pre-release.** Nothing is published to a package registry; build from source. The API may still change. Today it contains the first slice: the state, the patches, and compaction.

## What it is, in plain words

The state holds what an agent needs to take its next step, and nothing it does not:

* the **goal**, verbatim and frozen;
* the **obligations**: the "done when" clauses of the task, each of which is open or met;
* **facts**, each with its provenance (which record of the journal it came from);
* **open questions** and a **plan**;
* a **working set** of handles into the journal (the full history stays outside the state, so it stays retrievable).

The model never rewrites the state. It answers each step with an action and a list of typed **patches** (add a fact, meet an obligation, set the plan, ask a question, touch a handle). A **compaction** function then keeps the state small. It is a plain function: total (defined for every state), deterministic, and idempotent (compacting twice equals compacting once).

## What it proves

* **Nothing declared is ever lost.** After any list of patches and any compaction, the goal is unchanged, every obligation is still there with the same id and text, an obligation that was met stays met, and every pinned fact is still there and still pinned (`step_keeps`, for any model whatever it writes).
* **The pin rule.** A fact is protected when it is pinned, or when an obligation that is not yet met cites its key; compaction never drops a protected fact (`compact_protected`, `compact_cited`), and once the obligation is met the fact is an ordinary one again.
* **One fact per key.** `addFact` and compaction keep the keys distinct (`apply_keysDistinct`, `compact_keysDistinct`).
* **Compaction is idempotent** (`compact_idem`) and **bounded**: each list holds at most `n` items, plus the protected facts, which the caller chose to protect (`compact_size`).
* **The primary prompt is byte-stable.** The first part of every agent's context is typed data, rendered by a pure function into six fixed segments with the version first; two different prompts never render alike (`render_injective`, so a version bump is a visible change), and the first six segments of every context of a prompt are exactly its rendering, whatever follows (`context_take`).
* **The ephemeral tail is bounded and honest.** What is true right now about the machine goes on the end of one request and is thrown away. It is configured as data (ordered named slots, a byte cap each, a total cap) and is a pure function of that configuration and a trusted view of the machine. Proved: its total size is at most the total cap (`tail_bounded`) and each piece is within its slot's cap (`tail_piece_cap`); slots keep the configured order (`tail_order`); a slot over its cap, or cut by the total cap, is named in a typed marker, never dropped silently (`tail_oversize_named`); every piece has passed the redaction hook, so if the hook yields only clean text no piece is unclean (`tail_clean`; the hook is a parameter); equal views give equal tails (`tail_of_view`).
* **The tail is never retained.** A request is the history followed by the tail (`request_take`, `request_drop`); the next history is the history plus the reply plus the observation, built by a function with no tail argument (`advance`), so a tail segment that is no reply or observation never appears in any later history (`tail_not_retained`) and the history ignores the tails entirely (`historyOf_ignores_tail`). Two full requests of the same prompt and workspace share their first segments whatever the state, observation and tail (`fullRequest_prefix_stable`), so only the tail can miss a cache.
* **The proofs are checked, not assumed:** no `sorry`, no added axiom (the axiom gate checks every constant), and every gate prints evidence that it ran at least one case.

## What it does not prove

That a model does well with this state: task success is empirical and is never claimed here. That an obligation marked met really is met (that is the model's claim). The rendering of the state into a prompt, the redaction of secrets and a spend bound are planned and not built yet. The conformance scenarios in `vectors/` are regression evidence, not proof.

## Build and test

Prerequisites: `git`, [mise](https://mise.jdx.dev), `python3` with PyYAML. `mise exec -- scripts/tier1.sh` is the gate (Lean 4.35.0, pinned in `mise.toml`): forbidden-construct scan, import rule, zero-warning build, axiom gate, the conformance scenarios, the workflow and public-readiness lints, and the self-tests of the process scripts. Every gate has a negative self-test, and a gate that ran zero cases fails. CI runs the same script on GitHub-hosted runners only.

```lean
import VbmContext
open VbmContext
-- s : State, m : Model Obs Act (the model: any function from state and observation to an action and patches)
-- let (s', a) := step m 40 s obs   -- apply the patches, then compact to at most 40 items per list
```

The proofs are in `VbmContextProofs/State.lean`; the design is in `docs/decisions/0001-vbm-context.md`.

## How it is built

Agents write it under mechanical gates instead of line-by-line review. The standard is VBM (verified bare metal), see [the VBM standard](https://github.com/witt3rd/vbm). It lands directly on `main` with `scripts/land-direct`, a pinned copy of [vbm-land](https://github.com/witt3rd/vbm-land).

## License

Apache-2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE). Security reports: [SECURITY.md](SECURITY.md). Contributing: [CONTRIBUTING.md](CONTRIBUTING.md).
