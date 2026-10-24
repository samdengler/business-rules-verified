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

/-- A two-item offer accepted one minute before expiry creates an order
priced at the sum of the items: 245.00 USD. -/
@[case] def acceptBeforeExpiry : Except Rejection Order :=
  accept sampleOffer ⟨sampleOffer.expiresAt.epochSeconds - 60⟩ "ORD-1"

#guard (acceptBeforeExpiry.map (·.price.amount)) == .ok 24500

/-- The same offer accepted at the expiry instant is rejected as expired. -/
@[case] def acceptAtExpiry : Except Rejection Order :=
  accept sampleOffer sampleOffer.expiresAt "ORD-2"

#guard acceptAtExpiry == .error .expired

/-- An offer priced in USD whose bag is priced in EUR is rejected for mixed
currencies, even though it has not expired. -/
@[case] def acceptMixedCurrency : Except Rejection Order :=
  accept
    { sampleOffer with
      items := sampleOffer.items.map fun i =>
        if i.serviceCode = "BAG" then { i with price := ⟨4000, .EUR⟩ } else i }
    ⟨sampleOffer.expiresAt.epochSeconds - 60⟩ "ORD-3"

#guard acceptMixedCurrency == .error .mixedCurrency

/-- An offer with no items is rejected as empty, even though it has not
expired. -/
@[case] def acceptEmptyOffer : Except Rejection Order :=
  accept { sampleOffer with items := [] } ⟨sampleOffer.expiresAt.epochSeconds - 60⟩ "ORD-4"

#guard acceptEmptyOffer == .error .emptyOffer

/-- A flight is delivered (the passenger flew), and a later attempt to cancel
it is refused.  The pair is the state after delivery and the result of the
cancel. -/
@[case] def deliveryWalk : Option DeliveryState × Option DeliveryState :=
  let afterDeliver := step .ready .deliver
  (afterDeliver, afterDeliver.bind (step · .cancel))

#guard deliveryWalk == (some .delivered, none)

/-- One payment of 100.00 USD against an order. -/
def samplePayment : Payment := ⟨"PAY-1", "ORD-1", ⟨10000, .USD⟩⟩

/-- Two refunds of 60.00 USD against one payment of 100.00 USD are each
accepted, and together return 120.00 USD, more than was paid.  The triple is
whether the first refund is accepted, whether the second is accepted, and the
total refunded.  Counterexample for {lit}`refunds_le_payments`. -/
@[case] def doubleRefund : Bool × Bool × Nat :=
  let r1 : Refund := ⟨"REF-1", "PAY-1", ⟨6000, .USD⟩⟩
  let r2 : Refund := ⟨"REF-2", "PAY-1", ⟨6000, .USD⟩⟩
  (acceptRefund samplePayment r1, acceptRefund samplePayment r2,
    totalRefunded [samplePayment] [r1, r2] "ORD-1")

#guard doubleRefund == (true, true, 12000)

end Rules.OfferOrder
