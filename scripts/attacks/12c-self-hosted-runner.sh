ATK_DESC="run the CI gate job on a self-hosted runner (the workflow lint must refuse it: the repository is public)"
ATK_GATES=('scripts/tier1.sh'); ATK_GATE_FILES=(scripts/tier1.sh); ATK_LEAN=1; ATK_EXPECT='self-hosted'
atk_apply() { sed -i '0,/runs-on: ubuntu-latest/s//runs-on: [self-hosted, linux]/' .github/workflows/ci.yml; }
