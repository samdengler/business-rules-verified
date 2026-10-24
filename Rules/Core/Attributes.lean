import Lean

/-!
# Attributes

Tags that mark declarations for the review artifact.  The status executable
reads them from the compiled environment.
-/

namespace Rules.Core

open Lean

/-- {lit}`@[case]` marks a build-time example: a concrete scenario whose value the
build computes and the review artifact shows. -/
initialize caseAttr : TagAttribute ←
  registerTagAttribute `case "a build-time example shown in the review artifact"

/-- {lit}`@[ears "OO-001"]` gives a rule its stable EARS requirement ID.  IDs are
assigned by this attribute, not by position, so adding a rule never renumbers
the others. -/
syntax (name := ears) "ears " str : attr

/-- The EARS requirement ID attached to a rule by {lit}`@[ears "..."]`. -/
initialize earsAttr : ParametricAttribute String ←
  registerParametricAttribute {
    name := `ears
    descr := "stable EARS requirement ID for a rule"
    getParam := fun _ stx =>
      match stx with
      | `(attr| ears $id:str) => pure id.getString
      | _ => throwError "expected @[ears \"<ID>\"]"
  }

end Rules.Core
