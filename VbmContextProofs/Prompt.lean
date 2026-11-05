import VbmContext.Prompt
import Std.Data.String.ToNat
/-! Claims about the primary prompt: a pure, injective rendering whose bytes open every context of the agent, whatever follows. -/
namespace VbmContext

theorem render_length (p : PrimaryPrompt) : p.render.length = 6 := rfl

theorem render_header (p : PrimaryPrompt) : p.render.head? = some (PrimaryPrompt.header p.version) := rfl

/-- **A version bump (or any edit of the data) changes the rendering**: distinct prompts never render alike. -/
theorem render_injective {p q : PrimaryPrompt} (h : p.render = q.render) : p = q := by
  obtain ⟨v, r, i, c, d, x⟩ := p
  obtain ⟨v', r', i', c', d', x'⟩ := q
  simp only [PrimaryPrompt.render, PrimaryPrompt.header, List.cons.injEq, and_true] at h
  obtain ⟨h1, h2, h3, h4, h5, h6⟩ := h
  have hv : toString v = toString v' := by simpa using h1
  have : v = v' := Nat.repr_injective hv
  subst this; subst h2; subst h3; subst h4; subst h5; subst h6; rfl

/-- **The prefix of every context**: the first six segments of any context of this prompt are exactly its rendering, whatever the workspace layer and the rest are. -/
theorem context_take (p : PrimaryPrompt) (workspace rest : List String) : (context p workspace rest).take 6 = p.render := by
  rw [context, List.append_assoc]; exact List.take_left' (render_length p)

theorem render_prefix (p : PrimaryPrompt) (workspace rest : List String) : p.render <+: context p workspace rest :=
  ⟨workspace ++ rest, by simp [context]⟩

/-- Two calls of the same agent (same prompt, any later parts) share the whole prompt as an identical prefix. -/
theorem context_prefix_identical (p : PrimaryPrompt) (w w' r r' : List String) : (context p w r).take 6 = (context p w' r').take 6 := by
  rw [context_take, context_take]

end VbmContext
