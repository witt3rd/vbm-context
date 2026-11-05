ATK_DESC="make compact drop the obligations (the proofs and the conformance scenarios must refuse it)"
ATK_GATES=('scripts/tier1.sh'); ATK_GATE_FILES=(scripts/tier1.sh); ATK_LEAN=1; ATK_EXPECT='build failed|differ|FAILED'
atk_apply() { sed -i 's/{ s with plan := s.plan.take n,/{ s with obligations := [], plan := s.plan.take n,/' VbmContext/State.lean; }
