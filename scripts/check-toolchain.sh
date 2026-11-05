#!/usr/bin/env bash
# The toolchain and build configuration gate: lean-toolchain, mise.toml and lakefile.lean are what the zero-warning build and every proof run under, so an edit of them is checked by what it DOES, not by what it says.
#   1. lean-toolchain and mise.toml pin ONE and the same Lean version (a split pin builds with a different compiler than the one that is named);
#   2. the lakefile declares no dependency (a `require` would fetch code that no lock here pins);
#   3. the lakefile's own build options make a warning FAIL the build of each of its targets (the library and the proofs): a scratch package with the repository's lakefile and a module that has a warning must fail
#      `lake build TARGET` with the warning's diagnostic, and the same package with a clean module must pass (the control: the tool really runs here). Setting the option to false, appending `moreLeanArgs`, or any other way of switching the zero-warning build off is refused by this behaviour check.
# Prints `ran: toolchain: N cases` on success (docs/decisions/0001-vbm-context.md). Usage: scripts/check-toolchain.sh [ROOT]   (ROOT defaults to the repository; the self-test gives it fixture trees).
set -euo pipefail
root=$(cd "${1:-$(dirname "$0")/..}" && pwd)
bad() { echo "check-toolchain: $*" >&2; exit 1; }
n=0
tc=$(cat "$root/lean-toolchain" 2>/dev/null) || bad "lean-toolchain is missing"
[[ "$tc" =~ ^leanprover/lean4:v([0-9]+\.[0-9]+\.[0-9]+)$ ]] || bad "lean-toolchain is not a single pinned release (leanprover/lean4:vX.Y.Z): $tc"
ver=${BASH_REMATCH[1]}
grep -qxF "\"github:leanprover/lean4\" = \"$ver\"" "$root/mise.toml" 2>/dev/null || bad "mise.toml does not pin the Lean version of lean-toolchain ($ver) exactly: the toolchain pin is split"
n=$((n + 2))
[ -f "$root/lakefile.lean" ] || bad "lakefile.lean is missing"
if grep -qE '^[[:space:]]*require[[:space:]]' "$root/lakefile.lean"; then bad "lakefile.lean declares a dependency (require): none is allowed without a pinned lock"; fi
n=$((n + 1))
# the targets this check proves warning-fatal are EXACTLY the targets the lakefile declares: a new library or executable (or any other kind of target) that the check does not know fails here, so it cannot dodge the behaviour check below
targets="VbmContext VbmContextProofs"
declared=$(sed -nE 's/^(lean_lib|lean_exe)[[:space:]]+([^[:space:]]+).*/\2/p' "$root/lakefile.lean" | sed 's/«//g; s/»//g' | LC_ALL=C sort | tr '\n' ' ')
want=$(printf '%s\n' $targets | LC_ALL=C sort | tr '\n' ' ')
[ "$declared" = "$want" ] || bad "the lakefile declares the targets [${declared% }], but this check proves warnings fatal in exactly [${want% }]: extend scripts/check-toolchain.sh with the new target"
if grep -qE '^[[:space:]]*(target|extern_lib|input_file|input_dir|module_facet|package_facet|library_facet|lean_lib_facet)[[:space:]]' "$root/lakefile.lean"; then bad "the lakefile declares a target of a kind this check cannot build in a scratch package (target, extern_lib, input_file, ...): extend scripts/check-toolchain.sh first"; fi
t=$(mktemp -d "${TMPDIR:-/tmp}/check-toolchain.XXXXXX"); trap 'rm -rf "$t"' EXIT
cp "$root/lakefile.lean" "$root/lean-toolchain" "$t/"; mkdir "$t/VbmContext" "$t/VbmContextProofs"
echo "import VbmContext.Warn" > "$t/VbmContext.lean"; echo "import VbmContextProofs.Warn" > "$t/VbmContextProofs.lean"
body() { if [ "$1" = warn ]; then printf 'def f (x : Nat) : Nat :=\n  let y := 1\n  2\n'; else printf 'def f (x : Nat) : Nat := x\n'; fi; }
put() { body "$1" > "$t/VbmContext/Warn.lean"; body "$1" > "$t/VbmContextProofs/Warn.lean"; }
# every build target of the lakefile (the library and the proofs) has its own options: each one is checked on its own
for target in $targets; do
  put warn; rc=0; out=$(cd "$t" && lake build "$target" 2>&1) || rc=$?
  [ "$rc" != 0 ] || bad "a module with a warning BUILDS in the target $target under this lakefile: the zero-warning build is switched off for it"
  grep -q 'not explicitly referenced' <<<"$out" || bad "the module with a warning failed to build in the target $target (exit $rc), but not because of the warning, so the tool may never have run here: $(head -c 300 <<<"$out")"
  put clean; out=$(cd "$t" && lake build "$target" 2>&1) || bad "a clean module does not build in the target $target under this lakefile (the control): $(head -c 300 <<<"$out")"
  n=$((n + 2))
done
echo "check-toolchain: one Lean version ($ver) in lean-toolchain and mise.toml, no dependency, and warnings are fatal in every target of the lakefile, proved by a build in each: $targets"
echo "ran: toolchain: $n cases"
