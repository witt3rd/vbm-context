/-! The ephemeral tail: what is true right now about the machine, written onto the end of ONE request by the agent core and thrown away.
A tail is configured as data (`EphemeralSpec`: ordered named slots, each with a byte cap, and a total cap) and is a pure function of that configuration and
a trusted view of the machine (`V`). It takes no history and no model text as input, so it can neither be forged nor retained; every slot text passes an opaque redaction hook.
Slots over their own cap, and every slot that does not fit the total cap, are DROPPED and NAMED (a typed marker): nothing is cut silently. What a slot says is the caller's (`render`). -/
namespace VbmContext

/-- A named slot with the byte cap of its rendered text. `N` is the caller's closed alphabet of slot names. -/
structure Slot (N : Type) where
  name : N
  cap : Nat

/-- The configuration of a tail: the order of the slots IS the rendering order and the priority order. Data, never a code path. -/
structure EphemeralSpec (N : Type) where
  slots : List (Slot N)
  totalCap : Nat

/-- A rendered tail: the texts in spec order, the names that were shown, and the names that were dropped. -/
structure Tail (N : Type) where
  pieces : List String
  shown : List N
  dropped : List N
  deriving DecidableEq

/-- Walk the slots with `used` bytes already spent. A slot with nothing to say is skipped; one over its own cap is dropped; the first one that does not fit the total cap and all after it are dropped. -/
def tailGo {N V : Type} (render : N → V → Option String) (redact : String → String) (v : V) (total : Nat) : List (Slot N) → Nat → Tail N
  | [], _ => ⟨[], [], []⟩
  | sl :: rest, used =>
    match render sl.name v with
    | none => tailGo render redact v total rest used
    | some t0 =>
      let t := redact t0
      if sl.cap < t.utf8ByteSize then let r := tailGo render redact v total rest used; { r with dropped := sl.name :: r.dropped }
      else if total < used + t.utf8ByteSize then ⟨[], [], sl.name :: rest.map (·.name)⟩
      else let r := tailGo render redact v total rest (used + t.utf8ByteSize); ⟨t :: r.pieces, sl.name :: r.shown, r.dropped⟩

/-- The tail of one call: a function of the configuration, the slot renderers, the redaction hook and the trusted view. Nothing else. -/
def renderTail {N V : Type} (render : N → V → Option String) (redact : String → String) (spec : EphemeralSpec N) (v : V) : Tail N :=
  tailGo render redact v spec.totalCap spec.slots 0

/-- The typed marker of what was dropped (`none` when nothing was): it names slots of the closed alphabet and carries no other text. -/
def Tail.marker {N : Type} (nameStr : N → String) (t : Tail N) : Option String :=
  if t.dropped.isEmpty then none else some ("[tail: dropped " ++ ", ".intercalate (t.dropped.map nameStr) ++ "]")

/-- The segments of the request's last part: the shown texts, then the marker. -/
def Tail.segments {N : Type} (nameStr : N → String) (t : Tail N) : List String := t.pieces ++ (t.marker nameStr).toList

end VbmContext
