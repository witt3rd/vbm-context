ATK_DESC="bump the Lean version consistently in lean-toolchain AND mise.toml (the pins agree, so check-toolchain passes; the diff judge must refuse the changed lines)"
ATK_GATES=('scripts/gate-diff-improving.sh --suite-judged "$ATK_BASE" HEAD'); ATK_GATE_FILES=(scripts/gate-diff-improving.sh)
atk_apply() { sed -i 's/4\.35\.0/4.34.0/' lean-toolchain mise.toml; }
