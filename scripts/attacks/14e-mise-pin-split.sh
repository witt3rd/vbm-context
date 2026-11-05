ATK_DESC="change only the Lean version in mise.toml (the pins split: the build would run a compiler other than the one named)"
ATK_GATES=('scripts/check-toolchain.sh'); ATK_GATE_FILES=(scripts/check-toolchain.sh); ATK_LEAN=1; ATK_EXPECT='toolchain pin is split'
atk_apply() { sed -i 's/4\.35\.0/4.34.0/' mise.toml; }
