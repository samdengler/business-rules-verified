import Mathlib.Tactic

/-!
# Money

Amounts of money as the Offer and Order domain uses them: a whole number of
minor units (cents, pence) in one currency.
-/

namespace Rules.Core

/-- The currencies this slice prices offers in, as ISO 4217 codes. -/
inductive Currency
  /-- United States dollar. -/
  | USD
  /-- Euro. -/
  | EUR
  /-- Pound sterling. -/
  | GBP
  deriving DecidableEq, Repr, Inhabited

/-- An amount of money: a non-negative count of minor units (cents for USD and
EUR, pence for GBP) in a single currency.  A price of 125.00 USD is
{lean}`(⟨12500, .USD⟩ : Money)`. -/
structure Money where
  /-- The amount in minor units.  It cannot be negative. -/
  amount : Nat
  /-- The currency the amount is stated in. -/
  currency : Currency
  deriving DecidableEq, Repr, Inhabited

namespace Money

/-- Adds two amounts of money.  The sum exists only when both amounts are in
the same currency; adding a USD amount to a EUR amount gives no answer, so a
mixed-currency total is a visible failure rather than a silent conversion. -/
def add (a b : Money) : Option Money :=
  if a.currency = b.currency then some ⟨a.amount + b.amount, a.currency⟩ else none

/-- Zero in the given currency. -/
def zero (c : Currency) : Money := ⟨0, c⟩

/-- Adding two amounts in the same currency always succeeds, and the result
is the sum of the minor units. -/
theorem add_same_currency (a b : Money) (h : a.currency = b.currency) :
    a.add b = some ⟨a.amount + b.amount, a.currency⟩ := by
  simp [add, h]

end Money

end Rules.Core
