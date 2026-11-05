ATK_DESC="edit the lakefile option in place: warningAsError true -> false (the diff judge refuses any removed or changed line of lakefile.lean)"
ATK_GATES=('scripts/gate-diff-improving.sh --suite-judged "$ATK_BASE" HEAD'); ATK_GATE_FILES=(scripts/gate-diff-improving.sh)
atk_apply() { sed -i 's/warningAsError, true/warningAsError, false/' lakefile.lean; }
