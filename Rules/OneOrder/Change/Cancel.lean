import Rules.Core.Attributes
import Rules.OfferOrder.Payment
import Rules.OneOrder.Change.Differential

/-!
# Cancelling an order

A seller cancels an order that has no payment at once.  An order with any
payment, full or partial, is cancelled only by accepting a cancellation offer
from the airline, priced like a change whose new price is zero.
-/

namespace Rules.OneOrder.Change

open Rules.Core

/-- The order with every service cancelled and removed, keeping no value.
This is a cancellation made at once, with no offer. -/
def cancelDirect (o : Order) : Order :=
  { o with items := o.items.map fun i =>
      { i with services := i.services.map fun s => { s with status := .cancelled, delivery := .removed } } }

/-- The total price of an order's items, when all of them are priced in the
currency given. -/
def orderPrice (o : Order) (c : Currency) : Option Money :=
  if o.items.all (·.price.currency == c) then some ⟨(o.items.map (·.price.amount)).sum, c⟩ else none

/-- The airline's terms for cancelling an order. -/
structure CancelTerms where
  /-- The cancellation penalty. -/
  penalty : Money
  /-- The part of the order's price the airline keeps. -/
  forfeited : Money
  /-- Whether the penalty is netted or charged separately. -/
  handling : PenaltyHandling
  /-- How the airline settles money it owes. -/
  settlement : Settlement
  deriving DecidableEq, Repr, Inhabited

/-- The cancellation of a whole order as a change to price: the old price is
the order's price, in the penalty's currency, and the new price is zero. -/
def cancellationQuote (o : Order) (t : CancelTerms) : Option ChangeQuote :=
  (orderPrice o t.penalty.currency).map fun p =>
    { oldPrice := p, newPrice := ⟨0, p.currency⟩, penalty := t.penalty, forfeited := t.forfeited,
      handling := t.handling, settlement := t.settlement }

/-- What a request to cancel an order leads to. -/
inductive CancelOutcome
  /-- The order is cancelled at once; this is the order afterwards. -/
  | cancelled (o : Order)
  /-- The order needs a cancellation offer; this is its price differential. -/
  | offer (d : PriceDifferential)
  /-- The cancellation could not be priced. -/
  | rejected (r : QuoteRejection)
  deriving DecidableEq, Repr

/-- EARS: When a seller asks to cancel an order, the system shall cancel it at
once if no payment has been received for it, and otherwise only through a
cancellation offer.

Story: As a seller, I want an unpaid order cancelled at once and a paid order
cancelled through an offer, so that every cancellation that returns money is
priced first.

Acceptance criteria:

* ONE-203.1: When a seller asks to cancel an order for which no payment has
  been received, the system shall cancel and remove every service of the order
  at once.
* ONE-203.2: When an order is cancelled at once, the system shall mark each of
  its items cancelled and the order closed.
* ONE-203.3: If a seller asks to cancel an order for which any payment has been
  received, then the system shall cancel it only through a cancellation offer.
* ONE-203.4: When an order with payments is cancelled through an offer, the
  system shall not make the amount due by the airline larger than the payments
  received for the order.

The payments received are the pilot model's payments for the order
({name}`Rules.OfferOrder.totalPaid`).  The offer is priced from the order's
price, as in the worked examples, with {name}`priceDifferential`. -/
@[ears "ONE-203"]
def requestCancellation (r : ExcessPenalty) (o : Order) (payments : List Rules.OfferOrder.Payment)
    (t : CancelTerms) : CancelOutcome :=
  if Rules.OfferOrder.totalPaid payments o.id = 0 then .cancelled (cancelDirect o)
  else
    match cancellationQuote o t with
    | none => .rejected .mixedCurrency
    | some q =>
      match priceDifferential r q with
      | .ok d => .offer d
      | .error e => .rejected e

end Rules.OneOrder.Change
