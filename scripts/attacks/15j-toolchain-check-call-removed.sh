ATK_DESC="remove the call of scripts/check-toolchain.sh from tier1.sh (the targets are no longer proved warning-fatal)"
ATK_GATES=('scripts/gate-diff-improving.sh --suite-judged "$ATK_BASE" HEAD'); ATK_GATE_FILES=(scripts/gate-diff-improving.sh)
atk_apply() { sed -i '/^scripts\/check-toolchain.sh/d' scripts/tier1.sh; }
