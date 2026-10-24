import Mathlib.Order.Basic
import Mathlib.Order.Lattice

/-!
# Time

Points in time.  All times are UTC.
-/

namespace Rules.Core

/-- A point in time, as whole seconds since 1970-01-01T00:00:00Z.  All times
in the model are UTC; local times are converted at the boundary before they
reach a rule. -/
structure Instant where
  /-- Seconds since the Unix epoch, UTC. -/
  epochSeconds : Nat
  deriving DecidableEq, Repr, Inhabited

namespace Instant

theorem epochSeconds_injective : Function.Injective Instant.epochSeconds := by
  intro a b h
  cases a; cases b
  simp_all

/-- Instants are ordered by when they happen: earlier is smaller. -/
instance : LinearOrder Instant :=
  LinearOrder.lift' Instant.epochSeconds epochSeconds_injective

theorem le_iff (a b : Instant) : a ≤ b ↔ a.epochSeconds ≤ b.epochSeconds := Iff.rfl

theorem lt_iff (a b : Instant) : a < b ↔ a.epochSeconds < b.epochSeconds := Iff.rfl

end Instant

end Rules.Core
