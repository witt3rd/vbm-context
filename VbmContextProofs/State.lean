import VbmContext
/-! Claims about `VbmContext.State`: what a patch or a compaction can never take away, idempotence and the size bound. -/
namespace VbmContext

/-- `t` keeps everything of `s` that must survive: the goal, each obligation (same id and text, `met` never reverts) and each pinned fact (same key, still pinned). -/
def Keeps (s t : State) : Prop :=
  s.goal = t.goal
  ∧ (∀ o ∈ s.obligations, ∃ o' ∈ t.obligations, o'.id = o.id ∧ o'.text = o.text ∧ (o.met = true → o'.met = true))
  ∧ (∀ f ∈ s.facts, f.pinned = true → ∃ f' ∈ t.facts, f'.key = f.key ∧ f'.pinned = true)

theorem Keeps.refl (s : State) : Keeps s s :=
  ⟨rfl, fun o h => ⟨o, h, rfl, rfl, id⟩, fun f h p => ⟨f, h, rfl, p⟩⟩

theorem Keeps.trans {a b c : State} (h1 : Keeps a b) (h2 : Keeps b c) : Keeps a c := by
  refine ⟨h1.1.trans h2.1, fun o ho => ?_, fun f hf hp => ?_⟩
  · obtain ⟨o', ho', i, t, m⟩ := h1.2.1 o ho
    obtain ⟨o'', ho'', i2, t2, m2⟩ := h2.2.1 o' ho'
    exact ⟨o'', ho'', i2.trans i, t2.trans t, fun h => m2 (m h)⟩
  · obtain ⟨f', hf', k, p⟩ := h1.2.2 f hf hp
    obtain ⟨f'', hf'', k2, p2⟩ := h2.2.2 f' hf' p
    exact ⟨f'', hf'', k2.trans k, p2⟩

theorem apply_keeps (s : State) (p : Patch) : Keeps s (s.apply p) := by
  cases p with
  | addFact f =>
    refine ⟨rfl, fun o h => ⟨o, h, rfl, rfl, id⟩, fun g hg hp => ?_⟩
    by_cases hk : g.key = f.key
    · refine ⟨_, List.mem_cons_self, hk.symm, ?_⟩
      have : (s.facts.any fun x => x.key == f.key && x.pinned) = true :=
        List.any_eq_true.2 ⟨g, hg, by simp [hk, hp]⟩
      show (f.pinned || _) = true
      simp [this]
    · exact ⟨g, List.mem_cons_of_mem _ (List.mem_filter.2 ⟨hg, by simpa using hk⟩), rfl, hp⟩
  | meet i =>
    refine ⟨rfl, fun o h => ?_, fun f h p => ⟨f, h, rfl, p⟩⟩
    by_cases hi : o.id = i
    · exact ⟨{ o with met := true }, List.mem_map.2 ⟨o, h, by simp [hi]⟩, rfl, rfl, fun _ => rfl⟩
    · exact ⟨o, List.mem_map.2 ⟨o, h, by simp [hi]⟩, rfl, rfl, id⟩
  | setPlan _ | ask _ | touch _ => exact ⟨rfl, fun o h => ⟨o, h, rfl, rfl, id⟩, fun f h p => ⟨f, h, rfl, p⟩⟩

theorem applyAll_keeps (ps : List Patch) : ∀ s : State, Keeps s (s.applyAll ps) := by
  induction ps with
  | nil => exact Keeps.refl
  | cons p ps ih => intro s; exact (apply_keeps s p).trans (ih _)

theorem compact_keeps (n : Nat) (s : State) : Keeps s (compact n s) :=
  ⟨rfl, fun o h => ⟨o, h, rfl, rfl, id⟩,
   fun f h p => ⟨f, List.mem_append_left _ (List.mem_filter.2 ⟨h, by simp [protectedBy, p]⟩), rfl, p⟩⟩

/-- Whatever the model writes and however it is compacted, the goal, every obligation and every pinned fact survive a step. -/
theorem step_keeps {Obs Act : Type} (M : Model Obs Act) (n : Nat) (s : State) (o : Obs) : Keeps s (step M n s o).1 :=
  (applyAll_keeps _ s).trans (compact_keeps _ _)

theorem compact_goal (n : Nat) (s : State) : (compact n s).goal = s.goal := rfl
theorem compact_obligations (n : Nat) (s : State) : (compact n s).obligations = s.obligations := rfl

/-- **The pin rule.** A protected fact (pinned, or cited by an obligation not yet met) is never dropped by compaction. -/
theorem compact_protected (n : Nat) (s : State) (f : Fact) (h : f ∈ s.facts) (p : protectedBy s.obligations f = true) : f ∈ (compact n s).facts :=
  List.mem_append_left _ (List.mem_filter.2 ⟨h, p⟩)

/-- The fact an unmet obligation cites by key survives compaction. -/
theorem compact_cited (n : Nat) (s : State) (o : Obligation) (ho : o ∈ s.obligations) (hm : o.met = false) (k : String) (hk : k ∈ o.cites)
    (f : Fact) (hf : f ∈ s.facts) (hfk : f.key = k) : f ∈ (compact n s).facts :=
  compact_protected n s f hf (by simp only [protectedBy, Bool.or_eq_true, List.any_eq_true]; exact Or.inr ⟨o, ho, by simp [hm, hk, hfk]⟩)

/-- After the patches of a step, every protected fact of the patched state is in the new state. -/
theorem step_protected {Obs Act : Type} (M : Model Obs Act) (n : Nat) (s : State) (o : Obs) (f : Fact)
    (h : f ∈ (s.applyAll (M.decide s o).2).facts) (p : protectedBy (s.applyAll (M.decide s o).2).obligations f = true) : f ∈ (step M n s o).1.facts :=
  compact_protected n _ f h p

theorem capFacts_idem (P : Fact → Bool) (n : Nat) (l : List Fact) : capFacts P n (capFacts P n l) = capFacts P n l := by
  have h1 : ((l.filter (!P ·)).take n).filter P = [] :=
    List.filter_eq_nil_iff.2 fun x hx => by simpa using (List.mem_filter.1 (List.mem_of_mem_take hx)).2
  have h2 : (l.filter P).filter (!P ·) = [] :=
    List.filter_eq_nil_iff.2 fun x hx => by simpa using (List.mem_filter.1 hx).2
  have h3 : ((l.filter (!P ·)).take n).filter (!P ·) = (l.filter (!P ·)).take n :=
    List.filter_eq_self.2 fun x hx => by simpa using (List.mem_filter.1 (List.mem_of_mem_take hx)).2
  have h4 : (l.filter P).filter P = l.filter P :=
    List.filter_eq_self.2 fun x hx => by simpa using (List.mem_filter.1 hx).2
  simp [capFacts, List.filter_append, h1, h2, h3, h4, List.take_take]

theorem compact_idem (n : Nat) (s : State) : compact n (compact n s) = compact n s := by
  simp [compact, capFacts_idem, List.take_take]

/-- At most `n` of each list, plus the protected facts (the only part the cap does not touch). -/
theorem compact_size (n : Nat) (s : State) : (compact n s).size ≤ 4 * n + (s.facts.filter (protectedBy s.obligations)).length := by
  simp only [State.size, compact, capFacts, List.length_append]
  have := List.length_take_le n s.plan; have := List.length_take_le n (s.facts.filter (!protectedBy s.obligations ·))
  have := List.length_take_le n s.open_; have := List.length_take_le n s.work
  omega

/-! ### One fact per key -/

theorem apply_keysDistinct (s : State) (p : Patch) (h : s.KeysDistinct) : (s.apply p).KeysDistinct := by
  cases p with
  | addFact f =>
    simp only [State.KeysDistinct, State.apply, List.map_cons, List.nodup_cons, List.mem_map, List.mem_filter] at h ⊢
    refine ⟨?_, ?_⟩
    · rintro ⟨g, ⟨hg, hk⟩, hgk⟩; simp [hgk] at hk
    · exact ((List.filter_sublist.map _).nodup h)
  | meet _ | setPlan _ | ask _ | touch _ => exact h

theorem compact_keysDistinct (n : Nat) (s : State) (h : s.KeysDistinct) : (compact n s).KeysDistinct := by
  have hp : (s.facts.filter (protectedBy s.obligations) ++ s.facts.filter (!protectedBy s.obligations ·)).Perm s.facts := List.filter_append_perm _ _
  have hs : (capFacts (protectedBy s.obligations) n s.facts).Sublist (s.facts.filter (protectedBy s.obligations) ++ s.facts.filter (!protectedBy s.obligations ·)) :=
    (List.take_sublist _ _).append_left _
  exact (hs.map (·.key)).nodup ((hp.map (·.key)).nodup_iff.2 (show (s.facts.map (·.key)).Nodup from h))

end VbmContext
