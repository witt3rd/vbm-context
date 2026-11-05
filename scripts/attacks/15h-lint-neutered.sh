ATK_DESC="neuter scripts/lint-warning-options.sh (a stub that always succeeds): its self-test scripts/test_lint_warning_options.sh must FAIL (a lint whose self-test cannot fail)"
ATK_GATES=('scripts/test_lint_warning_options.sh'); ATK_GATE_FILES=(scripts/test_lint_warning_options.sh)
atk_apply() { neuter scripts/lint-warning-options.sh; }
