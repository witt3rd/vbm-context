import VbmContext
/-! Concrete scenarios run through the COMPILED library and compared with an expected result. Regression evidence, never proof. Every property a theorem proves was deleted from here
(goal and obligations kept, idempotence, protected facts and the size bound, prompt injectivity and prefix, tail naming and the empty marker, the request and the history: `VbmContextProofs`).
What is left are exact-value checks whose expectation is the author's own reading of the definition (the rendering format, newest-first order, the cut rule): they are in the class "reference is the
same agent's assumption" (candidates to delete) and are kept only so that the gate has something to run and its negative self-test, below, has something to fail.
`--selftest` runs the compaction scenarios against a mutant compaction that drops a pinned fact and requires them to differ, so the checker is shown able to fail. Prints `vbm-context-vectors: N cases, D differ`. -/
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
  [ ("lists capped at n, newest first", s.plan == ["a"] && s.open_ == ["q1"] && s.work == [5]),
    ("the pinned fact and the fact an unmet obligation cites survive, one other fact is kept", s.facts == [fact "p" 1 true, fact "y" 2, fact "x" 0]),
    ("a step applies the patches, then compacts; the met obligation no longer protects its cited fact", t.1.obligations.map (·.met) == [true, true] && t.1.work == [4] && t.2 == 7 && !(t.1.facts.any (·.key == "y"))),
    ("a rewrite of a pinned key stays pinned, with the new text and source", t.1.facts == [fact "p" 9 true, fact "x" 0]) ]

def pp : PrimaryPrompt := { version := 1, role := "crew", identity := "you build", contract := "finish with an outcome", dispositions := "edit early", variant := "may emit done" }

/-- The primary prompt: the rendering format (a bump, injectivity and the prefix of every context are theorems). -/
def promptScenarios : List (String × Bool) :=
  [ ("the primary prompt renders to its six segments, the version first",
      pp.render == ["vbm-primary-prompt v1", "crew", "you build", "finish with an outcome", "edit early", "may emit done"]) ]

/-- A toy closed alphabet of slots over a view that is the percent used; the renderer and the redaction hook are the caller's. -/
def tailRender (n : String) (pct : Nat) : Option String :=
  if n == "budget" then some s!"budget {pct}%" else if n == "calls" then some "calls left: 9 of 40" else if n == "clock" then some "12:00"
  else if n == "key" then some "key #123" else if n == "quiet" then none else none
def tailRedact (s : String) : String := s.map fun c => if c == '#' then '*' else c
def tailSpec (names : List String) (cap total : Nat) : EphemeralSpec String := ⟨names.map (⟨·, cap⟩), total⟩
def tailAt (spec : EphemeralSpec String) (pct : Nat) : Tail String := renderTail tailRender tailRedact spec pct

/-- The ephemeral tail: the marker text, the cut rule and the redaction hook as wired (bounds, order, naming and dependence on the view alone are theorems). -/
def tailScenarios : List (String × Bool) :=
  let a := tailAt (tailSpec ["budget", "quiet", "clock"] 20 100) 74
  let b := tailAt (tailSpec ["budget", "calls", "clock"] 12 100) 74
  let c := tailAt (tailSpec ["budget", "clock"] 20 14) 74
  [ ("slots render in spec order, a slot with nothing to say is skipped", a.pieces == ["budget 74%", "12:00"] && a.shown == ["budget", "clock"] && a.dropped.isEmpty),
    ("a slot over its own cap is dropped and named", b.pieces == ["budget 74%", "12:00"] && b.dropped == ["calls"] && b.marker id == some "[tail: dropped calls]"),
    ("the first slot that does not fit the total cap and all after are dropped and named", c.pieces == ["budget 74%"] && c.dropped == ["clock"]),
    ("the redaction hook runs on every slot text", (tailAt (tailSpec ["key"] 20 100) 0).pieces == ["key *123"]) ]

/-- The mutant of the negative self-test: a compaction that forgets protection and keeps only the first `n` facts. -/
def mutant (n : Nat) (s : State) : State := { compact n s with facts := s.facts.take n }

def main (args : List String) : IO UInt32 := do
  let good := scenarios compact ++ promptScenarios ++ tailScenarios
  let bad := (good.filter (!·.2)).length
  for (n, ok) in good do unless ok do IO.eprintln s!"differs: {n}"
  IO.println s!"vbm-context-vectors: {good.length} cases, {bad} differ"
  if args.contains "--selftest" then
    if (scenarios mutant).all (·.2) then IO.eprintln "vbm-context-vectors: the checker cannot fail (it accepted a compaction that drops protected facts)"; return 1
    IO.println "vbm-context-vectors: negative self-test ok (a compaction that drops protected facts is rejected)"
  return if bad == 0 && !good.isEmpty then 0 else 1
