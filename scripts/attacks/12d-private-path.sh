ATK_DESC="write a home-directory path of ours into the README (the public-readiness lint must refuse it)"
ATK_GATES=('scripts/tier1.sh'); ATK_GATE_FILES=(scripts/tier1.sh); ATK_LEAN=1; ATK_EXPECT='a path of ours|not public-ready'
atk_apply() { printf 'see %s/someone/notes\n' /home >> README.md; }
