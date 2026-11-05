ATK_DESC="a proofs module with 'set_option warningAsError false' and a warning in it: the source lint must refuse (the proofs directory is not protected)"
ATK_GATES=('scripts/tier1.sh'); ATK_GATE_FILES=(scripts/tier1.sh); ATK_LEAN=1; ATK_EXPECT='switch the zero-warning build off'
atk_apply() { printf 'set_option warningAsError false\ndef atkWarn (x : Nat) : Nat :=\n  let y := 1\n  2\n' > VbmContextProofs/AtkWarn.lean; echo 'import VbmContextProofs.AtkWarn' >> VbmContextProofs.lean; }
