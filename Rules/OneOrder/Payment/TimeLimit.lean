import Rules.Core.Attributes
import Rules.OneOrder.Payment.Status

/-!
# Payment time limits

An order item waiting for payment carries a payment time limit.  When the
limit passes and no successful payment covers the item, the item is removed
and any payment still pending for it fails.
-/

namespace Rules.OneOrder.Payment

open Rules.Core

/-- What happens to an order item's services when its payment time limit
passes unpaid: the service status and the delivery status they take.  The
guide says the item is removed and names no statuses, so the model takes them
as a parameter: a reading of the guide. -/
structure Removal where
  /-- The service status the item's services take. -/
  status : ServiceStatus
  /-- The delivery status the item's services take. -/
  delivery : DeliveryStatus
  deriving DecidableEq, Repr, Inhabited

/-- Whether an order item's payment time limit has passed at an instant with
no SUCCESSFUL payment covering it. -/
def PayableOrder.lapses (o : PayableOrder) (now : Instant) (pi : PayableItem) : Bool :=
  pi.timeLimit.any (· ≤ now) && !isPaid o.payments pi.item.id

/-- An order item removed: every service takes the statuses of the removal. -/
def PayableItem.remove (r : Removal) (pi : PayableItem) : PayableItem :=
  { pi with item := { pi.item with services := pi.item.services.map fun s =>
      { s with status := r.status, delivery := r.delivery } } }

/-- A payment with the transaction of every PENDING method marked FAILED. -/
def Transaction.failPending (p : Transaction) : Transaction :=
  { p with parts := p.parts.map fun m =>
      if m.status = .pending then { m with status := .failed } else m }

/-- EARS: When an order item's payment time limit passes with no SUCCESSFUL
payment covering it, the system shall remove the item and mark FAILED every
PENDING payment that covers it.

Story: As an airline, I want unpaid order items removed when their payment
time limit passes, so that seats and services are not held for customers who
do not pay.

Acceptance criteria:

* ONE-306.1: When an order item's payment time limit has passed and no
  SUCCESSFUL payment covers it, the system shall remove the item.
* ONE-306.2: When an order item is removed at its payment time limit, the
  system shall mark FAILED every PENDING payment that covers it.
* ONE-306.3: If a SUCCESSFUL payment covers an order item, then the system
  shall not remove the item at a payment time limit.
* ONE-306.4: While an order item's payment time limit has not passed, the
  system shall leave the item unchanged.
* ONE-306.5: The system shall not keep an unpaid order item in the order
  indefinitely.
* ONE-306.6: When an order item is removed at its payment time limit, the
  system shall leave none of its services holding value.

A time limit passes at its instant, as an offer expires at its expiry instant.
Which statuses a removed item's services take is a reading of the guide (see
{name}`Removal`). -/
@[ears "ONE-306"]
def expireUnpaid (r : Removal) (now : Instant) (o : PayableOrder) : PayableOrder :=
  { items := o.items.map fun pi => if o.lapses now pi then pi.remove r else pi,
    payments := o.payments.map fun p =>
      if p.status = .pending ∧ o.items.any (fun pi => o.lapses now pi && pi.item.id ∈ p.covers)
      then p.failPending else p }

end Rules.OneOrder.Payment
