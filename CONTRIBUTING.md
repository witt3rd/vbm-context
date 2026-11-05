# Contributing

vbm-context is built by agents under mechanical gates, and it lands directly on `main` with `scripts/land-direct` (no pull requests: the maintainers' agents use the pinned [vbm-land](https://github.com/witt3rd/vbm-land) lander). Outside contributions are welcome as an **issue** first: a counterexample to a claim, a missing guarantee you need, a gate that can be fooled. Pull requests from forks are not merged as such; a maintainer may land an equivalent change.

## Rules a change must meet

- `mise exec -- scripts/tier1.sh` passes (Lean 4.35.0, pinned in `mise.toml`). It runs offline after the first toolchain fetch.
- No `sorry`, `admit`, `axiom`, `unsafe`, `implemented_by` or `csimp` in Lean; `VbmContext/` imports `Init` and itself only. A proof is hard? Decompose it; never weaken the statement.
- Every gate has a negative self-test and prints ran-evidence (`ran: NAME: N cases`, N > 0); a gate that ran nothing fails.
- Small diffs: at most 150 production lines under `VbmContext/` per change. Conventional Commits (`type(scope): summary`).
- No private name, no personal path, no secret, no network call from a test. CI runs on GitHub-hosted runners only: a workflow that names a self-hosted runner, `pull_request_target` or a secret fails the lint.
- `scripts/land/` is a pinned copy of vbm-land: never edit it.

By contributing you agree your contribution is licensed under Apache-2.0.
