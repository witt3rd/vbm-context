import VbmContext
/-! Conformance scenarios: concrete states run through the library and compared with their expected result. Regression evidence, never proof
(the proofs are in `VbmContextProofs`). `--selftest` also runs the same scenarios against a mutant compaction (one that drops the obligations)
and requires them to differ, so the checker is shown able to fail. Prints `vbm-context-vectors: N cases, D differ`. -/
open VbmContext

def fact (k : String) (src : Nat) (pinned := false) : Fact := { key := k, text := k, src, pinned }
def base : State :=
  { goal := "fix the bug", obligations := [{ id := 1, text := "tests pass", cites := ["y"] }, { id := 2, text := "no new warnings", met := true }],
    plan := ["a", "b", "c"], facts := [fact "x" 0, fact "p" 1 true, fact "y" 2, fact "z" 3], open_ := ["q1", "q2", "q3"], work := [5, 4, 3] }

/-- Each scenario: a name and whether the compaction `c` behaves as expected on it. -/
def scenarios (c : Nat → State → State) : List (String × Bool) :=
  let s := c 1 base
  let m : Model Unit Nat := ⟨fun _ _ => (7, [.addFact (fact "p" 9), .meet 1, .touch 4, .ask "q0"])⟩
  let t := step m 1 base ()
  [ ("goal kept", s.goal == base.goal),
    ("obligations kept whole", s.obligations == base.obligations),
    ("lists capped at n, newest first", s.plan == ["a"] && s.open_ == ["q1"] && s.work == [5]),
    ("the pinned fact and the fact an unmet obligation cites survive, one other fact is kept", s.facts == [fact "p" 1 true, fact "y" 2, fact "x" 0]),
    ("idempotent", c 1 s == s),
    ("n = 0 keeps only the protected facts (pinned, or cited by an unmet obligation)", (c 0 base).facts == [fact "p" 1 true, fact "y" 2]),
    ("a step applies the patches, then compacts; the met obligation no longer protects its cited fact", t.1.obligations.map (·.met) == [true, true] && t.1.work == [4] && t.2 == 7 && !(t.1.facts.any (·.key == "y"))),
    ("a rewrite of a pinned key stays pinned, with the new text and source", t.1.facts == [fact "p" 9 true, fact "x" 0]) ]

def pp : PrimaryPrompt := { version := 1, role := "crew", identity := "you build", contract := "finish with an outcome", dispositions := "edit early", variant := "may emit done" }

/-- The primary prompt: a fixed rendering, a bump changes it, and every context of the prompt opens with it. -/
def promptScenarios : List (String × Bool) :=
  let p2 := { pp with version := 2 }
  [ ("the primary prompt renders to its six segments, the version first",
      pp.render == ["vbm-primary-prompt v1", "crew", "you build", "finish with an outcome", "edit early", "may emit done"]),
    ("a version bump changes the rendering", pp.render != p2.render),
    ("a context opens with the whole prompt, whatever follows", (context pp ["w"] ["s", "o"]).take 6 == pp.render && (context pp [] []).take 6 == pp.render) ]

def mutant (n : Nat) (s : State) : State := { compact n s with obligations := [] }

def main (args : List String) : IO UInt32 := do
  let good := scenarios compact ++ promptScenarios
  let bad := (good.filter (!·.2)).length
  for (n, ok) in good do unless ok do IO.eprintln s!"differs: {n}"
  IO.println s!"vbm-context-vectors: {good.length} cases, {bad} differ"
  if args.contains "--selftest" then
    if (scenarios mutant).all (·.2) then IO.eprintln "vbm-context-vectors: the checker cannot fail (it accepted a compaction that drops the obligations)"; return 1
    IO.println "vbm-context-vectors: negative self-test ok (a compaction that drops the obligations is rejected)"
  return if bad == 0 && !good.isEmpty then 0 else 1
