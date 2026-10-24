import Lean

/-!
# Attributes

Tags that mark declarations for the review artifact.  The status executable
reads them from the compiled environment.
-/

namespace Rules.Core

open Lean

/-- `@[case]` marks a build-time example: a concrete scenario whose value the
build computes and the review artifact shows. -/
initialize caseAttr : TagAttribute ←
  registerTagAttribute `case "a build-time example shown in the review artifact"

end Rules.Core
