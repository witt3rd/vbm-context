import VbmContext.State
import VbmContext.Excerpt
/-! Old-block elision: bulky blocks that are old are replaced, in one batch, by a one-line placeholder that names the tool and the handle under which the whole text is kept. The decision is made from block sizes and
recency against the fixed budget `keepTurns` and from nothing else: no window, no token limit of a model. Every block is kept (so roles and call order survive); the first block (the task) and the latest `keepTurns` turns are never
edited; a block already elided is never elided again; the change is a cache break and is counted: the epoch rises by one exactly when the context changed. A turn starts at an assistant block and runs to the next one. -/
namespace VbmContext

inductive Role | user | assistant
  deriving DecidableEq

/-- One block of a context. `size` is the UTF-8 bytes of the text the block shows while it is not elided (an excerpt, for a long tool result); `handle` is where the whole text is kept; `kind` names the tool (or the speaker). -/
structure Block where
  role : Role
  kind : String
  handle : Handle
  size : Nat
  elided : Bool := false
  deriving DecidableEq

/-- The one-line text a block becomes when elided. -/
def Block.placeholder (b : Block) : String := s!"[elided {b.kind}: {b.size} bytes; read it back by handle {b.handle}]"

/-- What a block costs the context in bytes: its text, or its placeholder once elided. -/
def Block.cost (b : Block) : Nat := if b.elided then b.placeholder.utf8ByteSize else b.size

/-- A block is bulky when it is not elided and its placeholder is smaller than its text: eliding it saves bytes. -/
def Block.bulky (b : Block) : Bool := !b.elided && decide (b.placeholder.utf8ByteSize < b.size)

/-- Elide a block if it is bulky; any other block is left exactly as it is. -/
def Block.shrink (b : Block) : Block := if b.bulky then { b with elided := true } else b

/-- A block that is a tool result, as admitted: its size is the excerpt's. -/
def Block.result (tool : String) (h : Handle) (out : String) : Block :=
  { role := .user, kind := tool, handle := h, size := (toolExcerpt tool h out).utf8ByteSize }

/-- The bytes of a context. -/
def cost (l : List Block) : Nat := (l.map Block.cost).sum

/-- Assistant blocks (turns) in a list of roles. -/
def assistants : List Role → Nat
  | [] => 0
  | .user :: rs => assistants rs
  | .assistant :: rs => assistants rs + 1

/-- How many leading blocks are old: those before the assistant block that starts the latest `k` turns. -/
def cut (k : Nat) : List Role → Nat
  | [] => 0
  | .user :: rs => cut k rs + 1
  | .assistant :: rs => if assistants rs + 1 ≤ k then 0 else cut k rs + 1

/-- Elision over the last `k` turns: with at most `k` turns nothing changes; otherwise the first block and the latest `k` turns are kept and every bulky block between them is elided. -/
def elideOld (k : Nat) (l : List Block) : List Block :=
  if assistants (l.map Block.role) ≤ k then l
  else match l with
    | [] => []
    | b :: rest =>
      let n := cut k (rest.map Block.role)
      b :: ((rest.take n).map Block.shrink ++ rest.drop n)

/-- Elision under the fixed budget `keepTurns`. -/
def elide (l : List Block) : List Block := elideOld keepTurns l

/-- A context and its epoch: the number of cache breaks so far. -/
structure Ctx where
  blocks : List Block
  epoch : Nat
  deriving DecidableEq

/-- Elide, and count a break exactly when the context changed (one bump however many blocks were elided). -/
def Ctx.elide (c : Ctx) : Ctx :=
  if VbmContext.elide c.blocks = c.blocks then c else ⟨VbmContext.elide c.blocks, c.epoch + 1⟩

/-- Admit a new block at the end: an append is not a break (the earlier bytes are as they were). -/
def Ctx.push (c : Ctx) (b : Block) : Ctx := ⟨c.blocks ++ [b], c.epoch⟩

end VbmContext
