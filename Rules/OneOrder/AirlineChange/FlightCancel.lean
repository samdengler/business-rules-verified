import Rules.Core.Attributes
import Rules.OneOrder.Order
import Rules.OneOrder.Delivery.Moves

/-!
# A flight the airline cancels

When the airline cancels a flight and does not move the customer to another
one, the services on that flight become cancelled with delivery status
UNABLE TO DELIVER.  The worked example changes no order item's status and
offers no refund.  No source says whether the customer is owed money back, or
how much of an item's price belongs to one of its flights, since the price is
set per order item.  The model takes the refund as a parameter, a reading of
the sources.
-/

namespace Rules.OneOrder.AirlineChange

open Rules.Core

/-- What the airline refunds when it cancels a flight and does not move the
customer to another one.  The worked example shows no refund, and no source
says whether one is owed or how much of an item's price belongs to one flight.
The model takes the answer as a parameter: a reading of the sources.  Every
reading refunds no more than the item's price. -/
structure FlightRefund where
  /-- The amount, in minor units of the item's currency, refunded for an order
  item when the airline cancels its services on a flight segment. -/
  refund : OrderItem → String → Nat
  /-- No more than the item's price is refunded. -/
  le_price : ∀ i seg, refund i seg ≤ i.price.amount

/-- Whether a service is live: neither cancelled nor transferred, and not in a
final delivery status. -/
def isLive (s : Service) : Bool :=
  s.status != .cancelled && s.status != .transferred && !Delivery.isFinal s.delivery

/-- A service after the airline cancels a flight: cancelled with delivery
status UNABLE TO DELIVER if it is a live service on that flight, and otherwise
as it was. -/
def cancelOnFlight (seg : String) (s : Service) : Service :=
  if s.segment = seg ∧ isLive s = true then
    { s with status := .cancelled, delivery := .unableToDeliver }
  else s

/-- Whether an order item has a live service on a flight segment. -/
def flies (seg : String) (i : OrderItem) : Bool :=
  i.services.any fun s => s.segment == seg && isLive s

/-- An order after the airline cancels a flight, and the refund for each order
item that had a live service on it. -/
structure FlightCancellation where
  /-- The order afterwards. -/
  order : Order
  /-- Each affected order item's reference and the amount refunded for it. -/
  refunds : List (String × Money)
  deriving DecidableEq, Repr, Inhabited

/-- EARS: When the airline cancels a flight and does not re-accommodate the
customer, the system shall cancel every live service on that flight with
delivery status UNABLE TO DELIVER.

Story: As a customer whose flight the airline cancelled, I want the cancelled
services marked and their value returned, so that I do not pay for a flight
that will not operate.

Acceptance criteria:

* ONE-704.1: When the airline cancels a flight and does not re-accommodate the
  customer, the system shall mark every live service on that flight, in every
  order item, CANCELLED with delivery status UNABLE TO DELIVER.
* ONE-704.2: When the airline cancels a flight, the system shall leave every
  service on other flights unchanged.
* ONE-704.3: When the airline cancels a flight, the system shall keep every
  order item with its reference and price.
* ONE-704.4: If the airline cancels a flight of a paid order item and does not
  re-accommodate the customer, then the system shall refund the customer part
  of the item's price.
* ONE-704.5: When the airline cancels a flight, the system shall mark
  CANCELLED every order item that holds a CANCELLED service.

A service is for one passenger on one flight segment, so the services that
depend on a flight, such as a bag or a seat on it, are services on the same
segment.  How much is refunded is the reading's ({name}`FlightRefund`). -/
@[ears "ONE-704"]
def cancelFlight (r : FlightRefund) (seg : String) (o : Order) : FlightCancellation where
  order := { o with items := o.items.map fun i => { i with services := i.services.map (cancelOnFlight seg) } }
  refunds := (o.items.filter (flies seg)).map fun i => (i.id, ⟨r.refund i seg, i.price.currency⟩)

end Rules.OneOrder.AirlineChange
