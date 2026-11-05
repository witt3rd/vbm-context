#!/usr/bin/env bash
# Tier 1: scripts/gate-diff-improving.sh can fail. In a scratch repo seeded with the real gate files, each mutation of the head is judged against the base: a removed, changed, weakened or masked tier1 line, a changed list,
# a changed gate source and a numeric baseline that appears FAIL (exit 1, naming the line); an added tier1 test line passes (exit 0); an unrelated file is not judged.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib-ran.sh   # ran_case counts each executed check, ran_done prints the evidence line `ran: NAME: N cases` (docs/decisions/0002-ran-evidence.md)
[ "$(bash -c '. scripts/git-hermetic.sh; echo loaded')" = loaded ] && ran_case || { echo "tier1: scripts/git-hermetic.sh does not load (a stub that exits?)" >&2; exit 1; }
. scripts/git-hermetic.sh   # hermetic git: no ambient config, explicit identity and branch
root=$(pwd); gate=$root/scripts/gate-diff-improving.sh
fail() { echo "tier1: gate-diff-improving: $*" >&2; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
git init -q -b main "$T/r"; cd "$T/r"; git config user.email t@t; git config user.name t; git config core.hooksPath /dev/null
mkdir -p scripts docs
files="scripts/tier1.sh scripts/protected-paths.txt scripts/ran-gates.txt scripts/public-banned-hashes.txt scripts/AxiomGate.lean scripts/land-direct scripts/protected-set.sh"
for f in $files; do cp "$root/$f" "$f"; done
echo unrelated > docs/other.md
git add -A; git commit -qm base; base=$(git rev-parse HEAD)
# mut <name> <expected: pass|fail> <needle expected in the output> <command that mutates the tree>
mut() {
  local name=$1 want=$2 needle=$3; shift 3
  "$@"; git add -A; git commit -qm "$name" --allow-empty
  out=$("$gate" ${GDI_FLAGS:-} "$base" HEAD 2>&1) && rc=0 || rc=$?
  if [ "$want" = pass ]; then [ "$rc" = 0 ] && grep -qx PASS <<<"$out" && ran_case || fail "$name: an improving change was refused ($out)"
  else [ "$rc" = 1 ] && grep -qx FAIL <<<"$out" && ran_case || fail "$name: expected FAIL, got rc=$rc ($out)"; fi
  if [ -n "$needle" ] && ! grep -qF -- "$needle" <<<"$out"; then fail "$name: '$needle' not in the output ($out)"; fi
  git reset -q --hard "$base"
}
num() { sed -i -E "$1" "$2"; }
mut "no change"                 pass ""                       true
mut "unrelated file"            pass ""                       eval 'echo x >> docs/other.md'
mut "tier1 line added"          pass "only added lines"       eval 'sed -i "/^scripts\/lint-pipefail.sh/a par scripts\/test_new.sh" scripts/tier1.sh'
mut "tier1 line removed"        fail "removed/changed"        eval 'sed -i "/^scripts\/lint-pipefail.sh/d" scripts/tier1.sh'
mut "tier1 line removed, approved"  pass "approved edit"   eval 'sed -i "/^scripts\/lint-pipefail.sh/d" scripts/tier1.sh; echo "scripts/tier1.sh 0000" > "$T/approved"; export GDI_APPROVED_FILE=$T/approved'
unset GDI_APPROVED_FILE
mut "tier1 mask added, approved"    fail "weakening"   eval 'sed -i "/^scripts\/lint-pipefail.sh/a exit 0" scripts/tier1.sh; echo "scripts/tier1.sh 0000" > "$T/approved"; export GDI_APPROVED_FILE=$T/approved'
unset GDI_APPROVED_FILE
mut "tier1 other file approved"     fail "removed/changed" eval 'sed -i "/^scripts\/lint-pipefail.sh/d" scripts/tier1.sh; echo "scripts/ran-gates.txt 0000" > "$T/approved"; export GDI_APPROVED_FILE=$T/approved'
unset GDI_APPROVED_FILE
mut "tier1 line changed"        fail "removed/changed"        eval 'sed -i "s/^scripts\/lint-pipefail.sh/scripts\/lint-pipefail.sh x/" scripts/tier1.sh'
mut "tier1 || true added"       fail "weakening"              eval 'sed -i "/^scripts\/lint-pipefail.sh/a scripts/test_new.sh || true" scripts/tier1.sh'
mut "tier1 exit 0 added"        fail "weakening"              eval 'sed -i "/^scripts\/lint-pipefail.sh/a exit 0" scripts/tier1.sh'
mut "tier1 joined line"         fail "joins"                  eval 'sed -i "/^scripts\/lint-pipefail.sh/i echo x \\\\" scripts/tier1.sh'
for f in scripts/protected-paths.txt scripts/ran-gates.txt scripts/public-banned-hashes.txt scripts/protected-set.sh; do
  mut "list $f changed"         fail "$f"                     eval "echo '# x' >> $f"
done
for f in scripts/AxiomGate.lean scripts/land-direct; do
  mut "gate source $f changed"  fail "$f"                     eval "echo '# x' >> $f"
done
mut "a gate source added"       fail "scripts/lint-public" eval 'echo x > scripts/lint-public'
# --suite-judged (what scripts/land-direct runs): lists and gate source are judged by the relabel-attack suite, not refused outright; everything else is judged as before
export GDI_FLAGS=--suite-judged
mut "suite: a list changed"             pass "judged by the relabel-attack suite" eval "echo '# x' >> scripts/ran-gates.txt"
mut "suite: gate source changed"        pass "judged by the relabel-attack suite" eval "echo '# x' >> scripts/AxiomGate.lean"
mut "suite: protected entry dropped"    fail "drops protection" eval "sed -i '/^\\.github\\/workflows\\/\$/d' scripts/protected-paths.txt"
mut "suite: protected entry narrowed"   fail "drops protection" eval "sed -i 's|^\\.github/workflows/\$|.github/workflows/ci.yml|' scripts/protected-paths.txt"
mut "suite: protected entry added"      pass "still protected" eval "echo newdir/ >> scripts/protected-paths.txt"
mut "suite: tier1 guard added"          pass "only added lines" eval "sed -i '/^scripts\/lint-pipefail.sh/a [ -n \"\$x\" ] || { echo \"tier1: x\" >\&2; exit 1; }' scripts/tier1.sh"
tier1_add() { printf '%s\n' "$1" > l.tmp; sed -i '/^scripts\/lint-pipefail.sh/r l.tmp' scripts/tier1.sh; rm -f l.tmp; }
for bad in '! scripts/test_new.sh' 'scripts/test_new.sh && :' 'scripts/test_new.sh &' 'set +o errexit' ': $(scripts/test_new.sh)' 'if scripts/test_new.sh; then :; fi' "trap 'exit 0' EXIT"; do
  mut "suite: tier1 mask $bad"          fail "not a plain step"  tier1_add "$bad"
done
unset GDI_FLAGS
# A pathological long added line is judged in linear time (a nested-quantifier regex once ran 47 minutes on one and held the land lock): each shape FAILs as "not a plain step", fast, under a 20 s GDI_TIMEOUT.
for shape in "$(printf 'a%.0s' $(seq 1 6000))!" "$(printf '$a%.0s' $(seq 1 3000))!" "$(printf 'ab=1 %.0s' $(seq 1 1500))!" "$(printf '"x" %.0s' $(seq 1 1500))!"; do
  GDI_TIMEOUT=20 GDI_FLAGS=--suite-judged mut "long line ${shape:0:12}..." fail "not a plain step" tier1_add "$shape"
done
# the bound itself: a judge that never finishes is killed and reported (exit 2, a clear line), not waited for
mkdir -p "$T/slow"; printf '#!/bin/sh\nexec sleep 60\n' > "$T/slow/python3"; chmod +x "$T/slow/python3"
git reset -q --hard "$base"; echo x >> docs/other.md; git add -A; git commit -qm slow
t0=$SECONDS; out=$(PATH="$T/slow:$PATH" GDI_TIMEOUT=1 "$gate" "$base" HEAD 2>&1) && rc=0 || rc=$?
[ "$rc" = 2 ] && grep -qF "GDI_TIMEOUT=1s" <<<"$out" && [ $((SECONDS - t0)) -lt 30 ] && ran_case || fail "a never-finishing judge was not bounded (rc=$rc, $out)"
git reset -q --hard "$base"
# --touched: the lander's trigger: the gate-defining files the change touches, nothing for an unrelated one
git reset -q --hard "$base"; echo '# x' >> scripts/AxiomGate.lean; echo x >> docs/other.md; git add -A; git commit -qm touched
[ "$("$gate" --touched "$base" HEAD)" = scripts/AxiomGate.lean ] && ran_case || fail "--touched did not name exactly the gate-defining file"
git reset -q --hard "$base"; echo x >> docs/other.md; git add -A; git commit -qm untouched
[ -z "$("$gate" --touched "$base" HEAD)" ] && ran_case || fail "--touched named a file of an unrelated change"
ran_done test_gate_diff_improving
echo "gate-diff-improving: every worsening, mask, list or source change FAILS and every improvement passes: ok"
