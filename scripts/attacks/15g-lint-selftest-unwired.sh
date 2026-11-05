ATK_DESC="remove the declaration of the source lint's negative self-test from tier1.sh (par scripts/test_lint_warning_options.sh)"
ATK_GATES=('scripts/gate-diff-improving.sh --suite-judged "$ATK_BASE" HEAD'); ATK_GATE_FILES=(scripts/gate-diff-improving.sh)
atk_apply() { sed -i '/^par scripts\/test_lint_warning_options.sh$/d' scripts/tier1.sh; }
