import Lake
open System Lake DSL

package «vbm-context» where
  leanOptions := #[⟨`warningAsError, true⟩, ⟨`autoImplicit, false⟩]

/-- The library: specification and code, one Lean core. Imports `Init` and itself only (checked by Tier 1). No dependency. -/
@[default_target]
lean_lib VbmContext where
  globs := #[.andSubmodules `VbmContext]

/-- The proofs: may import `Std` and `Lean`; NEVER linked (nothing in `VbmContext` may import it). -/
lean_lib VbmContextProofs where
  globs := #[.andSubmodules `VbmContextProofs]

/-- The conformance checker: runs recorded scenarios through the library and compares them with their expectations. Not part of any export. -/
lean_exe «vbm-context-vectors» where
  srcDir := "vectors"
  root := `Main
