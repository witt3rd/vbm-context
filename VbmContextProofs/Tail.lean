import VbmContext.Tail
/-! Claims about the ephemeral tail: bounded by its caps, determined by (configuration, view), in spec order, every over-cap or cut slot named, every piece passed through the redaction hook. -/
namespace VbmContext
variable {N V : Type} (render : N → V → Option String) (redact : String → String) (v : V) (total : Nat)

/-- Bytes of a list of texts. -/
def bytes (l : List String) : Nat := (l.map (·.utf8ByteSize)).sum

/-- The tail's bytes never exceed what the budget `total` leaves after `used`. -/
theorem tailGo_bytes : ∀ (slots : List (Slot N)) (used : Nat), used ≤ total → used + bytes (tailGo render redact v total slots used).pieces ≤ total
  | [], used, h => by simp [tailGo, bytes, h]
  | sl :: rest, used, h => by
    unfold tailGo
    cases hr : render sl.name v with
    | none => exact tailGo_bytes rest used h
    | some t0 =>
      simp only []
      split
      · exact tailGo_bytes rest used h
      · split
        · simp [bytes, h]
        · rename_i _ h2
          have := tailGo_bytes rest (used + (redact t0).utf8ByteSize) (by omega)
          simp only [bytes, List.map_cons, List.sum_cons] at this ⊢
          omega

/-- **The tail is bounded**: the shown texts total at most the total cap. -/
theorem tail_bounded (spec : EphemeralSpec N) : bytes (renderTail render redact spec v).pieces ≤ spec.totalCap := by
  have := tailGo_bytes render redact v spec.totalCap spec.slots 0 (Nat.zero_le _)
  simpa [renderTail] using this

/-- Each shown text is within the cap of one of the spec's slots. -/
theorem tailGo_piece_cap : ∀ (slots : List (Slot N)) (used : Nat), ∀ p ∈ (tailGo render redact v total slots used).pieces, ∃ sl ∈ slots, p.utf8ByteSize ≤ sl.cap
  | [], _, p, hp => by simp [tailGo] at hp
  | sl :: rest, used, p, hp => by
    unfold tailGo at hp
    cases hr : render sl.name v with
    | none =>
      rw [hr] at hp; simp only [] at hp
      obtain ⟨s, hs, h⟩ := tailGo_piece_cap rest used p hp; exact ⟨s, List.mem_cons_of_mem _ hs, h⟩
    | some t0 =>
      rw [hr] at hp; simp only [] at hp
      split at hp
      · obtain ⟨s, hs, h⟩ := tailGo_piece_cap rest used p hp; exact ⟨s, List.mem_cons_of_mem _ hs, h⟩
      · split at hp
        · simp at hp
        · rename_i h1 _
          rcases List.mem_cons.1 hp with rfl | hp
          · exact ⟨sl, List.mem_cons_self, by omega⟩
          · obtain ⟨s, hs, h⟩ := tailGo_piece_cap rest (used + (redact t0).utf8ByteSize) p hp; exact ⟨s, List.mem_cons_of_mem _ hs, h⟩

theorem tail_piece_cap (spec : EphemeralSpec N) : ∀ p ∈ (renderTail render redact spec v).pieces, ∃ sl ∈ spec.slots, p.utf8ByteSize ≤ sl.cap :=
  tailGo_piece_cap render redact v spec.totalCap spec.slots 0

/-- **Spec order**: the shown names and the dropped names are each a subsequence of the spec's slot names. -/
theorem tailGo_order : ∀ (slots : List (Slot N)) (used : Nat),
    (tailGo render redact v total slots used).shown.Sublist (slots.map (·.name)) ∧ (tailGo render redact v total slots used).dropped.Sublist (slots.map (·.name))
  | [], _ => by simp [tailGo]
  | sl :: rest, used => by
    unfold tailGo
    cases hr : render sl.name v with
    | none =>
      simp only []
      have := tailGo_order rest used
      exact ⟨this.1.cons _, this.2.cons _⟩
    | some t0 =>
      simp only []
      split
      · have := tailGo_order rest used; exact ⟨this.1.cons _, this.2.cons_cons _⟩
      · split
        · exact ⟨by simp, by simp⟩
        · have := tailGo_order rest (used + (redact t0).utf8ByteSize); exact ⟨this.1.cons_cons _, this.2.cons _⟩

theorem tail_order (spec : EphemeralSpec N) :
    (renderTail render redact spec v).shown.Sublist (spec.slots.map (·.name)) ∧ (renderTail render redact spec v).dropped.Sublist (spec.slots.map (·.name)) :=
  tailGo_order render redact v spec.totalCap spec.slots 0

/-- **Nothing is cut silently**: a slot whose (redacted) text is over its own cap is named in the dropped list. -/
theorem tailGo_oversize : ∀ (slots : List (Slot N)) (used : Nat) (sl : Slot N), sl ∈ slots → ∀ t0, render sl.name v = some t0 →
    sl.cap < (redact t0).utf8ByteSize → sl.name ∈ (tailGo render redact v total slots used).dropped
  | [], _, sl, h, _, _, _ => by simp at h
  | s :: rest, used, sl, h, t0, hr, hc => by
    unfold tailGo
    cases hs : render s.name v with
    | none =>
      simp only []
      rcases List.mem_cons.1 h with rfl | h
      · rw [hs] at hr; cases hr
      · exact tailGo_oversize rest used sl h t0 hr hc
    | some u0 =>
      simp only []
      split
      · rcases List.mem_cons.1 h with rfl | h
        · exact List.mem_cons_self
        · exact List.mem_cons_of_mem _ (tailGo_oversize rest used sl h t0 hr hc)
      · split
        · rcases List.mem_cons.1 h with rfl | h
          · exact List.mem_cons_self
          · exact List.mem_cons_of_mem _ (List.mem_map.2 ⟨sl, h, rfl⟩)
        · rcases List.mem_cons.1 h with rfl | h
          · rw [hs] at hr; cases hr; omega
          · exact tailGo_oversize rest _ sl h t0 hr hc

theorem tail_oversize_named (spec : EphemeralSpec N) (sl : Slot N) (h : sl ∈ spec.slots) (t0 : String) (hr : render sl.name v = some t0)
    (hc : sl.cap < (redact t0).utf8ByteSize) : sl.name ∈ (renderTail render redact spec v).dropped :=
  tailGo_oversize render redact v spec.totalCap spec.slots 0 sl h t0 hr hc

/-- **No secret survives the render**: if the redaction hook yields only clean text (`Clean` is whatever the caller means by it), every shown piece is clean. -/
theorem tailGo_clean (Clean : String → Prop) (hc : ∀ s, Clean (redact s)) : ∀ (slots : List (Slot N)) (used : Nat), ∀ p ∈ (tailGo render redact v total slots used).pieces, Clean p
  | [], _, p, hp => by simp [tailGo] at hp
  | sl :: rest, used, p, hp => by
    unfold tailGo at hp
    cases hr : render sl.name v with
    | none => rw [hr] at hp; exact tailGo_clean Clean hc rest used p hp
    | some t0 =>
      rw [hr] at hp; simp only [] at hp
      split at hp
      · exact tailGo_clean Clean hc rest used p hp
      · split at hp
        · simp at hp
        · rcases List.mem_cons.1 hp with rfl | hp
          · exact hc _
          · exact tailGo_clean Clean hc rest _ p hp

theorem tail_clean (spec : EphemeralSpec N) (Clean : String → Prop) (hc : ∀ s, Clean (redact s)) : ∀ p ∈ (renderTail render redact spec v).pieces, Clean p :=
  tailGo_clean render redact v spec.totalCap Clean hc spec.slots 0

/-- **Determined by (configuration, state)**: a tail is built from the trusted view of the state and nothing else, so equal views give equal tails. -/
theorem tail_of_view {S : Type} (view : S → V) (spec : EphemeralSpec N) (s s' : S) (h : view s = view s') :
    renderTail render redact spec (view s) = renderTail render redact spec (view s') := by rw [h]

/-- The marker is absent exactly when nothing was dropped. -/
theorem marker_none_iff (nameStr : N → String) (t : Tail N) : t.marker nameStr = none ↔ t.dropped = [] := by
  cases h : t.dropped <;> simp [Tail.marker, h]

end VbmContext
