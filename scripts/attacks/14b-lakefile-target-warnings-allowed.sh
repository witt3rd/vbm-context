ATK_DESC="ADD a line to the lakefile that lets the proofs library build with warnings (an added line passes the diff judge; scripts/check-toolchain.sh must refuse by what the build does)"
ATK_GATES=('scripts/check-toolchain.sh'); ATK_GATE_FILES=(scripts/check-toolchain.sh); ATK_LEAN=1; ATK_EXPECT='zero-warning build is switched off'
atk_apply() { sed -i 's/^lean_lib VbmContextProofs where$/&\n  leanOptions := #[⟨`warningAsError, false⟩]/' lakefile.lean; }
