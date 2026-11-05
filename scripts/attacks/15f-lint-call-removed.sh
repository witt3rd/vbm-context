ATK_DESC="remove the source lint's call from tier1.sh (set_option can then switch the zero-warning build off again)"
ATK_GATES=('scripts/gate-diff-improving.sh --suite-judged "$ATK_BASE" HEAD'); ATK_GATE_FILES=(scripts/gate-diff-improving.sh)
atk_apply() { sed -i '/^scripts\/lint-warning-options.sh/d' scripts/tier1.sh; }
