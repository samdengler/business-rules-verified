import Rules.Core.Attributes
import Rules.OfferOrder.Offer
import Rules.OfferOrder.Order

/-!
# Accepting an offer

The decision that turns an offer into an order, or rejects it with a reason.
-/

namespace Rules.OfferOrder

open Rules.Core

/-- Why an offer could not be accepted. -/
inductive Rejection
  /-- The offer was accepted at or after its expiry instant. -/
  | expired
  /-- The offer has no items. -/
  | emptyOffer
  /-- At least one item is priced in a currency other than the offer's. -/
  | mixedCurrency
  deriving DecidableEq, Repr, Inhabited

/-- The order item created when an offer item is bought.  It starts ready for
delivery at the offer item's price. -/
def toOrderItem (orderId : String) (i : OfferItem) : OrderItem where
  id := orderId ++ "-" ++ i.id
  fromOfferItem := i.id
  price := i.price
  delivery := .ready

/-- EARS: When a customer accepts an offer, the system shall create an order
only if the offer has not expired and contains at least one item.

The checks run in order: expiry first, then an empty offer, then items priced
in a currency other than the offer's.  The order's price is the sum of the
item prices, in the offer's currency. -/
@[ears "OO-001"]
def accept (o : Offer) (now : Instant) (orderId : String) : Except Rejection Order :=
  if now ≥ o.expiresAt then .error .expired
  else if o.items.isEmpty then .error .emptyOffer
  else if o.items.any (·.price.currency != o.currency) then .error .mixedCurrency
  else .ok
    { id := orderId
      fromOffer := o.id
      items := o.items.map (toOrderItem orderId)
      price := ⟨(o.items.map (·.price.amount)).sum, o.currency⟩
      createdAt := now }

end Rules.OfferOrder
