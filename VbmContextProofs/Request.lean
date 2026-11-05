import VbmContext.Request
import VbmContextProofs.Tail
import VbmContextProofs.Prompt
/-! Claims about the request and the history: the render equation, a history that never holds a tail, identical prefix bytes across calls. -/
namespace VbmContext

/-- **The render equation**: a request is the history's own rendering followed by the tail, nothing else. -/
theorem request_take (h t : List String) : (request h t).take h.length = h := by simp [request]
theorem request_drop (h t : List String) : (request h t).drop h.length = t := by simp [request]

/-- The history of the next call is this history, the reply, the observation: the previous tail is not in it. -/
theorem request_advance (h : List String) (r o : String) (t' : List String) : request (advance h r o) t' = h ++ [r, o] ++ t' := by simp [request, advance]

/-- **The history bytes are identical across calls**: the history of one call is a prefix of the next call's request, whatever tails either call showed. -/
theorem history_prefix_next (h : List String) (r o : String) (t t' : List String) : (request h t).take h.length = (request (advance h r o) t').take h.length := by
  simp [request, advance]

theorem request_bytes (h t : List String) : bytes (request h t) = bytes h + bytes t := by simp [request, bytes, List.map_append, List.sum_append]

/-- **The history is notice-free**: every segment of the history after any run of calls is in the starting history or is a reply or an observation. -/
theorem historyOf_mem (cs : List Call) : ∀ (h0 : List String) (x : String), x ∈ historyOf h0 cs → x ∈ h0 ∨ ∃ c ∈ cs, x = c.reply ∨ x = c.obs := by
  induction cs with
  | nil => intro h0 x h; exact Or.inl h
  | cons c cs ih =>
    intro h0 x h
    rcases ih _ x h with h1 | ⟨d, hd, hx⟩
    · simp only [advance, List.mem_append, List.mem_cons, List.not_mem_nil, or_false] at h1
      rcases h1 with h1 | h1 | h1
      · exact Or.inl h1
      · exact Or.inr ⟨c, List.mem_cons_self, Or.inl h1⟩
      · exact Or.inr ⟨c, List.mem_cons_self, Or.inr h1⟩
    · exact Or.inr ⟨d, List.mem_cons_of_mem _ hd, hx⟩

/-- A tail segment that is not part of the starting history and is no reply or observation never appears in the history, however many calls showed it. -/
theorem tail_not_retained (h0 : List String) (cs : List Call) (x : String) (h : x ∉ h0) (hr : ∀ c ∈ cs, x ≠ c.reply ∧ x ≠ c.obs) : x ∉ historyOf h0 cs := by
  intro hx
  rcases historyOf_mem cs h0 x hx with h1 | ⟨c, hc, hxc⟩
  · exact h h1
  · rcases hxc with e | e
    · exact (hr c hc).1 e
    · exact (hr c hc).2 e

/-- The history ignores the tails: runs that agree on replies and observations have the same history. -/
theorem historyOf_ignores_tail (h0 : List String) (cs cs' : List Call) (h : cs.map (fun c => (c.reply, c.obs)) = cs'.map (fun c => (c.reply, c.obs))) :
    historyOf h0 cs = historyOf h0 cs' := by
  induction cs generalizing h0 cs' with
  | nil => cases cs' with | nil => rfl | cons _ _ => simp at h
  | cons c cs ih =>
    cases cs' with
    | nil => simp at h
    | cons d ds =>
      simp only [List.map_cons, List.cons.injEq, Prod.mk.injEq] at h
      obtain ⟨⟨h1, h2⟩, h3⟩ := h
      simp only [historyOf, List.foldl_cons, h1, h2]
      exact ih _ ds h3

/-- **Identical prefix bytes across calls**: two full requests of the same prompt and workspace share their first `6 + workspace` segments, whatever the state, observation and tail. -/
theorem fullRequest_prefix_stable (p : PrimaryPrompt) (w s s' : List String) (o o' : String) (t t' : List String) :
    (fullRequest p w s o t).take (6 + w.length) = (fullRequest p w s' o' t').take (6 + w.length) := by
  have key : ∀ (s : List String) (o : String) (t : List String), (fullRequest p w s o t).take (6 + w.length) = p.render ++ w := by
    intro s o t
    have : fullRequest p w s o t = (p.render ++ w) ++ ((s ++ [o]) ++ t) := by simp [fullRequest, context]
    rw [this]
    exact List.take_left' (by simp [render_length])
  rw [key, key]

end VbmContext
