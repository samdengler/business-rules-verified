import Mathlib.Order.Basic
import Mathlib.Order.Lattice

/-!
# Classification

Data classification levels.  This is a placeholder for the Data Governance
namespace, which will attach a level to each data product field.
-/

namespace Rules.Core

/-- How sensitive a piece of data is, from least to most sensitive:
public, internal, confidential, restricted. -/
inductive Classification
  /-- Anyone may see it. -/
  | «public»
  /-- Employees and contractors may see it. -/
  | internal
  /-- Only people with a business need may see it. -/
  | confidential
  /-- Only named people may see it. -/
  | restricted
  deriving DecidableEq, Repr, Inhabited

namespace Classification

/-- The position of a level in the order public, internal, confidential,
restricted, starting at 0. -/
def rank : Classification → Nat
  | .«public» => 0
  | .internal => 1
  | .confidential => 2
  | .restricted => 3

theorem rank_injective : Function.Injective rank := by
  intro a b h
  cases a <;> cases b <;> first | rfl | (simp [rank] at h)

/-- Levels are ordered by sensitivity: public is lowest, restricted is
highest. -/
instance : LinearOrder Classification :=
  LinearOrder.lift' rank rank_injective

/-- Public is the lowest level: every level is at least as sensitive as
public. -/
theorem public_le : ∀ c : Classification, Classification.«public» ≤ c := by
  intro c
  change rank .«public» ≤ rank c
  simp [rank]

end Classification

end Rules.Core
