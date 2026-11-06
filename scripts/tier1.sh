#!/usr/bin/env bash
# Tier 1 (pre-landing gate): forbidden constructs, the import rule, the vendored lander's drift check, zero-warning build, the axiom gate, the workflow and public-readiness lints,
# and the offline self-tests of the process scripts. Every gate has a negative self-test and runs it here; every gate and test prints ran-evidence (a gate that ran zero cases FAILS).
# Run from the repo root: mise exec -- scripts/tier1.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
# RAN-EVIDENCE (docs/decisions/0001-vbm-context.md): every test script and every concurrent gate ends with `ran: NAME: N cases` (N > 0, or the gate's own count line named in scripts/ran-gates.txt);
# scripts/run-tests-parallel.sh and the check below FAIL a job without it, and a refused tool, a SKIPPED check or a stop by a guard is a failure, never a pass.
# A sourced library that was replaced by a stub (`exit 0`) would end this script with success: each is checked to define its function first.
[ "$(grep -c '^ran_done()' scripts/lib-ran.sh)" = 1 ] || { echo "tier1: scripts/lib-ran.sh does not define ran_done" >&2; exit 1; }
[ "$(grep -c '^must_fail()' scripts/lib-ran.sh)" = 1 ] || { echo "tier1: scripts/lib-ran.sh does not define must_fail" >&2; exit 1; }
[ "$(grep -c '^  check-dir)' scripts/ran-evidence.sh)" = 1 ] || { echo "tier1: scripts/ran-evidence.sh does not define check-dir" >&2; exit 1; }

tests=(); par() { tests+=("$@"); }   # independent test scripts, run in parallel at the end; every scripts/test_*.sh must be declared
bgdir=$(mktemp -d); bgnames=()
bg() { local n=$1; shift; bgnames+=("$n"); ( "$@" ) > "$bgdir/$n.log" 2>&1 & echo $! > "$bgdir/$n.pid"; }
bgwait() { local bad=0 n; for n in "${bgnames[@]}"; do if wait "$(cat "$bgdir/$n.pid")"; then cat "$bgdir/$n.log"; else echo "tier1: FAILED: $n" >&2; cat "$bgdir/$n.log" >&2; bad=1; fi; done; [ $bad = 0 ] || exit 1; }
lean_sources() { find VbmContext VbmContextProofs vectors -name '*.lean' 2>/dev/null; ls VbmContext.lean VbmContextProofs.lean 2>/dev/null; }

# 1. Forbidden constructs anywhere in Lean sources (AGENTS.md). A comment may mention one only on a line marked `-- tier1-allow`.
forbidden() { grep -HnE '\b(sorry|admit|axiom|unsafe|implemented_by|csimp)\b' "$@" | grep -v 'tier1-allow' || true; }
bad=$(forbidden $(lean_sources))
if [ -n "$bad" ]; then echo "tier1: forbidden construct(s):" >&2; echo "$bad" >&2; exit 1; fi
st=$(mktemp); trap 'rm -f "$st"; rm -rf "$bgdir"' EXIT
for w in sorry admit axiom unsafe implemented_by csimp; do
  echo "theorem t : True := by $w" > "$st"; [ -n "$(forbidden "$st")" ] || { echo "tier1: the forbidden-constructs scan does not flag '$w'" >&2; exit 1; }
done
echo "-- a comment that says sorry -- tier1-allow" > "$st"; [ -z "$(forbidden "$st")" ] || { echo "tier1: the tier1-allow marker is not honoured" >&2; exit 1; }
echo "-- a comment that says sorry" > "$st"; [ -n "$(forbidden "$st")" ] || { echo "tier1: an unmarked comment is not flagged" >&2; exit 1; }
echo "tier1: forbidden-constructs scan: negative self-tests ok (each forbidden word is flagged, the tier1-allow marker is honoured)"

# 1a. VbmContext/ imports Init (implicitly) and other VbmContext modules only: no Std, no Lean, no VbmContextProofs, no `prelude`.
bad_imports() { grep -HnE '^[[:space:]]*((public|meta|private)[[:space:]]+)*(import|prelude)\b' "$@" | grep -vE ':[0-9]+:import VbmContext(\.[A-Za-z0-9_]+)*[[:space:]]*$' || true; }
bad=$(bad_imports $(find VbmContext -name '*.lean') VbmContext.lean)
if [ -n "$bad" ]; then echo "tier1: VbmContext may import only VbmContext modules (Init is implicit):" >&2; echo "$bad" >&2; exit 1; fi
for imp in 'import Lean' 'import Std.Data.HashMap' 'import VbmContextProofs.State' 'prelude' 'public import Lean.Data.Json' 'import VbmContextX'; do
  printf '%s\n' "$imp" > "$st"; [ -n "$(bad_imports "$st")" ] || { echo "tier1: the import scan does not flag: $imp" >&2; exit 1; }
done
printf 'import VbmContext.State\n' > "$st"; [ -z "$(bad_imports "$st")" ] || { echo "tier1: the import scan flags an allowed import" >&2; exit 1; }
echo "tier1: import scan: negative self-tests ok (each import outside Init and VbmContext is flagged)"

scripts/lint-pipefail.sh   # a producer piped into an early-exiting consumer is flaky by construction; the lint has a negative self-test
scripts/land/bin/land-check   # the vendored lander is the pinned copy (no local patch), offline

# 2. Build, zero warnings (scripts/check-zero-warning.sh: the warning's own diagnostic is required, a clean file must pass; prints `ran: zero-warning: 3 cases`).
scripts/check-zero-warning.sh
lake build VbmContext VbmContextProofs   # once, for the gates and every test (they build nothing more)

# 2a. The axiom gate: every constant of ours depends only on propext, Classical.choice, Quot.sound (--selftest: a non-standard axiom is rejected).
bg axiom-gate lake env lean --run scripts/AxiomGate.lean --selftest
[ "$(cat .github/visibility)" = public ] || { echo "tier1: .github/visibility must say exactly public: this repository is public and never uses a self-hosted runner" >&2; exit 1; }
# 2d. The public-readiness lint: no private name, no path of ours, anywhere in the tree; it is shown able to fail.
par scripts/test_lint_public.sh
# 2e. The ran-evidence mechanism: the shared negative test (a refused, missing, skipped, silent or zero-count check FAILS).
par scripts/test_ran_evidence.sh
par scripts/test_run_parallel.sh

for f in scripts/test_*.sh; do case " ${tests[*]} " in *" $f "*) ;; *) echo "tier1: $f is not declared with par" >&2; exit 1;; esac; done
echo "tier1: ${#tests[@]} test scripts: ${tests[*]}"
bg tests scripts/run-tests-parallel.sh "${tests[@]}"
bgwait
scripts/ran-evidence.sh check-dir "$bgdir" scripts/ran-gates.txt   # every concurrent gate and the tests job ran something
echo "tier1: ok"
