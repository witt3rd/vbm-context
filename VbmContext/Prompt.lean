/-! The primary prompt: the first, static part of every agent's context. Typed data, versioned, rendered by a pure function into a fixed list of
segments, so the same data gives the same bytes on every call and on every box, and a version bump is a visible change of the first segment.
What the text says is data (the caller's policy), never code here. Three layers of a context, in order: primary prompt (this), typed state (`State`),
ephemeral tail (`Tail`). -/
namespace VbmContext

/-- One primary prompt: identity and function of a role, the outcome contract and the dispositions every role shares, and the role's own variant. -/
structure PrimaryPrompt where
  version : Nat
  role : String
  identity : String
  contract : String
  dispositions : String
  variant : String
  deriving DecidableEq

/-- The first segment names the version, so a bump changes the bytes (and counts as a deliberate cache break). -/
def PrimaryPrompt.header (v : Nat) : String := "vbm-primary-prompt v" ++ toString v

/-- Rendering: no clock, no id, no path, no ordering from outside: a fixed list of six segments, a function of the data alone. -/
def PrimaryPrompt.render (p : PrimaryPrompt) : List String :=
  [PrimaryPrompt.header p.version, p.role, p.identity, p.contract, p.dispositions, p.variant]

/-- A context: the primary prompt first, then the workspace layer, then the state and the call's own parts. -/
def context (p : PrimaryPrompt) (workspace rest : List String) : List String := p.render ++ workspace ++ rest

end VbmContext
