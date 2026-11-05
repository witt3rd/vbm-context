#!/usr/bin/env bash
# The toolchain and build configuration gate: lean-toolchain, mise.toml and lakefile.lean are what the zero-warning build and every proof run under, so an edit of them is checked by what it DOES, not by what it says.
#   1. lean-toolchain and mise.toml pin ONE and the same Lean version (a split pin builds with a different compiler than the one that is named);
#   2. the lakefile declares no dependency (a `require` would fetch code that no lock here pins);
#   3. the lakefile's own build options make a warning FAIL the build of each of its targets (the library, the proofs, the vector checker): a scratch package with the repository's lakefile and a module that has a warning must fail
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
t=$(mktemp -d "${TMPDIR:-/tmp}/check-toolchain.XXXXXX"); trap 'rm -rf "$t"' EXIT
cp "$root/lakefile.lean" "$root/lean-toolchain" "$t/"; mkdir "$t/VbmContext" "$t/VbmContextProofs" "$t/vectors"
echo "import VbmContext.Warn" > "$t/VbmContext.lean"; echo "import VbmContextProofs.Warn" > "$t/VbmContextProofs.lean"
body() { if [ "$1" = warn ]; then printf 'def f (x : Nat) : Nat :=\n  let y := 1\n  2\n'; else printf 'def f (x : Nat) : Nat := x\n'; fi; }
put() { body "$1" > "$t/VbmContext/Warn.lean"; body "$1" > "$t/VbmContextProofs/Warn.lean"; { body "$1"; printf 'def main : IO Unit := pure ()\n'; } > "$t/vectors/Main.lean"; }
# every build target of the lakefile (the library, the proofs, the vector checker) has its own options: each one is checked on its own
for target in VbmContext VbmContextProofs vbm-context-vectors; do
  put warn; rc=0; out=$(cd "$t" && lake build "$target" 2>&1) || rc=$?
  [ "$rc" != 0 ] || bad "a module with a warning BUILDS in the target $target under this lakefile: the zero-warning build is switched off for it"
  grep -q 'not explicitly referenced' <<<"$out" || bad "the module with a warning failed to build in the target $target (exit $rc), but not because of the warning, so the tool may never have run here: $(head -c 300 <<<"$out")"
  put clean; out=$(cd "$t" && lake build "$target" 2>&1) || bad "a clean module does not build in the target $target under this lakefile (the control): $(head -c 300 <<<"$out")"
  n=$((n + 2))
done
echo "check-toolchain: one Lean version ($ver) in lean-toolchain and mise.toml, no dependency, and every target of the lakefile fails a build on a warning: ok"
echo "ran: toolchain: $n cases"
