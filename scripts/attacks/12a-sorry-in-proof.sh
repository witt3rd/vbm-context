ATK_DESC="put a sorry in a proof (the forbidden-constructs scan of tier1.sh must refuse it)"
ATK_GATES=('scripts/tier1.sh'); ATK_GATE_FILES=(scripts/tier1.sh); ATK_LEAN=1; ATK_EXPECT='forbidden construct'
atk_apply() { sed -i 's/^theorem compact_goal .*/theorem compact_goal (n : Nat) (s : State) : (compact n s).goal = s.goal := by sorry/' VbmContextProofs/State.lean; }
