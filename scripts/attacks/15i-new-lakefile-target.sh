ATK_DESC="ADD a new library target to the lakefile that tolerates warnings (an added line passes the diff judge): check-toolchain must refuse a target it does not prove warning-fatal"
ATK_GATES=('scripts/check-toolchain.sh'); ATK_GATE_FILES=(scripts/check-toolchain.sh); ATK_LEAN=1; ATK_EXPECT='proves warnings fatal in exactly'
atk_apply() { printf 'lean_lib VbmContextExtra where\n  leanOptions := #[⟨`warningAsError, false⟩]\n' >> lakefile.lean; }
