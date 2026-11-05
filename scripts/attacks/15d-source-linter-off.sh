ATK_DESC="'set_option linter.unusedVariables false in' (a linter silenced, so the warning is never raised) in a library module: the source lint must refuse any set_option"
ATK_GATES=('scripts/tier1.sh'); ATK_GATE_FILES=(scripts/tier1.sh); ATK_LEAN=1; ATK_EXPECT='switch the zero-warning build off'
atk_apply() { printf 'set_option linter.unusedVariables false in\ndef atkWarn (x : Nat) : Nat :=\n  let y := 1\n  2\n' > VbmContext/AtkWarn.lean; echo 'import VbmContext.AtkWarn' >> VbmContext.lean; }
