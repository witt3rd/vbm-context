ATK_DESC="narrow an entry (.github/workflows/ to one file) in scripts/protected-paths.txt"
ATK_GATES=('scripts/gate-diff-improving.sh --suite-judged "$ATK_BASE" HEAD'); ATK_GATE_FILES=(scripts/gate-diff-improving.sh)
atk_apply() { sed -i 's|^\.github/workflows/$|.github/workflows/ci.yml|' scripts/protected-paths.txt; }
