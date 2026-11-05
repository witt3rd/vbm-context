#!/usr/bin/env bash
# Lint: no Lean source file may switch the zero-warning build off from INSIDE the source. `set_option warningAsError false` (or any `set_option`, e.g. `linter.* false`, which downgrades or silences a diagnostic) in a module makes
# `lake build` pass on a warning there, whatever the lakefile says; code that runs while the file is elaborated (`run_cmd`, `elab`, `macro`, `syntax`, `initialize`, ...) can set options programmatically, and `#exit` stops the file
# so what follows is never checked. Every .lean file of the repository (the library, the proofs, the vector checker, the umbrella files, the lakefile and the gate scripts; not .lake) is scanned. A comment may mention a banned word
# only on a line marked `tier1-allow` (the same marker as the forbidden-constructs scan). Prints the targets scanned and `ran: warning-options: N cases` (N = files scanned, which must be > 0).
#   scripts/lint-warning-options.sh [ROOT]     exit 0 clean; exit 1 prints each finding as path:line: text. (ROOT defaults to the repository; the self-test gives it fixture trees.)
set -euo pipefail
export LC_ALL=C
root=$(cd "${1:-$(dirname "$0")/..}" && pwd)
cd "$root"
mapfile -t files < <(find . -name '*.lean' -not -path './.lake/*' -not -path './.git/*' | sed 's|^\./||' | sort)
[ "${#files[@]}" -gt 0 ] || { echo "lint-warning-options: no .lean file under $root: nothing was scanned (a lint that scans nothing is not a pass)" >&2; exit 1; }
banned='(^|[^A-Za-z0-9_.'"'"'])(set_option|run_cmd|run_elab|run_meta|elab|elab_rules|macro|macro_rules|syntax|declare_syntax_cat|initialize|builtin_initialize)($|[^A-Za-z0-9_'"'"'])|#exit'
hits=$(grep -HnE -- "$banned" "${files[@]}" | grep -v 'tier1-allow' || true)
if [ -n "$hits" ]; then
  echo "lint-warning-options: a source file can switch the zero-warning build off or run code while it is elaborated (set_option, run_cmd, elab, macro, syntax, initialize, #exit):" >&2
  echo "$hits" >&2; exit 1
fi
targets=$(printf '%s\n' "${files[@]}" | awk -F/ '{ t = (NF > 1) ? $1 : $1; if (t !~ /\.lean$/ || NF > 1) sub(/\.lean$/, "", t); c[t]++ } END { for (t in c) printf "%s(%d) ", t, c[t] }' | tr ' ' '\n' | sort | tr '\n' ' ')
echo "lint-warning-options: scanned ${#files[@]} Lean files, no set_option, run_cmd, elab, macro, syntax, initialize or #exit: ${targets% }"
echo "ran: warning-options: ${#files[@]} cases"
