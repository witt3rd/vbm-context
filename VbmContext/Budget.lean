/-! The fixed budgets of context reduction, owned in ONE place. They are plain numbers: nothing here (or anywhere in context reduction) is derived from a model's context
window, because what a reduction saves is saved whatever the window is. A tool whose result needs another budget passes it as data to `excerpt`; there is no registry. -/
namespace VbmContext

/-- EXCERPT_BYTES: the most bytes of head and tail an excerpt keeps of one tool result (UTF-8 bytes; the excerpt's note comes on top of it). About 2.7k tokens at three bytes per token. -/
def excerptBytes : Nat := 8192

/-- K: the number of latest turns (an assistant block and what follows it) that elision never touches. -/
def keepTurns : Nat := 4

theorem keepTurns_pos : 0 < keepTurns := by decide

end VbmContext
