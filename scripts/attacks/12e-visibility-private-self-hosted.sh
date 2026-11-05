ATK_DESC="flip .github/visibility to private and put the CI job on a self-hosted runner (the workflow lint then allows it: tier1.sh's own visibility guard must refuse)"
ATK_GATES=('scripts/tier1.sh'); ATK_GATE_FILES=(scripts/tier1.sh); ATK_LEAN=1; ATK_EXPECT='visibility'
atk_apply() { echo private > .github/visibility; sed -i '0,/runs-on: ubuntu-latest/s//runs-on: [self-hosted, linux]/' .github/workflows/ci.yml; }
