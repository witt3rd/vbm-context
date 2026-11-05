/-! The typed state of an agent step: a compact, typed record that replaces the transcript, the typed patches a model may write
back, and a total, deterministic compaction. Pure data and total functions over `Init` only; the claims are in `VbmContextProofs`. -/
namespace VbmContext

/-- Where a fact came from: the index of the journal record (the full history stays in the journal, so it stays retrievable). -/
abbrev Handle := Nat

/-- A fact with its provenance. A pinned fact is protected: compaction never drops it, and a later write never unpins it. -/
structure Fact where
  key : String
  text : String
  src : Handle
  pinned : Bool := false
  deriving DecidableEq

/-- A "done when" clause of the task. -/
structure Obligation where
  id : Nat
  text : String
  met : Bool := false
  deriving DecidableEq

structure State where
  goal : String                  -- the task, verbatim, frozen
  obligations : List Obligation  -- never dropped, ids and texts fixed, `met` only goes from false to true
  plan : List String
  facts : List Fact              -- one fact per key (`addFact` replaces)
  open_ : List String            -- open questions
  work : List Handle             -- the working set: handles into the journal, not contents
  deriving DecidableEq

/-- What a model may write back: a typed patch, never a whole new state. -/
inductive Patch where
  | addFact (f : Fact) | meet (id : Nat) | setPlan (p : List String) | ask (q : String) | touch (h : Handle)

/-- A new fact replaces the old one of its key (newest first) and stays pinned if the old one was. -/
def State.apply (s : State) : Patch → State
  | .addFact f =>
    let pin := f.pinned || s.facts.any fun g => g.key == f.key && g.pinned
    { s with facts := { f with pinned := pin } :: s.facts.filter (·.key != f.key) }
  | .meet i => { s with obligations := s.obligations.map fun o => if o.id = i then { o with met := true } else o }
  | .setPlan p => { s with plan := p }
  | .ask q => { s with open_ := q :: s.open_ }
  | .touch h => { s with work := h :: s.work.filter (· != h) }

def State.applyAll (s : State) (ps : List Patch) : State := ps.foldl State.apply s

/-- Compaction caps each unbounded list at `n`, newest first, and keeps the goal, the obligations and every pinned fact whole.
A projection, not a re-summary: that is what makes it idempotent. Total and deterministic by construction (a function). -/
def compact (n : Nat) (s : State) : State :=
  { s with plan := s.plan.take n, open_ := s.open_.take n, work := s.work.take n,
           facts := s.facts.filter (·.pinned) ++ (s.facts.filter (!·.pinned)).take n }

/-- The one-step machine: the model, an arbitrary function, sees the state and an observation and returns an action and patches. -/
structure Model (Obs Act : Type) where
  decide : State → Obs → Act × List Patch

def step {Obs Act : Type} (M : Model Obs Act) (n : Nat) (s : State) (o : Obs) : State × Act :=
  let r := M.decide s o
  (compact n (s.applyAll r.2), r.1)

/-- Count of items, standing in for a token estimate (a real one is a byte count over a rendering). -/
def State.size (s : State) : Nat := s.plan.length + s.facts.length + s.open_.length + s.work.length

end VbmContext
