ATK_DESC="keep the toolchain pin but make it a moving release (lean-toolchain: a nightly instead of one release): the judge refuses the changed line, and check-toolchain refuses the form"
ATK_GATES=('scripts/check-toolchain.sh'); ATK_GATE_FILES=(scripts/check-toolchain.sh); ATK_LEAN=1; ATK_EXPECT='not a single pinned release'
atk_apply() { echo 'leanprover/lean4:nightly' > lean-toolchain; }
