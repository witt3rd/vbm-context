# Scorecard

Status: draft by a worker, 2026-11-18; goals and targets are the owner's to set.

## Goals as the repository states them

- **G1** A small typed state (goal, obligations, facts with provenance, open questions, working set) replaces the transcript. Source: README.md:3; AGENTS.md:17; docs/decisions/0001-vbm-context.md:4.
- **G2** Scope is pure data and total functions over `Init`: no model call, network, prices, model names or tokenizer; `VbmContext` imports only itself. Source: AGENTS.md:19 and :36; docs/decisions/0001-vbm-context.md:13.
- **G3** Nothing declared is ever lost: the goal, obligations (met only rises) and pinned or cited facts survive any patches and any compaction. Source: README.md:21; AGENTS.md:37.
- **G4** Compaction is total, deterministic, idempotent and bounded (`4n` plus protected facts). Source: README.md:24; docs/decisions/0001-vbm-context.md:10-11.
- **G5** The primary prompt is byte-stable and injective; the ephemeral tail is bounded, names what it cuts, goes through a redaction hook and is never retained. Source: README.md:25-27.
- **G6** Excerpt and old-block elision cut context whatever the model window is, with fixed budgets in one module. Source: README.md:28-29; docs/decisions/0001-vbm-context.md:16.
- **G7** The proofs are checked, not assumed: no `sorry`, no added axiom, no forbidden construct, zero build warnings. Source: README.md:30; AGENTS.md:26 and :39-40.
- **G8** Every gate prints ran-evidence (N > 0) and has a negative self-test that shows it can fail. Source: AGENTS.md:28; docs/decisions/0001-vbm-context.md:21; CONTRIBUTING.md:9.
- **G9** Public from day one: no private name, path or number anywhere in the tree. Source: AGENTS.md:30; docs/decisions/0001-vbm-context.md:24.
- **G10** Small, fast changes: at most 150 production lines under `VbmContext/` and 45 minutes without a passing build. Source: AGENTS.md:31; CONTRIBUTING.md:10.
- **G11** Build the planned slices: state rendering with `parse (render s) = s`, provenance validity and redaction, a per-step spend bound (prices a parameter). Source: AGENTS.md:22; docs/decisions/0001-vbm-context.md:16; README.md:34.
- **G12** Reinstate the vectors gate as a compiled-versus-kernel differential in the slice that first ships the compiled path to a consumer. Source: AGENTS.md:27; docs/decisions/0001-vbm-context.md:18.
- **G13** Non-goal that bounds every claim: that a model succeeds with this state is empirical and never claimed proved. Source: README.md:34; docs/decisions/0001-vbm-context.md:6.
- **G14** Release state: pre-release, built from source, API may change (tag v0.1.0). Source: README.md:5; VERSION:1.

## Metrics

Every value is an integer; the unit is in the name (`-lines`, `-seconds`, `-permille`, otherwise a count). Commands run from the repository root; `mise exec --` is the repository's way to get the pinned Lean 4.35.0 (in the worker's jail `mise` could not fetch it offline, so the same commands were run with the installed 4.35.0 `bin` on `PATH`). In a command, `\|` is a pipe (escaped for the table). The floor starts equal to now and only moves toward better.

| metric | direction (higher or lower is better) | goal it serves | how to measure (the exact command, from the repository root) | now (value and date) | floor (= now) | target (blank: the owner sets it) |
|---|---|---|---|---|---|---|
| proof-ledger-gaps | lower | G3-G7 | `for n in $(grep -oP '\x60\K[A-Za-z_.]+_[A-Za-z_]+(?=\x60)' README.md \| sort -u); do grep -rqw "$n" VbmContext VbmContextProofs \|\| echo "$n"; done \| wc -l` | 0 (2026-11-18; README theorem names with no definition, of 31) | 0 | |
| readme-theorem-names | higher | G3-G6 | `grep -oP '\x60\K[A-Za-z_.]+_[A-Za-z_]+(?=\x60)' README.md \| sort -u \| wc -l` | 31 (2026-11-18) | 31 | |
| theorems | higher | G3-G6 | `grep -rhE '^\s*(private )?(theorem\|lemma)\b' VbmContextProofs VbmContext \| wc -l` | 108 (2026-11-18) | 108 | |
| forbidden-construct-hits | lower | G7 | `grep -rnwE 'sorry\|admit\|axiom\|unsafe\|implemented_by\|csimp' VbmContext VbmContextProofs VbmContext.lean VbmContextProofs.lean \| grep -vc tier1-allow \|\| true` | 0 (2026-11-18) | 0 | |
| axiom-offending-constants | lower | G7 | `mise exec -- .land/tool/bin/land-lean axiom \| grep -oE '[0-9]+ offending'` | 0 (2026-11-18; of 625 constants checked) | 0 | |
| build-warnings | lower | G7 | `rm -rf .lake; mise exec -- lake build VbmContext VbmContextProofs 2>&1 \| grep -ci warning \|\| true` | 0 (2026-11-18) | 0 | |
| recheck-failures | lower | G7 | `mise exec -- .land/tool/bin/land-lean recheck >/dev/null 2>&1; echo $?` | 0 (2026-11-18; exit status; both modules replayed ok) | 0 | |
| foreign-imports-in-core | lower | G2 | `grep -rhE '^import' VbmContext VbmContext.lean \| grep -vc '^import VbmContext' \|\| true` | 0 (2026-11-18) | 0 | |
| trust-ledger-gaps | lower | G7 | `mise exec -- .land/tool/bin/land-lean trust \| grep -oE '[0-9]+ with no written contract'` | 2 (2026-11-18; T1 and T2 have no written contract or no test) | 2 | |
| public-lint-violations | lower | G9 | `scripts/lint-public \| grep -c . \|\| true` | 0 (2026-11-18) | 0 | |
| lint-public-selftest-cases | higher | G8 | `scripts/test_lint_public.sh \| grep -oE 'ran: test_lint_public: [0-9]+'` | 8 (2026-11-18) | 8 | |
| verified-core-lines | lower | G2, G10 | `git ls-files VbmContext VbmContext.lean \| xargs cat \| wc -l` | 313 (2026-11-18) | 313 | |
| proof-to-core-permille | higher | G3-G6 | `echo $(( $(git ls-files VbmContextProofs VbmContextProofs.lean \| xargs cat \| wc -l) * 1000 / $(git ls-files VbmContext VbmContext.lean \| xargs cat \| wc -l) ))` | 2495 (2026-11-18; 781 proof lines per 313 core lines) | 2495 | |
| largest-landing-core-lines | lower | G10 | `for c in $(git rev-list HEAD -- VbmContext); do git show --numstat --format= $c -- VbmContext VbmContext.lean \| awk '{a+=$1} END{print a}'; done \| sort -n \| tail -1` | 137 (2026-11-18; the largest of the 7 commits that touch the core; limit 150) | 137 | |
| unbuilt-planned-slices | lower | G11 | `grep -o 'Next, not started:[^.]*' docs/decisions/0001-vbm-context.md \| tr ';' '\n' \| grep -c .` | 3 (2026-11-18; state rendering with parse, provenance and redaction, spend bound) | 3 | |
| differential-cases | higher | G12 | no gate exists yet; once it does, its own `ran:` line is the count | 0 (2026-11-18; no gate, by design until a compiled path ships) | 0 | |
| commits-since-release | lower | G14 (release state) | `git rev-list v0.1.0..HEAD --count` | 7 (2026-11-18; v0.1.0 of 2026-11-11; VERSION 0.1.0, pre-release) | 7 | |
| build-seconds | lower | G8, G10 | `rm -rf .lake; SECONDS=0; mise exec -- lake build VbmContext VbmContextProofs >/dev/null 2>&1; echo $SECONDS` | 3 (2026-11-18; cold, after removing .lake) | 3 | |
| recheck-seconds | lower | G7, G10 | `SECONDS=0; mise exec -- .land/tool/bin/land-lean recheck >/dev/null 2>&1; echo $SECONDS` | 71 (2026-11-18) | 71 | |
| tier1-seconds | lower | G8, G10 | `SECONDS=0; mise exec -- scripts/tier1.sh >/dev/null 2>&1; echo $SECONDS` | unmeasured (the harness runs Tier 1 and the task says not to; also `mise` cannot fetch the pinned toolchain offline here (parts measured: build 3 s + recheck 71 s)) | unmeasured | |
| model-task-success-permille | higher | G13 (empirical, never claimed proved) | none in this repository | unmeasured (needs an empirical harness with a model and tasks, outside this repository) | unmeasured | |

## Health today

- **Regressed:** nothing; every measured floor equals its first value, so there is no history yet.
- **Clean:** `proof-ledger-gaps`, `forbidden-construct-hits`, `axiom-offending-constants`, `build-warnings`, `recheck-failures`, `foreign-imports-in-core` and `public-lint-violations` are all 0; the proof side looks healthy and every README theorem name exists in the Lean sources.
- **Open gap:** `trust-ledger-gaps` is 2 (T1 the Lean toolchain and T2 the scripts' tools have no written contract or no test; the ledger says it accepts them).
- **Far from where the goals point:** `unbuilt-planned-slices` is 3 (G11: rendering with `parse (render s) = s`, provenance and redaction, spend bound), so the README itself says redaction and a spend bound are not built; `differential-cases` is 0 (G12, due only when a compiled path ships); `commits-since-release` is 7 after v0.1.0.
- **Unmeasured:** `tier1-seconds` (needs the harness or a working `mise`) and `model-task-success-permille` (needs an empirical harness; the repository never claims it).
- **Watch:** `largest-landing-core-lines` is 137 against a limit of 150, and the core is 313 lines, so one more slice of that size would fail the limit unless split. `recheck-seconds` (71) is the slowest measured part of the gate.

## What a steward would do first

1. Build the next planned slice, the state rendering with a stable prefix and `parse (render s) = s`, to lower `unbuilt-planned-slices` from 3, raise `theorems` and `readme-theorem-names`, and keep `proof-ledger-gaps` at 0.
2. Measure `tier1-seconds` in an environment where `mise` can reach the toolchain (or record it from the harness), so the gate's time has a floor and `recheck-seconds` (71) is not the only timing.
3. Close or restate the two `trust-ledger-gaps` entries (give T1 and T2 a written contract or a test, or have the owner accept them as they are), and move `commits-since-release` by cutting a release when the owner decides.

## Questions for the owner

- What is the target for each metric? All targets are blank; the repository states none.
- Which planned slice comes first (G11), and is the order rendering, provenance and redaction, then spend bound?
- Is `trust-ledger-gaps` of 2 acceptable for good (the ledger says accept), or should it fall to 0?
- When should the vectors gate return as a differential (G12): is a consumer of the compiled path planned, and when?
- How should model task success (G13) be measured, if at all, and where: a harness outside this repository?
- What is the release cadence (G14): is `commits-since-release` meant to stay low, and what ends pre-release?
- Should the proof weight (`proof-to-core-permille`, `verified-core-lines`) have a direction the owner prefers? Here higher proof per core line, and a smaller core, are assumed better.
- Should `docs/decisions/0001-vbm-context.md:21` and `AGENTS.md` still name `scripts/run-tests-parallel.sh`, `scripts/ran-evidence.sh`, `scripts/test_ran_evidence.sh` and `scripts/lint-workflows.py`? The decision names them but they do not exist (the vendored `.land/tool/bin` versions are used; no workflow exists).
