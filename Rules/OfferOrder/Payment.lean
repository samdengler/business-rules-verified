import Rules.Core.Attributes
import Rules.Core.Money

/-!
# Payments and refunds

Money received against an order, and money returned against a payment.
-/

namespace Rules.OfferOrder

open Rules.Core

/-- Money received from the customer against an order. -/
structure Payment where
  /-- The payment reference. -/
  id : String
  /-- The order the payment is for. -/
  order : String
  /-- The amount received. -/
  amount : Money
  deriving DecidableEq, Repr, Inhabited

/-- Money returned to the customer against one payment. -/
structure Refund where
  /-- The refund reference. -/
  id : String
  /-- The payment the refund is made against. -/
  payment : String
  /-- The amount returned. -/
  amount : Money
  deriving DecidableEq, Repr, Inhabited

/-- The total amount, in minor units, received in the payments for an
order. -/
def totalPaid (ps : List Payment) (orderId : String) : Nat :=
  ((ps.filter (·.order == orderId)).map (·.amount.amount)).sum

/-- The total amount, in minor units, returned in refunds made against the
payments for an order. -/
def totalRefunded (ps : List Payment) (rs : List Refund) (orderId : String) : Nat :=
  let paymentIds := (ps.filter (·.order == orderId)).map (·.id)
  ((rs.filter (fun r => paymentIds.contains r.payment)).map (·.amount.amount)).sum

/-- EARS: When a refund is requested against a payment, the system shall accept it
only if the refund amount does not exceed that payment's amount.

The check looks at this one refund and this one payment; it does not look at
refunds already made against the same payment. -/
@[ears "OO-003"]
def acceptRefund (p : Payment) (r : Refund) : Bool :=
  r.payment == p.id && decide (r.amount.amount ≤ p.amount.amount)

end Rules.OfferOrder
