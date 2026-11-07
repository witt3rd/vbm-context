import VbmContext.State
import VbmContext.Budget
/-! The excerpt (the pointer spill): a text bound for the context that is over its budget is shown as its head and its tail with a note that says which tool produced it, how much was omitted and under which
handle the whole text is kept. A text within the budget is shown whole. The function is pure and the whole text is the caller's to keep (writing it is I/O, not here): the excerpt is a VIEW and nothing is
capped in what is stored. Sizes are UTF-8 bytes; head and tail are whole characters. The budget is a number the caller passes (the fixed `excerptBytes` unless a tool brings its own): no window is read. -/
namespace VbmContext

/-- UTF-8 bytes of a text given as characters. -/
def bytesOf (cs : List Char) : Nat := (cs.map Char.utf8Size).sum

/-- The longest prefix of whole characters within `n` bytes (it stops at the first character that does not fit, so it never splits one). -/
def headBytes : Nat → List Char → List Char
  | _, [] => []
  | n, c :: cs => if c.utf8Size ≤ n then c :: headBytes (n - c.utf8Size) cs else []

/-- The longest suffix of whole characters within `n` bytes. -/
def tailBytes (n : Nat) (cs : List Char) : List Char := (headBytes n cs.reverse).reverse

/-- The cut: the head takes at most half the budget, the tail is cut from what the head left, so head, omitted middle and tail are disjoint and in order. -/
def excerptCut (budget : Nat) (cs : List Char) : List Char × List Char × List Char :=
  let h := headBytes (budget / 2) cs
  let r := cs.drop h.length
  let t := tailBytes (budget / 2) r
  (h, r.take (r.length - t.length), t)

/-- The line that replaces the omitted middle: the tool, how much was omitted, how long the whole is, and the handle under which the whole text is kept. -/
def excerptNote (tool : String) (omitted total : Nat) (h : Handle) : String :=
  s!"\n[... {omitted} characters of {tool} output omitted; the full text ({total} characters) is kept as handle {h}: read it back by that handle ...]\n"

/-- A text within the budget is shown as it is. -/
def fits (budget : Nat) (out : String) : Bool := out.utf8ByteSize ≤ budget

/-- The excerpt of a text over the budget: head, note, tail. -/
def cutText (tool : String) (budget : Nat) (h : Handle) (out : String) : String :=
  let p := excerptCut budget out.toList
  String.ofList p.1 ++ excerptNote tool p.2.1.length out.length h ++ String.ofList p.2.2

/-- What the context shows for the result `out` of `tool` (the whole text is kept under `h` by the caller). -/
def excerpt (tool : String) (budget : Nat) (h : Handle) (out : String) : String := if fits budget out then out else cutText tool budget h out

/-- The excerpt of a tool result at its admission under the fixed budget. -/
def toolExcerpt (tool : String) (h : Handle) (out : String) : String := excerpt tool excerptBytes h out

end VbmContext
