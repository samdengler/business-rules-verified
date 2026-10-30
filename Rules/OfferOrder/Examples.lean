import Rules.Core.Attributes
import Rules.OfferOrder.Accept
import Rules.OfferOrder.Payment

/-!
# Examples

Concrete scenarios the build computes.  Each {attr}`@[case]` declaration is shown in
the review artifact with its computed value, and each {lit}`#guard` fails the build
if that value changes.
-/

namespace Rules.OfferOrder

open Rules.Core

/-- A one-way flight with a checked bag for one passenger: 200.00 USD for the
flight and 45.00 USD for the bag, valid until 2026-10-27 12:00 UTC. -/
def sampleOffer : Offer where
  id := "OFF-1"
  items :=
    [ { id := "OI-1", serviceCode := "FLT", price := ⟨20000, .USD⟩, passenger := ⟨"PAX-1"⟩ },
      { id := "OI-2", serviceCode := "BAG", price := ⟨4500, .USD⟩, passenger := ⟨"PAX-1"⟩ } ]
  expiresAt := ⟨1793102400⟩
  currency := .USD

/-- *Given* the sample offer: a flight at 200.00 USD and a bag at 45.00 USD,
valid until 2026-10-27 12:00 UTC.

*When* the customer accepts it at 11:59 UTC, one minute before expiry.

*Then* an order is created with both items, priced at 245.00 USD. -/
@[case, checks "OO-001.4 OO-001.5"] def acceptBeforeExpiry : Except Rejection Order :=
  accept sampleOffer ⟨sampleOffer.expiresAt.epochSeconds - 60⟩ "ORD-1"

#guard (acceptBeforeExpiry.map (·.price.amount)) == .ok 24500

/-- *Given* the sample offer, valid until 2026-10-27 12:00 UTC.

*When* the customer accepts it at 12:00 UTC, the expiry instant.

*Then* the offer is rejected as expired. -/
@[case, checks "OO-001.1"] def acceptAtExpiry : Except Rejection Order :=
  accept sampleOffer sampleOffer.expiresAt "ORD-2"

#guard acceptAtExpiry == .error .expired

/-- *Given* the sample offer, priced in USD, with the bag priced at 40.00 EUR
instead.

*When* the customer accepts it at 11:59 UTC, before expiry.

*Then* the offer is rejected for mixed currencies. -/
@[case, checks "OO-001.3"] def acceptMixedCurrency : Except Rejection Order :=
  accept
    { sampleOffer with
      items := sampleOffer.items.map fun i =>
        if i.serviceCode = "BAG" then { i with price := ⟨4000, .EUR⟩ } else i }
    ⟨sampleOffer.expiresAt.epochSeconds - 60⟩ "ORD-3"

#guard acceptMixedCurrency == .error .mixedCurrency

/-- *Given* the sample offer with no items.

*When* the customer accepts it at 11:59 UTC, before expiry.

*Then* the offer is rejected as empty. -/
@[case, checks "OO-001.2"] def acceptEmptyOffer : Except Rejection Order :=
  accept { sampleOffer with items := [] } ⟨sampleOffer.expiresAt.epochSeconds - 60⟩ "ORD-4"

#guard acceptEmptyOffer == .error .emptyOffer

/-- The result of delivering a service and then trying to cancel it.  A
missing state means the event was refused. -/
structure DeliveryWalk where
  /-- The state after the deliver event. -/
  afterDeliver : Option DeliveryState
  /-- The state after the cancel event. -/
  afterCancel : Option DeliveryState
  deriving DecidableEq, Repr

/-- *Given* a flight that is ready for delivery.

*When* the passenger flies, and someone then tries to cancel the flight.

*Then* the flight is delivered, and the cancel is refused. -/
@[case, checks "OO-002.1 OO-002.4"] def deliveryWalk : DeliveryWalk :=
  let afterDeliver := step .ready .deliver
  { afterDeliver, afterCancel := afterDeliver.bind (step · .cancel) }

#guard deliveryWalk == { afterDeliver := some .delivered, afterCancel := none }

/-- One row of the delivery transition table: a state, an event, and the state
the event leads to.  A missing state means the event is refused. -/
structure Transition where
  /-- The state before the event. -/
  before : DeliveryState
  /-- The event applied. -/
  event : DeliveryEvent
  /-- The state after the event. -/
  after : Option DeliveryState
  deriving DecidableEq, Repr

/-- *Given* each of the four delivery states.

*When* each of the three delivery events is applied to it.

*Then* deliver and cancel move a ready service, refund moves a cancelled
service, and every other event is refused.  The review document draws this
table as the delivery state diagram. -/
@[case, checks "OO-002.1 OO-002.2 OO-002.3 OO-002.4 OO-002.5"] def transitionTable : List Transition :=
  [DeliveryState.ready, .delivered, .cancelled, .refunded].flatMap fun s =>
    [DeliveryEvent.deliver, .cancel, .refund].map fun e => ⟨s, e, step s e⟩

#guard transitionTable.filter (·.after.isSome) ==
  [⟨.ready, .deliver, some .delivered⟩, ⟨.ready, .cancel, some .cancelled⟩,
   ⟨.cancelled, .refund, some .refunded⟩]
#guard transitionTable.length == 12

/-- One payment of 100.00 USD against an order. -/
def samplePayment : Payment := ⟨"PAY-1", "ORD-1", ⟨10000, .USD⟩⟩

/-- The result of two refunds against one payment. -/
structure DoubleRefund where
  /-- Whether the first refund is accepted. -/
  firstAccepted : Bool
  /-- Whether the second refund is accepted. -/
  secondAccepted : Bool
  /-- The total refunded against the order, in the payment's currency. -/
  totalRefunded : Money
  deriving DecidableEq, Repr

/-- *Given* one payment of 100.00 USD against order ORD-1.

*When* two refunds of 60.00 USD each are requested against that payment.

*Then* each refund is accepted, and together they return 120.00 USD, more than
was paid.  This is the counterexample for {lit}`refunds_le_payments`. -/
@[case, checks "OO-003.2"] def doubleRefund : DoubleRefund :=
  let r1 : Refund := ⟨"REF-1", "PAY-1", ⟨6000, .USD⟩⟩
  let r2 : Refund := ⟨"REF-2", "PAY-1", ⟨6000, .USD⟩⟩
  { firstAccepted := acceptRefund samplePayment r1
    secondAccepted := acceptRefund samplePayment r2
    totalRefunded := ⟨totalRefunded [samplePayment] [r1, r2] "ORD-1", samplePayment.amount.currency⟩ }

#guard doubleRefund == { firstAccepted := true, secondAccepted := true, totalRefunded := ⟨12000, .USD⟩ }

end Rules.OfferOrder
