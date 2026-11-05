ATK_DESC="a library module with 'set_option warningAsError false' and a warning in it (lake build passes it, whatever the lakefile says): the source lint must refuse"
ATK_GATES=('scripts/tier1.sh'); ATK_GATE_FILES=(scripts/tier1.sh); ATK_LEAN=1; ATK_EXPECT='switch the zero-warning build off'
atk_apply() { printf 'set_option warningAsError false\ndef atkWarn (x : Nat) : Nat :=\n  let y := 1\n  2\n' > VbmContext/AtkWarn.lean; echo 'import VbmContext.AtkWarn' >> VbmContext.lean; }
