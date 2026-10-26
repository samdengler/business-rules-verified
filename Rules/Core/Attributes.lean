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

/-- {lit}`@[open_question]` marks a theorem left open on purpose because its
proof is waiting on a business decision.  Any other theorem that depends on
{lit}`sorry` fails the status check. -/
initialize openQuestionAttr : TagAttribute ←
  registerTagAttribute `open_question "a theorem left open pending a business decision"

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

/-- {lit}`@[checks "OO-001.1"]` says which acceptance criteria a theorem or an
example checks.  Several IDs are separated by spaces.  The status executable
computes each criterion's status from the declarations that check it. -/
syntax (name := checks) "checks " str : attr

/-- The acceptance criterion IDs attached to a theorem or example by
{lit}`@[checks "..."]`, as written. -/
initialize checksAttr : ParametricAttribute String ←
  registerParametricAttribute {
    name := `checks
    descr := "acceptance criteria checked by a theorem or example"
    getParam := fun _ stx =>
      match stx with
      | `(attr| checks $ids:str) => pure ids.getString
      | _ => throwError "expected @[checks \"<ID> ...\"]"
  }

end Rules.Core
