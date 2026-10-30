import Rules.Core.Attributes
import Rules.OneOrder.Examples
import Rules.OneOrder.Change.Cancel
import Rules.OneOrder.Creation.Create
import Rules.OneOrder.Creation.Repeat
import Rules.OneOrder.Creation.Version
import Rules.OneOrder.Creation.Retention

/-!
# Examples of order creation, versions and retention

Concrete create requests, order histories and retention checks the build
computes.  The offers, orders and references are our own.
-/

namespace Rules.OneOrder.Creation

open Rules.Core

/-- An amount in whole euros. -/
def eur (n : Nat) : Money := ⟨n * 100, .EUR⟩

/-- An amount in whole US dollars. -/
def usd (n : Nat) : Money := ⟨n * 100, .USD⟩

/-- The instant the example offers expire: 2026-10-27 12:00 UTC. -/
def noon : Instant := ⟨1793102400⟩

/-- The instant of the example requests: 2026-10-27 11:30 UTC. -/
def halfPastEleven : Instant := ⟨1793100600⟩

/-- An offer item for the first passenger on the outbound segment. -/
def itemOf (id : String) (price : Money) : OfferItem :=
  { id, price, passengers := [⟨"PAX-1"⟩], segments := ["SEG-OUT"] }

/-- A one-way trip valid until noon: a flight at 400.00 EUR, which the offer
marks mandatory, and an optional bag at 40.00 EUR and seat at 25.00 EUR. -/
def tripOffer : MarkedOffer :=
  { offer := { id := "OFF-A", expiresAt := noon, currency := .EUR,
               items := [itemOf "OI-FLT" (eur 400), itemOf "OI-BAG" (eur 40), itemOf "OI-SEAT" (eur 25)] },
    mandatory := ["OI-FLT"] }

/-- A return flight at 380.00 EUR that expired at 11:00 UTC. -/
def returnOffer : MarkedOffer :=
  { offer := { id := "OFF-B", expiresAt := ⟨noon.epochSeconds - 3600⟩, currency := .EUR,
               items := [itemOf "OI-RET" (eur 380)] },
    mandatory := ["OI-RET"] }

/-- An a la carte offer valid until noon: a flight at 400.00 EUR and a seat at
25.00 EUR, neither marked mandatory. -/
def aLaCarteOffer : MarkedOffer :=
  { offer := { id := "OFF-C", expiresAt := noon, currency := .EUR,
               items := [itemOf "OI-FLT" (eur 400), itemOf "OI-SEAT" (eur 25)] },
    mandatory := [] }

/-- A hotel transfer at 60.00 USD, valid until noon and priced in US dollars. -/
def transferOffer : MarkedOffer :=
  { offer := { id := "OFF-D", expiresAt := noon, currency := .USD,
               items := [itemOf "OI-TRF" (usd 60)] },
    mandatory := ["OI-TRF"] }

/-- The offers the airline holds in the examples. -/
def heldOffers : List MarkedOffer := [tripOffer, returnOffer, aLaCarteOffer, transferOffer]

/-! ## Selecting offer items -/

/-- One selection from an offer and what the rule made of it. -/
structure SelectionRow where
  /-- The offer item references selected. -/
  selected : List String
  /-- The offer items taken into the order. -/
  taken : List String
  /-- Why the selection was rejected, if it was. -/
  rejection : Option CreateRejection
  deriving DecidableEq, Repr

/-- Select items from an offer and show the result. -/
def SelectionRow.of (o : MarkedOffer) (sel : List String) : SelectionRow :=
  match selectItems o sel with
  | .ok items => { selected := sel, taken := items.map (·.id), rejection := none }
  | .error e => { selected := sel, taken := [], rejection := some e }

/-- *Given* the trip offer: a flight the offer marks mandatory, and an optional
bag and seat.

*When* a seller selects the flight and the seat, then the bag alone, then the
flight and a meal the offer does not hold.

*Then* the flight and the seat are taken.  The bag alone is rejected because
the flight is missing.  The meal is rejected as an item the offer does not
hold. -/
@[case, checks "ONE-401.1 ONE-401.2 ONE-401.3"]
def selectingFromTrip : List SelectionRow :=
  [.of tripOffer ["OI-FLT", "OI-SEAT"], .of tripOffer ["OI-BAG"], .of tripOffer ["OI-FLT", "OI-MEAL"]]

#guard selectingFromTrip ==
  [{ selected := ["OI-FLT", "OI-SEAT"], taken := ["OI-FLT", "OI-SEAT"], rejection := none },
   { selected := ["OI-BAG"], taken := [], rejection := some (.missingMandatory "OFF-A" "OI-FLT") },
   { selected := ["OI-FLT", "OI-MEAL"], taken := [], rejection := some (.unknownItem "OFF-A" "OI-MEAL") }]

/-- A selection next to the items its offer marks mandatory. -/
structure MandatoryCheck where
  /-- The items the offer marks mandatory. -/
  mandatoryItems : List String
  /-- The offer items taken into the order. -/
  taken : List String
  /-- Whether an item the offer marks mandatory was taken. -/
  mandatoryTaken : Bool
  deriving DecidableEq, Repr

/-- *Given* an a la carte offer with a flight and a seat, neither marked
mandatory.

*When* a seller selects the seat alone.

*Then* the selection is accepted, and the order would hold a seat with no
flight.  No item the offer marks mandatory is taken, because it marks none. -/
@[case, checks "ONE-401.4"]
def seatWithoutFlight : Except CreateRejection MandatoryCheck :=
  (selectItems aLaCarteOffer ["OI-SEAT"]).map fun items =>
    { mandatoryItems := aLaCarteOffer.mandatory, taken := items.map (·.id),
      mandatoryTaken := items.any (aLaCarteOffer.mandatory.contains ·.id) }

#guard seatWithoutFlight == .ok { mandatoryItems := [], taken := ["OI-SEAT"], mandatoryTaken := false }

/-! ## Creating an order from several offers -/

/-- What a create request produced: each order item's reference, the offer
item it came from, and the order's total in the euro. -/
structure CreatedSummary where
  /-- Each order item's reference. -/
  itemRefs : List String
  /-- The offer item each order item came from. -/
  fromOfferItems : List String
  /-- The order's total in euros, if every item is priced in euros. -/
  total : Option Money
  deriving DecidableEq, Repr

/-- Summarise a created order. -/
def CreatedSummary.of (o : Order) : CreatedSummary :=
  { itemRefs := o.items.map (·.id), fromOfferItems := o.items.map (·.fromOfferItem),
    total := Change.orderPrice o .EUR }

/-- *Given* the trip offer: a flight at 400.00 EUR, a bag at 40.00 EUR and a
seat at 25.00 EUR, valid until 12:00 UTC.

*When* a seller sends a create request at 11:30 UTC for the flight and the
seat, leaving out the bag.

*Then* the order holds two items, the flight and the seat, and no bag.  Its
total is 425.00 EUR, the price of the flight and the seat. -/
@[case, checks "ONE-402.1 ONE-402.2"]
def tripWithoutBag : Except CreateRejection CreatedSummary :=
  (createOrder heldOffers [⟨"OFF-A", ["OI-FLT", "OI-SEAT"]⟩] halfPastEleven "ORD-1").map .of

#guard tripWithoutBag ==
  .ok { itemRefs := ["ORD-1-OFF-A-OI-FLT", "ORD-1-OFF-A-OI-SEAT"], fromOfferItems := ["OI-FLT", "OI-SEAT"],
        total := some (eur 425) }

/-- *Given* the trip offer, valid until 12:00 UTC, and a return flight offer
that expired at 11:00 UTC.

*When* a seller sends one create request at 11:30 UTC for the outbound flight
of the first offer and the return flight of the second.

*Then* the whole request is rejected because the return offer has expired.
No order is created for the outbound flight alone. -/
@[case, checks "ONE-402.3"]
def oneOfferExpired : Except CreateRejection CreatedSummary :=
  (createOrder heldOffers [⟨"OFF-A", ["OI-FLT"]⟩, ⟨"OFF-B", ["OI-RET"]⟩] halfPastEleven "ORD-2").map .of

#guard oneOfferExpired == .error (.expired "OFF-B")

/-- *Given* the a la carte offer, which marks no item mandatory.

*When* a seller sends a create request that selects nothing from it.

*Then* the request is rejected, since the order would hold no item. -/
@[case, checks "ONE-402.4"]
def nothingSelected : Except CreateRejection CreatedSummary :=
  (createOrder heldOffers [⟨"OFF-C", []⟩] halfPastEleven "ORD-3").map .of

#guard nothingSelected == .error .noItems

/-- An order's total in one currency. -/
structure TotalRow where
  /-- The currency. -/
  currency : Currency
  /-- The order's total in that currency, if every item is priced in it. -/
  total : Option Money
  deriving DecidableEq, Repr

/-- An order item and its price. -/
structure PricedItem where
  /-- The order item's reference. -/
  item : String
  /-- The price of the item. -/
  price : Money
  deriving DecidableEq, Repr

/-- An order's items with their prices, and its total in each currency. -/
structure TotalsCase where
  /-- The order items and their prices. -/
  items : List PricedItem
  /-- The order's total in each currency. -/
  totals : List TotalRow
  deriving DecidableEq, Repr

/-- *Given* the trip offer, priced in euros, and a hotel transfer offer at
60.00 USD, priced in US dollars.  Both are valid until 12:00 UTC.

*When* a seller sends one create request at 11:30 UTC for the flight and the
transfer.

*Then* the order is created with a flight at 400.00 EUR and a transfer at
60.00 USD.  It has no total in any currency. -/
@[case, checks "ONE-402.5"]
def twoCurrencies : Except CreateRejection TotalsCase :=
  (createOrder heldOffers [⟨"OFF-A", ["OI-FLT"]⟩, ⟨"OFF-D", ["OI-TRF"]⟩] halfPastEleven "ORD-4").map fun o =>
    { items := o.items.map fun i => { item := i.id, price := i.price },
      totals := [Currency.EUR, .USD, .GBP].map fun c => { currency := c, total := Change.orderPrice o c } }

#guard twoCurrencies ==
  .ok { items := [{ item := "ORD-4-OFF-A-OI-FLT", price := eur 400 },
                  { item := "ORD-4-OFF-D-OI-TRF", price := usd 60 }],
        totals := [{ currency := .EUR, total := none }, { currency := .USD, total := none },
                   { currency := .GBP, total := none }] }

/-! ## Repeated create requests -/

/-- One create request and how the airline answered it. -/
structure RepeatRow where
  /-- Which request this is. -/
  request : String
  /-- The airline's reading of the guide for repeated requests. -/
  handling : RepeatHandling
  /-- The reference of the order in the answer, if any. -/
  answer : Option String
  /-- Why the request was rejected, if it was. -/
  rejection : Option CreateRejection
  /-- How many recorded orders came from the trip offer afterwards. -/
  ordersFromOffer : Nat
  deriving DecidableEq, Repr

/-- The request for the trip's flight, as the seller sends it and sends it
again. -/
def tripRequest : List Selection := [⟨"OFF-A", ["OI-FLT"]⟩]

/-- Send the trip request with the airline's record given and show the
answer. -/
def RepeatRow.of (request : String) (h : RepeatHandling) (book : List CreatedOrder) (orderId : String) :
    RepeatRow :=
  match createOnce h book heldOffers tripRequest halfPastEleven orderId with
  | .ok (o, book') =>
    { request, handling := h, answer := some o.id, rejection := none,
      ordersFromOffer := (book'.filter (·.offers.contains "OFF-A")).length }
  | .error e =>
    { request, handling := h, answer := none, rejection := some e,
      ordersFromOffer := (book.filter (·.offers.contains "OFF-A")).length }

/-- The airline's record after the first trip request. -/
def bookAfterFirst : List CreatedOrder :=
  match createOnce .reject [] heldOffers tripRequest halfPastEleven "ORD-5" with
  | .ok (_, book) => book
  | .error _ => []

/-- *Given* the trip offer, and no order created from it yet.

*When* a seller sends a create request for the flight, the request times out
at the seller, and the seller sends it again.

*Then* the first request creates order ORD-5 and records it against the trip
offer.  The repeated request is answered with ORD-5 where the airline returns
the existing order, and rejected where it rejects repeated requests.  Where
the airline creates another order, the seller gets ORD-6 and the trip offer
has produced two orders. -/
@[case, checks "ONE-403.1 ONE-403.2 ONE-403.3 ONE-403.4"]
def repeatedRequest : List RepeatRow :=
  [.of "first request" .reject [] "ORD-5",
   .of "same request again" .returnExisting bookAfterFirst "ORD-6",
   .of "same request again" .reject bookAfterFirst "ORD-6",
   .of "same request again" .createAgain bookAfterFirst "ORD-6"]

#guard repeatedRequest ==
  [{ request := "first request", handling := .reject, answer := some "ORD-5", rejection := none,
     ordersFromOffer := 1 },
   { request := "same request again", handling := .returnExisting, answer := some "ORD-5", rejection := none,
     ordersFromOffer := 1 },
   { request := "same request again", handling := .reject, answer := none,
     rejection := some (.offerUsed "ORD-5"), ordersFromOffer := 1 },
   { request := "same request again", handling := .createAgain, answer := some "ORD-6", rejection := none,
     ordersFromOffer := 2 }]

/-! ## Order versions and history -/

/-- An order item for the first passenger on the outbound segment, with one
service in the delivery status given.  The service is cancelled if it was
removed, and confirmed otherwise. -/
def orderItemOf (id : String) (price : Money) (delivery : DeliveryStatus) : OrderItem :=
  { id, fromOfferItem := id, price,
    services := [{ id := id ++ "-SVC", passenger := ⟨"PAX-1"⟩, segment := "SEG-OUT",
                   status := if delivery = .removed ∨ delivery = .removedHoldValue then .cancelled
                     else .confirmed,
                   delivery }] }

/-- The trip order as created: a flight and a seat, waiting for payment. -/
def tripOrder : Order :=
  { id := "ORD-7", createdAt := halfPastEleven,
    items := [orderItemOf "ITEM-FLT" (eur 400) .confirmed, orderItemOf "ITEM-SEAT" (eur 25) .confirmed] }

/-- The first change group: a bag is added. -/
def addBag : ChangeGroup := ⟨[.add (orderItemOf "ITEM-BAG" (eur 40) .confirmed)]⟩

/-- The second change group: the seat is cancelled. -/
def cancelSeat : ChangeGroup := ⟨[.replace (orderItemOf "ITEM-SEAT" (eur 25) .removed)]⟩

/-- An order at one version. -/
structure VersionRow where
  /-- The version. -/
  version : Nat
  /-- The order items' references. -/
  items : List String
  /-- The order items that are active, under the strict reading. -/
  activeItems : List String
  /-- How many change groups the history holds. -/
  groupsInHistory : Nat
  deriving DecidableEq, Repr

/-- Show an order record at its current version. -/
def VersionRow.of (r : OrderRecord) : VersionRow :=
  { version := r.version, items := r.current.items.map (·.id),
    activeItems := (r.current.items.filter (·.isActive strictReading)).map (·.id),
    groupsInHistory := r.groups.length }

/-- An order's versions and the labels of its history under both readings. -/
structure VersionedOrder where
  /-- The order at each version. -/
  versions : List VersionRow
  /-- The versions the history labels its groups with, listed oldest first. -/
  oldestFirst : List Nat
  /-- The versions the history labels its groups with, listed newest first. -/
  newestFirst : List Nat
  deriving DecidableEq, Repr

/-- *Given* the trip order as created, with a flight and a seat.

*When* the airline adds a bag, then cancels the seat, in two change groups.

*Then* the order is at version 1 when created, 2 after the bag and 3 after
the seat.  Its history holds the two groups, labelled 2 and 3, listed oldest
first or newest first as the reading says. -/
@[case, checks "ONE-404.1 ONE-404.2 ONE-404.3 ONE-404.4"]
def versionsOfTrip : VersionedOrder :=
  let r := OrderRecord.after tripOrder [addBag, cancelSeat]
  { versions := [.of (.after tripOrder []), .of (.after tripOrder [addBag]), .of r],
    oldestFirst := (orderHistory .oldestFirst r).entries.map (·.version),
    newestFirst := (orderHistory .newestFirst r).entries.map (·.version) }

#guard versionsOfTrip ==
  { versions :=
      [{ version := 1, items := ["ITEM-FLT", "ITEM-SEAT"], activeItems := ["ITEM-FLT", "ITEM-SEAT"],
         groupsInHistory := 0 },
       { version := 2, items := ["ITEM-FLT", "ITEM-SEAT", "ITEM-BAG"],
         activeItems := ["ITEM-FLT", "ITEM-SEAT", "ITEM-BAG"], groupsInHistory := 1 },
       { version := 3, items := ["ITEM-FLT", "ITEM-SEAT", "ITEM-BAG"],
         activeItems := ["ITEM-FLT", "ITEM-BAG"], groupsInHistory := 2 }],
    oldestFirst := [2, 3], newestFirst := [3, 2] }

/-- The order a seller rebuilds from a history listed one way. -/
structure RebuildRow where
  /-- How the history lists its change groups. -/
  listing : HistoryListing
  /-- The order items of the rebuilt order. -/
  rebuilt : List String
  /-- Whether the rebuilt order is the order as it is now. -/
  matchesCurrent : Bool
  deriving DecidableEq, Repr

/-- An order as it is now, next to the orders rebuilt from its history. -/
structure RebuildCase where
  /-- The order items of the order as it is now. -/
  current : List String
  /-- The order rebuilt under each reading. -/
  rebuilds : List RebuildRow
  deriving DecidableEq, Repr

/-- The third change group: the bag is removed. -/
def removeBag : ChangeGroup := ⟨[.remove "ITEM-BAG"]⟩

/-- *Given* the trip order, to which the airline added a bag at version 2 and
from which it removed the bag at version 3.

*When* a seller asks for the order's history and applies its change groups to
the order at version 1, in the order listed.

*Then* listed oldest first, the rebuilt order is the order as it is now, with
a flight and a seat.  Listed newest first, the removal runs before the bag
was added, and the bag comes back. -/
@[case, checks "ONE-404.5"]
def newestFirstHistory : RebuildCase :=
  let r := OrderRecord.after tripOrder [addBag, removeBag]
  { current := r.current.items.map (·.id),
    rebuilds := [HistoryListing.oldestFirst, .newestFirst].map fun l =>
      { listing := l, rebuilt := (orderHistory l r).rebuild.items.map (·.id),
        matchesCurrent := (orderHistory l r).rebuild == r.current } }

#guard newestFirstHistory ==
  { current := ["ITEM-FLT", "ITEM-SEAT"],
    rebuilds :=
      [{ listing := .oldestFirst, rebuilt := ["ITEM-FLT", "ITEM-SEAT"], matchesCurrent := true },
       { listing := .newestFirst, rebuilt := ["ITEM-FLT", "ITEM-SEAT", "ITEM-BAG"], matchesCurrent := false }] }

/-! ## Changes against a stale version -/

/-- One change request and how the airline answered it. -/
structure StaleRow where
  /-- Which request this is. -/
  request : String
  /-- The airline's reading of the guide for a version that is not current. -/
  handling : StaleHandling
  /-- The order's version after the request, if the change was applied. -/
  versionAfter : Option Nat
  /-- Why the change was rejected, if it was. -/
  rejection : Option VersionRejection
  deriving DecidableEq, Repr

/-- Send a change request and show the answer. -/
def StaleRow.of (request : String) (s : StaleHandling) (r : OrderRecord) (seen : Option Nat)
    (g : ChangeGroup) : StaleRow :=
  match requestChange s r seen g with
  | .ok r' => { request, handling := s, versionAfter := some r'.version, rejection := none }
  | .error e => { request, handling := s, versionAfter := none, rejection := some e }

/-- The trip order at version 3, after the bag was added and the seat
cancelled. -/
def tripAtThree : OrderRecord := OrderRecord.after tripOrder [addBag, cancelSeat]

/-- The trip order at version 4, after the first seller removed the bag. -/
def tripAtFour : OrderRecord := recordChanges tripAtThree removeBag

/-- *Given* the trip order at version 3, which two sellers have both read.

*When* the first seller sends a change carrying version 3, which removes the
bag.  The second seller then sends a change carrying version 3, or no
version.

*Then* the first change is applied and the order moves to version 4.  The
second seller's change carrying version 3 is rejected where the airline
rejects stale versions, and applied over the removal its seller never saw
where the airline applies it anyway.  A change carrying no version is
applied. -/
@[case, checks "ONE-405.1 ONE-405.2 ONE-405.3"]
def twoSellersOneVersion : List StaleRow :=
  [.of "first seller sends version 3" .reject tripAtThree (some 3) removeBag,
   .of "second seller sends version 3" .reject tripAtFour (some 3) addBag,
   .of "second seller sends version 3" .apply tripAtFour (some 3) addBag,
   .of "second seller sends no version" .reject tripAtFour none addBag]

#guard twoSellersOneVersion ==
  [{ request := "first seller sends version 3", handling := .reject, versionAfter := some 4, rejection := none },
   { request := "second seller sends version 3", handling := .reject, versionAfter := none,
     rejection := some .stale },
   { request := "second seller sends version 3", handling := .apply, versionAfter := some 5, rejection := none },
   { request := "second seller sends no version", handling := .reject, versionAfter := some 5,
     rejection := none }]

/-! ## Order retention -/

/-- Thirteen months counted as a fixed number of days. -/
def daysCount (days : Nat) : MonthCount := ⟨fun t => ⟨t.epochSeconds + days * 24 * 60 * 60⟩⟩

/-- Thirteen months counted as 396 days, the length of the 13 calendar months
from 2026-01-01 to 2027-02-01. -/
def thirteenMonths : MonthCount := daysCount 396

/-- 2026-01-01 00:00 UTC. -/
def newYear2026 : Instant := ⟨1767225600⟩

/-- An order created on 2026-01-01 with one item, whose service is in the
delivery status given. -/
def orderFrom2026 (delivery : DeliveryStatus) : Order :=
  { id := "ORD-8", createdAt := newYear2026, items := [orderItemOf "ITEM-FLT" (eur 400) delivery] }

/-- One retention check: when it is made, when the order was first used, and
whether the order must still be kept. -/
structure RetentionRow where
  /-- The instant of the check. -/
  checkedAt : Instant
  /-- When the order was first used, if it was. -/
  firstUse : Option Instant
  /-- Whether the order must still be accessible. -/
  mustKeep : Bool
  deriving DecidableEq, Repr

/-- Check whether the order with a paid flight must be kept. -/
def RetentionRow.of (checkedAt : Instant) (firstUse : Option Instant) : RetentionRow :=
  { checkedAt, firstUse,
    mustKeep := Creation.mustKeep thirteenMonths strictReading (orderFrom2026 .readyToProceed) firstUse none
      checkedAt }

/-- *Given* an order created on 2026-01-01 with a paid flight, which holds
value.  Thirteen months are counted as 396 days.

*When* the airline checks on 2027-01-15, 2027-03-01 and 2027-08-01 whether
it must keep the order, once for an order never used and once for an order
first used on 2026-06-01.

*Then* on 2027-01-15, within 13 months of creation, it must keep the order
either way.  On 2027-03-01 it must keep it only if it was used, within 13
months of its first usage.  On 2027-08-01 it need not keep it. -/
@[case, checks "ONE-406.1 ONE-406.2"]
def retentionOfPaidOrder : List RetentionRow :=
  let used : Instant := ⟨1780272000⟩
  [.of ⟨1799971200⟩ none, .of ⟨1799971200⟩ (some used),
   .of ⟨1803859200⟩ none, .of ⟨1803859200⟩ (some used),
   .of ⟨1817078400⟩ none, .of ⟨1817078400⟩ (some used)]

#guard retentionOfPaidOrder ==
  [{ checkedAt := ⟨1799971200⟩, firstUse := none, mustKeep := true },
   { checkedAt := ⟨1799971200⟩, firstUse := some ⟨1780272000⟩, mustKeep := true },
   { checkedAt := ⟨1803859200⟩, firstUse := none, mustKeep := false },
   { checkedAt := ⟨1803859200⟩, firstUse := some ⟨1780272000⟩, mustKeep := true },
   { checkedAt := ⟨1817078400⟩, firstUse := none, mustKeep := false },
   { checkedAt := ⟨1817078400⟩, firstUse := some ⟨1780272000⟩, mustKeep := false }]

/-- One retention check of an order that has reached a final status. -/
structure FinalRow where
  /-- The instant of the check. -/
  checkedAt : Instant
  /-- Whether the order must still be accessible. -/
  mustKeep : Bool
  deriving DecidableEq, Repr

/-- *Given* an order created on 2026-01-01 whose one flight was delivered, so
its item is closed, on 2026-11-10.

*When* the airline checks on 2026-11-15 and on 2026-11-20 whether it must
keep the order.

*Then* it must keep it on 2026-11-15, within 7 days, and need not on
2026-11-20. -/
@[case, checks "ONE-406.3"]
def deliveredOrderRetention : List FinalRow :=
  [⟨1794700800⟩, ⟨1795132800⟩].map fun t =>
    { checkedAt := t,
      mustKeep := mustKeep thirteenMonths strictReading (orderFrom2026 .delivered) none (some ⟨1794268800⟩) t }

#guard deliveredOrderRetention ==
  [{ checkedAt := ⟨1794700800⟩, mustKeep := true }, { checkedAt := ⟨1795132800⟩, mustKeep := false }]

/-- Whether an order holds value, next to whether it must be kept. -/
structure ValueKept where
  /-- Whether the order still holds value. -/
  holdsValue : Bool
  /-- Whether the order must still be accessible. -/
  mustKeep : Bool
  deriving DecidableEq, Repr

/-- *Given* an order created on 2026-01-01 whose flight was removed with its
value held for the customer, and never used.

*When* the airline checks on 2028-01-01 whether it must keep the order.

*Then* the order still holds value under every reading, and the airline need
not keep it: 13 months from creation have passed, and there was no first
usage. -/
@[case, checks "ONE-406.4"]
def storedValueNeverUsed : ValueKept :=
  let o := orderFrom2026 .removedHoldValue
  { holdsValue := o.isOpened strictReading,
    mustKeep := mustKeep thirteenMonths strictReading o none none ⟨1830297600⟩ }

#guard storedValueNeverUsed == { holdsValue := true, mustKeep := false }

end Rules.OneOrder.Creation
