ATK_DESC="change the Lean version in lean-toolchain (a version bump or a downgrade is a changed line: refused by the diff judge unless an exact-diff approval was consumed)"
ATK_GATES=('scripts/gate-diff-improving.sh --suite-judged "$ATK_BASE" HEAD'); ATK_GATE_FILES=(scripts/gate-diff-improving.sh)
atk_apply() { echo 'leanprover/lean4:v4.34.0' > lean-toolchain; }
