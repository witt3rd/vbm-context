#!/usr/bin/env bash
# Tier 1: scripts/lint-warning-options.sh can fail. On fixture trees: `set_option warningAsError false` (also the `in` form), any other set_option (a linter switched off), code that runs at elaboration (run_cmd, elab, macro, syntax,
# initialize) and `#exit` in a source file of the library, the proofs, the vector checker, an umbrella file or a NEW directory each FAIL naming path:line; a comment that mentions one fails unless marked tier1-allow; a tree with no Lean file fails
# (a lint that scanned nothing is not a pass); near-miss names and the .lake directory do not trip it; the real tree passes with its evidence line. A refusal counts only when the lint SAYS why (scripts/lib-ran.sh must_fail).
set -euo pipefail
export LC_ALL=C
cd "$(dirname "$0")/.."
. scripts/lib-ran.sh   # ran_case counts each executed check, ran_done prints the evidence line `ran: NAME: N cases` (docs/decisions/0001-vbm-context.md)
lint=$(pwd)/scripts/lint-warning-options.sh
fail() { echo "test_lint_warning_options: $*" >&2; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
out=$("$lint" 2>&1) && grep -qE '^ran: warning-options: [1-9][0-9]* cases$' <<<"$out" && grep -q 'VbmContext(' <<<"$out" && grep -q 'VbmContextProofs(' <<<"$out" && ran_case || fail "the real tree does not pass, or the lint printed no evidence naming the targets it scanned: $out"
fixture() { rm -rf "$T/f"; mkdir -p "$T/f/VbmContext" "$T/f/VbmContextProofs" "$T/f/vectors"; printf 'def f (x : Nat) : Nat := x\n' | tee "$T/f/VbmContext/A.lean" "$T/f/VbmContextProofs/B.lean" "$T/f/vectors/Main.lean" > "$T/f/VbmContext.lean"; }
fixture; "$lint" "$T/f" >/dev/null && ran_case || fail "a clean fixture tree was flagged"
neg() {  # neg NAME FILE LINE: append LINE to FILE of the fixture, the lint must FAIL naming FILE:N
  fixture; printf '%s\n' "$3" >> "$T/f/$2"; must_fail "$1" "$lint" "$T/f"; grep -qF -- "$2:2:" <<<"$MUST_FAIL_ERR" && ran_case || fail "$1: the lint failed but did not name $2:2: $MUST_FAIL_ERR"
}
neg "warningAsError false" VbmContext/A.lean "set_option warningAsError false"
neg "warningAsError false, in form" VbmContext/A.lean "set_option warningAsError false in"
neg "warningAsError false in the proofs" VbmContextProofs/B.lean "set_option warningAsError false"
neg "warningAsError false in the vector checker" vectors/Main.lean "set_option warningAsError false"
neg "warningAsError false in an umbrella file" VbmContext.lean "set_option warningAsError false"
neg "a linter switched off" VbmContext/A.lean "set_option linter.unusedVariables false"
neg "run_cmd" VbmContext/A.lean "run_cmd pure ()"
neg "elab" VbmContext/A.lean "elab \"x\" : command => pure ()"
neg "macro" VbmContext/A.lean "macro \"x\" : command => \`(def y := 1)"
neg "syntax" VbmContext/A.lean "syntax \"x\" : term"
neg "initialize" VbmContext/A.lean "initialize r : IO.Ref Nat ← IO.mkRef 0"
neg "#exit" VbmContext/A.lean "#exit"
fixture; mkdir "$T/f/Other"; echo "set_option warningAsError false" > "$T/f/Other/C.lean"; must_fail "a new directory" "$lint" "$T/f"; grep -qF "Other/C.lean:1:" <<<"$MUST_FAIL_ERR" && ran_case || fail "a new directory is not scanned: $MUST_FAIL_ERR"
neg "a comment that mentions one" VbmContext/A.lean "-- use set_option warningAsError false here"
fixture; echo "-- a comment that says set_option -- tier1-allow" >> "$T/f/VbmContext/A.lean"; "$lint" "$T/f" >/dev/null && ran_case || fail "the tier1-allow marker is not honoured"
fixture; printf 'def reset_options := 1\ndef my_elab_x := 2\ndef Foo.set_option := 3\ndef syntaxes := 4\n' >> "$T/f/VbmContext/A.lean"; "$lint" "$T/f" >/dev/null && ran_case || fail "a near-miss name was flagged"
fixture; mkdir -p "$T/f/.lake/build"; echo "set_option warningAsError false" > "$T/f/.lake/build/X.lean"; "$lint" "$T/f" >/dev/null && ran_case || fail "the .lake directory is scanned"
rm -rf "$T/e"; mkdir "$T/e"; must_fail "no Lean file at all" "$lint" "$T/e"; grep -qF "nothing was scanned" <<<"$MUST_FAIL_ERR" && ran_case || fail "an empty tree did not fail for the right reason: $MUST_FAIL_ERR"
ran_done test_lint_warning_options
echo "lint-warning-options: every in-source way of switching the warning check off or running code at elaboration FAILS naming file:line, in every directory; a tree with nothing to scan fails; the real tree passes: ok"
