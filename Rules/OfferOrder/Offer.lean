import Rules.Core.Money
import Rules.Core.Time
import Rules.Core.Party

/-!
# Offers

An offer is what the airline proposes to sell: a set of priced items for
named passengers, valid until it expires.  It corresponds to the IATA ONE
Order `Offer` and `OfferItem`.
-/

namespace Rules.OfferOrder

open Rules.Core

/-- One priced product inside an offer, for one passenger: a flight, a bag,
a seat.  It corresponds to a ONE Order `OfferItem`. -/
structure OfferItem where
  /-- The offer item reference, unique within its offer. -/
  id : String
  /-- The service the item sells, such as `FLT` (flight), `BAG` (checked bag)
  or `SEAT` (seat selection). -/
  serviceCode : String
  /-- The price the customer pays for this item. -/
  price : Money
  /-- The passenger the item is for. -/
  passenger : Passenger
  deriving DecidableEq, Repr, Inhabited

/-- A set of priced items the airline offers a customer, valid until
`expiresAt`, with every price stated in `currency`.  It corresponds to a
ONE Order `Offer`. -/
structure Offer where
  /-- The offer reference. -/
  id : String
  /-- The items on offer. -/
  items : List OfferItem
  /-- The instant the offer stops being valid.  An offer accepted at or after
  this instant is rejected. -/
  expiresAt : Instant
  /-- The currency the offer is priced in. -/
  currency : Currency
  deriving DecidableEq, Repr, Inhabited

end Rules.OfferOrder
