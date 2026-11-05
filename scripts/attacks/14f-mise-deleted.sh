ATK_DESC="delete mise.toml (no pinned toolchain: the diff judge refuses the removed lines)"
ATK_GATES=('scripts/gate-diff-improving.sh --suite-judged "$ATK_BASE" HEAD'); ATK_GATE_FILES=(scripts/gate-diff-improving.sh)
atk_apply() { git rm -q mise.toml; }
