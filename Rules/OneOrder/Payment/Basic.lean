import Rules.Core.Money
import Rules.Core.Time
import Rules.OneOrder.Order

/-!
# Payments and payable items

ONE Order payments as IATA's public implementation guide describes them.  A
payment covers one or more order items and is made with one or more payment
methods.  Each method has its own transaction, with a requested amount, a
surcharge and an outcome.  An order item waiting for payment carries a payment
time limit.
-/

namespace Rules.OneOrder.Payment

open Rules.Core

/-- The status of a payment transaction.  It corresponds to the ONE Order
payment status. -/
inductive PaymentStatus
  /-- The airline cannot yet tell whether it will collect the funds, for example
  while the customer completes a redirected payment. -/
  | pending
  /-- The airline is certain to collect the funds. -/
  | successful
  /-- The airline knows it will not collect the funds. -/
  | failed
  deriving DecidableEq, Repr, Inhabited

/-- The payment methods the model distinguishes. -/
inductive Method
  /-- A payment card. -/
  | card
  /-- A settlement plan, such as the IATA settlement plans. -/
  | settlementPlan
  /-- Cash. -/
  | cash
  /-- A commitment to pay when no amount is due.  Its amount is always zero. -/
  | commitment
  deriving DecidableEq, Repr, Inhabited

/-- One payment method's part of a payment: its own transaction, the amount
requested from it, the surcharge the airline adds for the method, and the
outcome of its transaction. -/
structure MethodPart where
  /-- The reference of this method's transaction. -/
  id : String
  /-- The payment method. -/
  method : Method
  /-- The amount requested from this method, before its surcharge. -/
  requested : Money
  /-- The surcharge for this method and amount. -/
  surcharge : Money
  /-- The outcome of this method's transaction. -/
  status : PaymentStatus
  deriving DecidableEq, Repr, Inhabited

/-- One payment transaction: the order items it covers, its currency, and the
payment methods it uses.  It corresponds to a ONE Order payment. -/
structure Transaction where
  /-- The payment reference. -/
  id : String
  /-- The references of the order items the payment covers. -/
  covers : List String
  /-- The currency of the payment. -/
  currency : Currency
  /-- The payment methods, each with its own transaction. -/
  parts : List MethodPart
  deriving DecidableEq, Repr, Inhabited

/-- An order item as the payment rules see it: the item, and its payment time
limit if it has one. -/
structure PayableItem where
  /-- The order item, with its price and services. -/
  item : OrderItem
  /-- The instant by which the item must be paid, if the airline gave one. -/
  timeLimit : Option Instant
  deriving DecidableEq, Repr, Inhabited

/-- An order as the payment rules see it: its items with their payment time
limits, and the payments made for it. -/
structure PayableOrder where
  /-- The order's items, each with its payment time limit. -/
  items : List PayableItem
  /-- The payments made for the order. -/
  payments : List Transaction
  deriving DecidableEq, Repr, Inhabited

/-- The total of the amounts requested from a payment's methods, in minor
units, before surcharges. -/
def Transaction.requestedTotal (p : Transaction) : Nat :=
  (p.parts.map (·.requested.amount)).sum

/-- The total of the surcharges on a payment's methods, in minor units. -/
def Transaction.surchargeTotal (p : Transaction) : Nat :=
  (p.parts.map (·.surcharge.amount)).sum

/-- The order's items that a payment covers. -/
def PayableOrder.coveredBy (o : PayableOrder) (p : Transaction) : List PayableItem :=
  o.items.filter (fun pi => pi.item.id ∈ p.covers)

/-- The total price of some order items, in minor units. -/
def priceTotal (items : List PayableItem) : Nat :=
  (items.map (·.item.price.amount)).sum

end Rules.OneOrder.Payment
