#!/usr/bin/env bash
# Tier 1: scripts/check-toolchain.sh can fail. On fixture trees copied from the real lean-toolchain, mise.toml and lakefile.lean: a split Lean pin, a toolchain that is not one pinned release, a missing pin line, a dependency,
# and the zero-warning build switched off (in the package options, or in the options of any one target: the library, the proofs, the vector checker) each FAIL with the reason; a `lake` that is refused, crashes or cannot fail is not a pass;
# the real tree passes (the control). A refusal counts only when the script SAYS why (scripts/lib-ran.sh must_fail).
set -euo pipefail
export LC_ALL=C
cd "$(dirname "$0")/.."
. scripts/lib-ran.sh   # ran_case counts each executed check, ran_done prints the evidence line `ran: NAME: N cases` (docs/decisions/0001-vbm-context.md)
gate=$(pwd)/scripts/check-toolchain.sh
fail() { echo "test_check_toolchain: $*" >&2; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
out=$("$gate" 2>&1) && grep -qx 'ran: toolchain: 9 cases' <<<"$out" && ran_case || fail "the real tree does not pass, or the gate printed no evidence: $out"
fixture() { rm -rf "$T/f"; mkdir "$T/f"; cp lean-toolchain mise.toml lakefile.lean "$T/f/"; }
neg() {  # neg NAME NEEDLE: the fixture tree in $T/f must FAIL with NEEDLE in what the gate says
  must_fail "$1" "$gate" "$T/f"; grep -qF -- "$2" <<<"$MUST_FAIL_ERR" && ran_case || fail "$1: the gate failed but did not say '$2': $MUST_FAIL_ERR"
}
fixture; sed -i 's/4\.35\.0/4.34.0/' "$T/f/mise.toml"; neg "a split pin" "toolchain pin is split"
fixture; echo 'leanprover/lean4:nightly' > "$T/f/lean-toolchain"; neg "a toolchain that is not one release" "not a single pinned release"
fixture; : > "$T/f/mise.toml"; neg "a missing pin line" "toolchain pin is split"
fixture; rm "$T/f/lean-toolchain"; neg "a missing toolchain file" "lean-toolchain is missing"
fixture; echo 'require foo from git "https://example.invalid/foo.git"' >> "$T/f/lakefile.lean"; neg "a dependency" "declares a dependency"
fixture; sed -i 's/warningAsError, true/warningAsError, false/' "$T/f/lakefile.lean"; neg "warnings allowed in the package options" "switched off"
for lib in "lean_lib VbmContext where" "lean_lib VbmContextProofs where" "lean_exe «vbm-context-vectors» where"; do
  fixture; python3 - "$T/f/lakefile.lean" "$lib" <<'PY'
import sys
p, anchor = sys.argv[1:3]; t = open(p).read(); assert anchor in t
open(p, "w").write(t.replace(anchor, anchor + "\n  leanOptions := #[⟨`warningAsError, false⟩]", 1))
PY
  neg "warnings allowed in the target: $lib" "switched off for it"
done
# a lake that crashes, or that cannot fail, is not a pass (the tool must really run): stubs first on PATH
mkdir "$T/bin"; fixture
printf '#!/usr/bin/env bash\necho "segmentation fault" >&2; exit 139\n' > "$T/bin/lake"; chmod +x "$T/bin/lake"
PATH="$T/bin:$PATH" neg "a lake that crashes" "may never have run"
printf '#!/usr/bin/env bash\nexit 0\n' > "$T/bin/lake"
PATH="$T/bin:$PATH" neg "a lake that cannot fail" "switched off"
ran_done test_check_toolchain
echo "check-toolchain: a split pin, a dependency, a warning-tolerant package or target and a lake that never ran each FAIL with the reason; the real tree passes: ok"
