import VbmContext.Excerpt
/-! Claims about the excerpt: the text shown is the whole text when it fits; otherwise it is the head, a note and the tail, the head and the tail whole characters from the two ends of the text, the note's count exactly the omitted middle,
and the length at most the budget plus the note. Not proved: that the caller keeps the whole text under the handle (that is the caller's write), and a bound on the note itself (it carries a tool name and numbers). -/
namespace VbmContext

theorem headBytes_size : ∀ (n : Nat) (cs : List Char), bytesOf (headBytes n cs) ≤ n
  | _, [] => by simp [headBytes, bytesOf]
  | n, c :: cs => by
    unfold headBytes
    split
    · have := headBytes_size (n - c.utf8Size) cs
      simp only [bytesOf, List.map_cons, List.sum_cons] at *; omega
    · simp [bytesOf]

theorem headBytes_prefix : ∀ (n : Nat) (cs : List Char), headBytes n cs <+: cs
  | _, [] => by simp [headBytes]
  | n, c :: cs => by
    unfold headBytes
    split
    · obtain ⟨t, ht⟩ := headBytes_prefix (n - c.utf8Size) cs
      exact ⟨t, by simp [ht]⟩
    · exact ⟨c :: cs, rfl⟩

/-- The size read off a string is the size the cut is proved over. -/
theorem utf8ByteSize_ofList (cs : List Char) : (String.ofList cs).utf8ByteSize = bytesOf cs := by
  have h : ∀ cs : List Char, cs.utf8Encode.size = bytesOf cs := by
    intro cs
    induction cs with
    | nil => simp [List.utf8Encode, bytesOf]
    | cons c cs ih =>
      rw [List.utf8Encode_cons, ByteArray.size_append, ih]
      simp [List.utf8Encode_singleton, bytesOf]
  rw [← String.size_toByteArray, String.toByteArray_ofList, h]

theorem bytesOf_reverse (cs : List Char) : bytesOf cs.reverse = bytesOf cs := by
  simp [bytesOf, List.map_reverse, List.sum_reverse]

theorem tailBytes_size (n : Nat) (cs : List Char) : bytesOf (tailBytes n cs) ≤ n := by
  have := headBytes_size n cs.reverse
  rw [tailBytes, bytesOf_reverse]; exact this

theorem tailBytes_suffix (n : Nat) (cs : List Char) : tailBytes n cs <:+ cs := by
  have := headBytes_prefix n cs.reverse
  obtain ⟨t, ht⟩ := this
  exact ⟨t.reverse, by rw [tailBytes, ← List.reverse_append, ht, List.reverse_reverse]⟩

/-- Nothing is lost or reordered: head, middle and tail are the text. -/
theorem excerptCut_parts (budget : Nat) (cs : List Char) :
    (excerptCut budget cs).1 ++ (excerptCut budget cs).2.1 ++ (excerptCut budget cs).2.2 = cs := by
  simp only [excerptCut]
  obtain ⟨y, hy⟩ := headBytes_prefix (budget / 2) cs
  generalize headBytes (budget / 2) cs = h at hy ⊢
  subst hy
  rw [List.drop_left]
  obtain ⟨x, hx⟩ := tailBytes_suffix (budget / 2) y
  generalize tailBytes (budget / 2) y = t at hx ⊢
  subst hx
  simp

/-- The kept bytes (head and tail) never exceed the budget, whatever the widths of the characters. -/
theorem excerptCut_size (budget : Nat) (cs : List Char) :
    bytesOf (excerptCut budget cs).1 + bytesOf (excerptCut budget cs).2.2 ≤ budget := by
  have h1 := headBytes_size (budget / 2) cs
  have h2 := tailBytes_size (budget / 2) (cs.drop (headBytes (budget / 2) cs).length)
  simp only [excerptCut]; omega

/-- The note's count is exactly the characters between the kept head and tail. -/
theorem excerpt_omitted (budget : Nat) (cs : List Char) :
    (excerptCut budget cs).2.1.length + (excerptCut budget cs).1.length + (excerptCut budget cs).2.2.length = cs.length := by
  have := congrArg List.length (excerptCut_parts budget cs)
  simp only [List.length_append] at this; omega

/-- A text within the budget is shown whole. -/
theorem excerpt_of_fits {budget : Nat} {tool : String} {h : Handle} {out : String} (hf : out.utf8ByteSize ≤ budget) : excerpt tool budget h out = out := by
  simp [excerpt, fits, hf]

/-- **Bounded.** An excerpt is at most the budget plus its note, whatever the text and the widths of its characters. -/
theorem excerpt_len_le (tool : String) (budget : Nat) (h : Handle) (out : String) :
    (excerpt tool budget h out).utf8ByteSize ≤ budget + (excerptNote tool (excerptCut budget out.toList).2.1.length out.length h).utf8ByteSize := by
  by_cases hf : fits budget out = true
  · have h' : out.utf8ByteSize ≤ budget := by simpa [fits] using hf
    simp only [excerpt, hf, ite_true]; omega
  · have h' : fits budget out = false := by simpa using hf
    simp only [excerpt, h', ite_false, cutText, String.utf8ByteSize_append, utf8ByteSize_ofList, Bool.false_eq_true]
    have := excerptCut_size budget out.toList
    omega

/-- **Head and tail kept.** The text is the head, the omitted middle and the tail, in order, and the excerpt is the head, the note, the tail. -/
theorem excerpt_keeps_head_tail (tool : String) (budget : Nat) (h : Handle) (out : String) (hf : ¬ fits budget out = true) :
    ∃ hd mid tl : List Char, out.toList = hd ++ mid ++ tl ∧ bytesOf hd + bytesOf tl ≤ budget ∧
      excerpt tool budget h out = String.ofList hd ++ excerptNote tool mid.length out.length h ++ String.ofList tl := by
  refine ⟨(excerptCut budget out.toList).1, (excerptCut budget out.toList).2.1, (excerptCut budget out.toList).2.2,
    (excerptCut_parts budget out.toList).symm, excerptCut_size budget out.toList, ?_⟩
  have h' : fits budget out = false := by simpa using hf
  simp [excerpt, h', cutText]

theorem headBytes_ne_nil {n : Nat} {c : Char} {cs : List Char} (h : 4 ≤ n) : headBytes n (c :: cs) ≠ [] := by
  have : c.utf8Size ≤ n := Nat.le_trans (Char.utf8Size_le_four c) h
  simp [headBytes, this]

/-- With room for one character at each end (8 bytes), a cut text keeps something of both ends: the model always sees how the text began and how it ended. -/
theorem excerpt_ends_nonempty (budget : Nat) (out : String) (hb : 8 ≤ budget) (hf : ¬ fits budget out = true) :
    (excerptCut budget out.toList).1 ≠ [] ∧ (excerptCut budget out.toList).2.2 ≠ [] := by
  have hbig : budget < bytesOf out.toList := by
    have : ¬ out.utf8ByteSize ≤ budget := by simpa [fits] using hf
    have e : out.utf8ByteSize = bytesOf out.toList := by
      have := utf8ByteSize_ofList out.toList
      rwa [String.ofList_toList] at this
    omega
  generalize out.toList = cs at hbig
  have h4 : 4 ≤ budget / 2 := by omega
  cases cs with
  | nil => simp [bytesOf] at hbig
  | cons c cs =>
    have hhead : headBytes (budget / 2) (c :: cs) ≠ [] := headBytes_ne_nil h4
    refine ⟨by simpa [excerptCut] using hhead, ?_⟩
    simp only [excerptCut, tailBytes]
    have hsz := headBytes_size (budget / 2) (c :: cs)
    obtain ⟨r, hr⟩ := headBytes_prefix (budget / 2) (c :: cs)
    have hrne : r ≠ [] := by
      rintro rfl
      simp only [List.append_nil] at hr
      rw [← hr] at hbig; omega
    have hdrop : (c :: cs).drop (headBytes (budget / 2) (c :: cs)).length = r := by
      generalize headBytes (budget / 2) (c :: cs) = hd at hr
      rw [← hr, List.drop_left]
    rw [hdrop]
    cases hrev : r.reverse with
    | nil => exact absurd (List.reverse_eq_nil_iff.mp hrev) hrne
    | cons d ds =>
      have := headBytes_ne_nil (c := d) (cs := ds) h4
      simpa using this

/-- The fixed budget leaves room for a character at each end. -/
theorem excerptBytes_room : 8 ≤ excerptBytes := by decide

end VbmContext
