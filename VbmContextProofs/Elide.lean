import VbmContext.Elide
import VbmContextProofs.Excerpt
/-! Claims about elision. Per block: `shrink` only ever sets the `elided` flag, never on a block that is already elided, never on a block that is not bulky, and a bulky block costs strictly less once elided (`shrink_cost_lt`).
Per context (`elideOld`): every block is kept with its role, kind, handle and size (so roles and call order survive: `elideOld_map`); the first block is never edited (`elideOld_head`); the latest `k` turns are never edited and are
exactly `k` turns once there are more (`elideOld_recent`); a block already elided stays as it is (`elideOld_elided`); the result is a fixed point (`elideOld_idem`); it is no larger and strictly smaller whenever it changed (`elideOld_cost_lt`);
no old block stays bulky (`elideOld_decomp`, `shrink_not_bulky`). Per epoch (`Ctx.elide`): one bump exactly when the context changed, none otherwise, so a second elision never bumps (`ctx_elide_idem`).
Nothing here mentions a window, a token limit or a model: the decision reads block sizes and recency only. -/
namespace VbmContext

/-! ### One block -/

theorem bulky_iff (b : Block) : b.bulky = true ↔ b.elided = false ∧ b.placeholder.utf8ByteSize < b.size := by
  simp [Block.bulky]

theorem shrink_bulky {b : Block} (h : b.bulky = true) : b.shrink = { b with elided := true } := by simp [Block.shrink, h]
theorem shrink_plain {b : Block} (h : b.bulky = false) : b.shrink = b := by simp [Block.shrink, h]

theorem shrink_role (b : Block) : b.shrink.role = b.role := by unfold Block.shrink; split <;> rfl
theorem shrink_kind (b : Block) : b.shrink.kind = b.kind := by unfold Block.shrink; split <;> rfl
theorem shrink_handle (b : Block) : b.shrink.handle = b.handle := by unfold Block.shrink; split <;> rfl
theorem shrink_size (b : Block) : b.shrink.size = b.size := by unfold Block.shrink; split <;> rfl

/-- A block already elided is never elided again. -/
theorem shrink_elided {b : Block} (h : b.elided = true) : b.shrink = b := shrink_plain (by simp [Block.bulky, h])

theorem shrink_not_bulky (b : Block) : b.shrink.bulky = false := by
  by_cases h : b.bulky = true
  · rw [shrink_bulky h]; simp [Block.bulky]
  · rw [shrink_plain (by simpa using h)]; simpa using h

/-- Idempotent: an elided block, or a block that is not bulky, is left alone. -/
theorem shrink_idem (b : Block) : b.shrink.shrink = b.shrink := shrink_plain (shrink_not_bulky b)

/-- Eliding never costs more, and a block it changes costs strictly less. -/
theorem shrink_cost_le (b : Block) : b.shrink.cost ≤ b.cost := by
  by_cases h : b.bulky = true
  · obtain ⟨h1, h2⟩ := (bulky_iff b).1 h
    rw [shrink_bulky h]; simp [Block.cost, h1, Block.placeholder]; simp [Block.placeholder] at h2; omega
  · rw [shrink_plain (by simpa using h)]; exact Nat.le_refl _

theorem shrink_cost_lt {b : Block} (h : b.shrink ≠ b) : b.shrink.cost < b.cost := by
  by_cases hb : b.bulky = true
  · obtain ⟨h1, h2⟩ := (bulky_iff b).1 hb
    rw [shrink_bulky hb]; simp [Block.cost, h1, Block.placeholder]; simp [Block.placeholder] at h2; omega
  · exact absurd (shrink_plain (by simpa using hb)) h

/-- A tool result enters the context as a user-role block that is not elided, sized as its excerpt, and that is at most the budget plus the note. -/
theorem result_size_le (tool : String) (h : Handle) (out : String) :
    (Block.result tool h out).size ≤ excerptBytes + (excerptNote tool (excerptCut excerptBytes out.toList).2.1.length out.length h).utf8ByteSize :=
  excerpt_len_le tool excerptBytes h out

theorem result_fresh (tool : String) (h : Handle) (out : String) :
    (Block.result tool h out).role = .user ∧ (Block.result tool h out).elided = false := ⟨rfl, rfl⟩

theorem cost_map_shrink_le : ∀ l : List Block, cost (l.map Block.shrink) ≤ cost l
  | [] => by simp [cost]
  | b :: rest => by
    have := cost_map_shrink_le rest; have := shrink_cost_le b
    simp only [cost, List.map_cons, List.sum_cons] at *; omega

theorem cost_map_shrink_lt : ∀ l : List Block, l.map Block.shrink ≠ l → cost (l.map Block.shrink) < cost l
  | [], h => absurd rfl h
  | b :: rest, h => by
    by_cases hb : b.shrink = b
    · have hr : rest.map Block.shrink ≠ rest := by
        intro e; apply h; simp [hb, e]
      have := cost_map_shrink_lt rest hr
      simp only [cost, List.map_cons, List.sum_cons, hb] at *; omega
    · have := cost_map_shrink_le rest; have := shrink_cost_lt hb
      simp only [cost, List.map_cons, List.sum_cons] at *; omega

/-! ### The roles decide the cut -/

theorem map_shrink_role (l : List Block) : (l.map Block.shrink).map Block.role = l.map Block.role := by
  simp [List.map_map, Function.comp_def, shrink_role]

theorem cut_le (k : Nat) : ∀ rs : List Role, cut k rs ≤ rs.length
  | [] => by simp [cut]
  | .user :: rs => by simp [cut]; have := cut_le k rs; omega
  | .assistant :: rs => by
    simp only [cut]; split
    · omega
    · have := cut_le k rs; simp; omega

/-- From the cut on, the rest is exactly the latest `k` turns (and is not empty), as soon as there are at least `k` turns. -/
theorem cut_drop {k : Nat} (hk : 0 < k) : ∀ rs : List Role, k ≤ assistants rs → assistants (rs.drop (cut k rs)) = k ∧ rs.drop (cut k rs) ≠ []
  | [], h => by simp [assistants] at h; omega
  | .user :: rs, h => by
    simp only [assistants] at h
    simp only [cut, List.drop_succ_cons]; exact cut_drop hk rs h
  | .assistant :: rs, h => by
    simp only [cut]
    split
    · rename_i hc
      simp only [assistants, List.drop_zero] at h ⊢
      exact ⟨by omega, by simp⟩
    · rename_i hc
      simp only [assistants] at h
      simp only [List.drop_succ_cons]
      exact cut_drop hk rs (by omega)

/-! ### One context -/

theorem assistants_cons_le (r : Role) (rs : List Role) : assistants rs ≤ assistants (r :: rs) := by
  cases r <;> simp [assistants]

/-- Every block is kept, with the same role, kind, handle and size: only the `elided` flag can change. -/
theorem elideOld_map {α : Type} (f : Block → α) (hf : ∀ b, f b.shrink = f b) (k : Nat) (l : List Block) :
    (elideOld k l).map f = l.map f := by
  unfold elideOld
  split
  · rfl
  · cases l with
    | nil => rfl
    | cons b rest =>
      simp only [List.map_cons, List.map_append, List.map_map, Function.comp_def, hf]
      rw [← List.map_append, List.take_append_drop]

theorem elideOld_roles (k : Nat) (l : List Block) : (elideOld k l).map Block.role = l.map Block.role := elideOld_map _ shrink_role k l
theorem elideOld_handles (k : Nat) (l : List Block) : (elideOld k l).map Block.handle = l.map Block.handle := elideOld_map _ shrink_handle k l
theorem elideOld_kinds (k : Nat) (l : List Block) : (elideOld k l).map Block.kind = l.map Block.kind := elideOld_map _ shrink_kind k l
theorem elideOld_sizes (k : Nat) (l : List Block) : (elideOld k l).map Block.size = l.map Block.size := elideOld_map _ shrink_size k l

/-- No block is added, dropped or reordered. -/
theorem elideOld_length (k : Nat) (l : List Block) : (elideOld k l).length = l.length := by
  simpa using congrArg List.length (elideOld_map (fun _ => ()) (fun _ => rfl) k l)

/-- With at most `k` turns nothing changes. -/
theorem elideOld_small {k : Nat} {l : List Block} (h : assistants (l.map Block.role) ≤ k) : elideOld k l = l := by
  simp [elideOld, h]

/-- **The first block (the task) is never edited.** -/
theorem elideOld_head (k : Nat) (l : List Block) : (elideOld k l).head? = l.head? := by
  unfold elideOld
  split
  · rfl
  · cases l <;> rfl

theorem elideOld_cons {k : Nat} {b : Block} {rest : List Block} (h : ¬ assistants ((b :: rest).map Block.role) ≤ k) :
    elideOld k (b :: rest) = b :: ((rest.take (cut k (rest.map Block.role))).map Block.shrink ++ rest.drop (cut k (rest.map Block.role))) := by
  unfold elideOld
  split
  · exact absurd ‹_› h
  · rfl

/-- The shape of an elision that changes anything: the first block, the old blocks (each shrunk) and the latest `k` turns, which are kept as they were. -/
theorem elideOld_decomp {k : Nat} (hk : 0 < k) {l : List Block} (h : k < assistants (l.map Block.role)) :
    ∃ b old rec, l = b :: (old ++ rec) ∧ elideOld k l = b :: (old.map Block.shrink ++ rec) ∧ rec ≠ [] ∧ assistants (rec.map Block.role) = k := by
  cases l with
  | nil => simp [assistants] at h
  | cons b rest =>
    have hge : k ≤ assistants (rest.map Block.role) := by
      have := assistants_cons_le b.role (rest.map Block.role)
      simp only [List.map_cons] at h
      cases hb : b.role <;> simp [hb, assistants] at h <;> omega
    obtain ⟨h1, h2⟩ := cut_drop hk _ hge
    refine ⟨b, rest.take (cut k (rest.map Block.role)), rest.drop (cut k (rest.map Block.role)), by simp, ?_, ?_, ?_⟩
    · exact elideOld_cons (Nat.not_le.mpr h)
    · intro e; apply h2; rw [← List.map_drop, e]; rfl
    · rw [← List.map_drop] at h1; exact h1

/-- **The latest turns are never edited.** With `0 < k`, a nonempty context has a nonempty suffix, holding the last block and exactly `k` turns (or all of them if there are fewer), that elision leaves as it is. -/
theorem elideOld_recent {k : Nat} (hk : 0 < k) (l : List Block) :
    ∃ suf, suf <:+ l ∧ suf <:+ elideOld k l ∧ (l ≠ [] → suf ≠ []) ∧ assistants (suf.map Block.role) = min k (assistants (l.map Block.role)) := by
  by_cases h : assistants (l.map Block.role) ≤ k
  · exact ⟨l, List.suffix_refl _, by rw [elideOld_small h]; exact List.suffix_refl _, fun h => h, by omega⟩
  · obtain ⟨b, old, rec, e1, e2, hne, hr⟩ := elideOld_decomp hk (Nat.not_le.mp h)
    refine ⟨rec, ?_, ?_, fun _ => hne, by omega⟩
    · rw [e1]; exact ⟨b :: old, by simp⟩
    · rw [e2]; exact ⟨b :: old.map Block.shrink, by simp⟩

theorem getLast?_of_suffix {α : Type} {s l : List α} (h : s <:+ l) (hne : s ≠ []) : s.getLast? = l.getLast? := by
  obtain ⟨p, rfl⟩ := h
  cases s with
  | nil => exact absurd rfl hne
  | cons x xs => rw [List.getLast?_append]; simp [List.getLast?_cons]

/-- The latest block is never edited (with `0 < k`; in particular under `keepTurns`). -/
theorem elideOld_last {k : Nat} (hk : 0 < k) (l : List Block) : (elideOld k l).getLast? = l.getLast? := by
  by_cases hl : l = []
  · subst hl; simp [elideOld, assistants]
  · obtain ⟨suf, h1, h2, h3, _⟩ := elideOld_recent hk l
    rw [← getLast?_of_suffix h2 (h3 hl), getLast?_of_suffix h1 (h3 hl)]

/-- **A block already elided stays as it is** (it is never elided twice, and never undone). -/
theorem elideOld_elided {k : Nat} {l : List Block} {x : Block} (hx : x ∈ l) (he : x.elided = true) : x ∈ elideOld k l := by
  unfold elideOld
  split
  · exact hx
  · cases l with
    | nil => exact hx
    | cons b rest =>
      rcases List.mem_cons.1 hx with rfl | hx
      · exact List.mem_cons_self
      · refine List.mem_cons_of_mem _ ?_
        rw [← List.take_append_drop (cut k (rest.map Block.role)) rest] at hx
        rcases List.mem_append.1 hx with hx | hx
        · exact List.mem_append_left _ (List.mem_map.2 ⟨x, hx, shrink_elided he⟩)
        · exact List.mem_append_right _ hx

/-- **Idempotent**: elision of an elided context changes nothing. -/
theorem elideOld_idem (k : Nat) (l : List Block) : elideOld k (elideOld k l) = elideOld k l := by
  by_cases h : assistants (l.map Block.role) ≤ k
  · rw [elideOld_small h, elideOld_small h]
  · cases l with
    | nil => simp [elideOld]
    | cons b rest =>
      have hlen : cut k (rest.map Block.role) ≤ rest.length := by simpa using cut_le k (rest.map Block.role)
      have e := elideOld_cons h
      generalize hn : cut k (rest.map Block.role) = n at e hlen
      have hA : ((rest.take n).map Block.shrink).length = n := by simp [hlen]
      have hroles : ((rest.take n).map Block.shrink ++ rest.drop n).map Block.role = rest.map Block.role := by
        rw [List.map_append, map_shrink_role, ← List.map_append, List.take_append_drop]
      have h' : ¬ assistants ((b :: ((rest.take n).map Block.shrink ++ rest.drop n)).map Block.role) ≤ k := by
        show ¬ assistants (b.role :: _) ≤ k
        rw [hroles]; exact h
      rw [e, elideOld_cons h', hroles, hn, List.take_left' hA, List.drop_left' hA]
      simp only [List.map_map, Function.comp_def, shrink_idem]

theorem cost_split (n : Nat) (rest : List Block) : cost rest = cost (rest.take n) + cost (rest.drop n) := by
  unfold cost
  conv => lhs; rw [← List.take_append_drop n (rest.map Block.cost)]
  rw [List.sum_append, List.map_take, List.map_drop]

/-- **No more bytes, and strictly fewer whenever the context changed.** -/
theorem elideOld_cost_le (k : Nat) (l : List Block) : cost (elideOld k l) ≤ cost l := by
  by_cases h : assistants (l.map Block.role) ≤ k
  · rw [elideOld_small h]; exact Nat.le_refl _
  · cases l with
    | nil => exact Nat.le_refl _
    | cons b rest =>
      rw [elideOld_cons h]
      generalize cut k (rest.map Block.role) = n
      have := cost_map_shrink_le (rest.take n)
      have e := cost_split n rest
      simp only [cost, List.map_cons, List.sum_cons, List.map_append, List.sum_append] at this e ⊢
      omega

theorem elideOld_cost_lt (k : Nat) (l : List Block) (hc : elideOld k l ≠ l) : cost (elideOld k l) < cost l := by
  by_cases h : assistants (l.map Block.role) ≤ k
  · exact absurd (elideOld_small h) hc
  · cases l with
    | nil => exact absurd rfl hc
    | cons b rest =>
      rw [elideOld_cons h] at hc ⊢
      generalize cut k (rest.map Block.role) = n at hc ⊢
      have hne : (rest.take n).map Block.shrink ≠ rest.take n := by
        intro e; apply hc; rw [e, List.take_append_drop]
      have := cost_map_shrink_lt _ hne
      have e := cost_split n rest
      simp only [cost, List.map_cons, List.sum_cons, List.map_append, List.sum_append] at this e ⊢
      omega

/-! ### The epoch -/

theorem ctx_elide_blocks (c : Ctx) : c.elide.blocks = elide c.blocks := by
  simp only [Ctx.elide]; split <;> simp_all

/-- **One bump per change**: the epoch rises by exactly one when the context changed, and not at all otherwise. -/
theorem ctx_elide_epoch_bump {c : Ctx} (h : elide c.blocks ≠ c.blocks) : c.elide.epoch = c.epoch + 1 := by
  unfold Ctx.elide; simp [h]

theorem ctx_elide_epoch_same {c : Ctx} (h : elide c.blocks = c.blocks) : c.elide = c := by
  unfold Ctx.elide; simp [h]

theorem ctx_elide_epoch_le (c : Ctx) : c.elide.epoch ≤ c.epoch + 1 := by
  simp only [Ctx.elide]; split <;> simp

/-- The epoch rises exactly when the blocks changed. -/
theorem ctx_elide_epoch_iff (c : Ctx) : c.elide.epoch = c.epoch + 1 ↔ c.elide.blocks ≠ c.blocks := by
  by_cases h : elide c.blocks = c.blocks
  · rw [ctx_elide_epoch_same h]; simp
  · rw [ctx_elide_epoch_bump h, ctx_elide_blocks]; simp [h]

/-- A second elision neither changes the blocks nor counts a break. -/
theorem ctx_elide_idem (c : Ctx) : c.elide.elide = c.elide := by
  apply ctx_elide_epoch_same
  rw [ctx_elide_blocks]; exact elideOld_idem keepTurns c.blocks

/-- A change shrinks the context strictly. -/
theorem ctx_elide_cost_lt {c : Ctx} (h : c.elide.epoch = c.epoch + 1) : cost c.elide.blocks < cost c.blocks := by
  rw [ctx_elide_epoch_iff] at h
  rw [ctx_elide_blocks] at h ⊢
  exact elideOld_cost_lt keepTurns _ h

/-- Appending a block is not a break, and leaves every earlier block as it was. -/
theorem ctx_push_epoch (c : Ctx) (b : Block) : (c.push b).epoch = c.epoch := rfl
theorem ctx_push_prefix (c : Ctx) (b : Block) : c.blocks <+: (c.push b).blocks := ⟨[b], rfl⟩

/-- **Under the fixed budget**: the latest block is never edited, and a context of at most `keepTurns` turns never changes. -/
theorem elide_last (l : List Block) : (elide l).getLast? = l.getLast? := elideOld_last keepTurns_pos l

theorem elide_small {l : List Block} (h : assistants (l.map Block.role) ≤ keepTurns) : elide l = l := elideOld_small h

end VbmContext
