import Rules.Core.Attributes
import Rules.OneOrder.Accept

/-!
# Examples

Concrete ONE Order scenarios the build computes.  Each {attr}`@[case]`
declaration is shown in the review document with its computed value, and each
{lit}`#guard` fails the build if that value changes.
-/

namespace Rules.OneOrder

open Rules.Core

/-- The cautious reading of the guide: every delivery status the guide leaves
unsettled holds value, so the airline keeps it until someone decides. -/
def cautiousReading : ValueReading where
  holds s := !(s == .delivered || s == .removed)
  confirmed := rfl
  readyToProceed := rfl
  removedHoldValue := rfl
  delivered := rfl
  removed := rfl

/-- The strict reading of the guide: only the three statuses the guide says
hold value do; every unsettled status holds none. -/
def strictReading : ValueReading where
  holds s := s == .confirmed || s == .readyToProceed || s == .removedHoldValue
  confirmed := rfl
  readyToProceed := rfl
  removedHoldValue := rfl
  delivered := rfl
  removed := rfl

/-- A return trip for two passengers: one offer item covering both passengers on
an outbound and an inbound segment at 900.00 EUR, and a checked bag for the
first passenger on the outbound segment at 40.00 EUR. -/
def familyOffer : Offer where
  id := "OFF-ONE-1"
  items :=
    [ { id := "OI-1", price := ⟨90000, .EUR⟩, passengers := [⟨"PAX-1"⟩, ⟨"PAX-2"⟩],
        segments := ["SEG-OUT", "SEG-IN"] },
      { id := "OI-2", price := ⟨4000, .EUR⟩, passengers := [⟨"PAX-1"⟩], segments := ["SEG-OUT"] } ]
  expiresAt := ⟨1793102400⟩
  currency := .EUR

/-- What accepting an offer produced: per order item, its reference, the offer
item it came from and how many services it holds, and the order's statuses. -/
structure Accepted where
  /-- Each order item's reference. -/
  itemRefs : List String
  /-- The offer item each order item came from. -/
  fromOfferItems : List String
  /-- How many services each order item holds. -/
  serviceCounts : List Nat
  /-- The order's statuses under the strict reading. -/
  orderStatus : List OrderStatus
  deriving DecidableEq, Repr

/-- Summarise an accepted order. -/
def Accepted.of (o : Order) : Accepted where
  itemRefs := o.items.map (·.id)
  fromOfferItems := o.items.map (·.fromOfferItem)
  serviceCounts := o.items.map (·.services.length)
  orderStatus := orderStatuses strictReading o

/-- *Given* the family offer: a return trip for two passengers at 900.00 EUR and
an outbound bag for the first passenger at 40.00 EUR, valid until
2026-10-27 12:00 UTC.

*When* the customer accepts it at 11:59 UTC.

*Then* the order has two order items, one per offer item.  The trip item holds
four services (two passengers on two segments) and the bag item holds one.
The order is opened. -/
@[case, checks "ONE-001.1 ONE-001.2 ONE-001.3 ONE-001.4 ONE-003.1"]
def acceptFamilyOffer : Except Rules.OfferOrder.Rejection Accepted :=
  (accept familyOffer ⟨familyOffer.expiresAt.epochSeconds - 60⟩ "ORD-ONE-1").map Accepted.of

#guard acceptFamilyOffer ==
  .ok { itemRefs := ["ORD-ONE-1-OI-1", "ORD-ONE-1-OI-2"], fromOfferItems := ["OI-1", "OI-2"],
        serviceCounts := [4, 1], orderStatus := [.opened] }

/-- *Given* the family offer, valid until 2026-10-27 12:00 UTC.

*When* the customer accepts it at 12:00 UTC, the expiry instant.

*Then* the offer is rejected as expired. -/
@[case, checks "ONE-001.5"]
def acceptFamilyAtExpiry : Except Rules.OfferOrder.Rejection Accepted :=
  (accept familyOffer familyOffer.expiresAt "ORD-ONE-2").map Accepted.of

#guard acceptFamilyAtExpiry == .error .expired

/-- A service for the first passenger on the outbound segment, with the given
service and delivery statuses. -/
def svc (status : ServiceStatus) (delivery : DeliveryStatus) : Service :=
  { id := "SVC-1", passenger := ⟨"PAX-1"⟩, segment := "SEG-OUT", status := status, delivery := delivery }

/-- An order item for one flight at 300.00 EUR holding the given services. -/
def itemWith (services : List Service) : OrderItem :=
  { id := "ITEM-1", fromOfferItem := "OI-1", price := ⟨30000, .EUR⟩, services := services }

/-- An item's statuses under the two readings of the guide. -/
structure ItemStatuses where
  /-- The statuses under the cautious reading, where unsettled statuses hold value. -/
  cautious : List ItemStatus
  /-- The statuses under the strict reading, where they hold none. -/
  strict : List ItemStatus
  deriving DecidableEq, Repr

/-- Work out an item's statuses under both readings. -/
def ItemStatuses.of (i : OrderItem) : ItemStatuses :=
  { cautious := itemStatuses cautiousReading i, strict := itemStatuses strictReading i }

/-- *Given* an order item with one flight service, paid for and ready to
proceed.

*When* the item's status is worked out.

*Then* it is active under both readings, since a service ready to proceed holds
value. -/
@[case, checks "ONE-002.1"]
def paidItem : ItemStatuses := .of (itemWith [svc .confirmed .readyToProceed])

#guard paidItem == { cautious := [.active], strict := [.active] }

/-- *Given* an order item whose one flight service was cancelled and removed,
with no value kept.

*When* the item's status is worked out.

*Then* it is cancelled under both readings. -/
@[case, checks "ONE-002.2"]
def cancelledItem : ItemStatuses := .of (itemWith [svc .cancelled .removed])

#guard cancelledItem == { cautious := [.cancelled], strict := [.cancelled] }

/-- *Given* an order item with two services: a flight that was delivered and a
bag that was removed.

*When* the item's status is worked out.

*Then* it is closed under both readings. -/
@[case, checks "ONE-002.3"]
def closedItem : ItemStatuses :=
  .of (itemWith [svc .confirmed .delivered, { svc .cancelled .removed with id := "SVC-2" }])

#guard closedItem == { cautious := [.closed], strict := [.closed] }

/-- *Given* an order item whose one flight service was delivered and then
transferred to another order item by a change.

*When* the item's status is worked out.

*Then* it is both cancelled and closed under both readings.  The guide's
cancelled condition (every service transferred, none holding value) and its
closed condition (a service delivered, the rest delivered or removed) both
hold. -/
@[case, checks "ONE-002.4"]
def deliveredThenTransferred : ItemStatuses := .of (itemWith [svc .transferred .delivered])

#guard deliveredThenTransferred == { cautious := [.cancelled, .closed], strict := [.cancelled, .closed] }

/-- *Given* an order item whose one flight service is suspended by an airline
decision.

*When* the item's status is worked out.

*Then* under the cautious reading it is active.  Under the strict reading it
has no status: the service holds no value, is neither cancelled nor
transferred, and was not delivered. -/
@[case, checks "ONE-002.4"]
def suspendedService : ItemStatuses := .of (itemWith [svc .confirmed .suspended])

#guard suspendedService == { cautious := [.active], strict := [] }

/-- An order's statuses under the two readings of the guide. -/
structure OrderStatuses where
  /-- The statuses under the cautious reading. -/
  cautious : List OrderStatus
  /-- The statuses under the strict reading. -/
  strict : List OrderStatus
  deriving DecidableEq, Repr

/-- An order holding one order item. -/
def orderWith (i : OrderItem) : Order := { id := "ORD-ONE-3", items := [i], createdAt := ⟨1793102400⟩ }

/-- Work out an order's statuses under both readings. -/
def OrderStatuses.of (o : Order) : OrderStatuses :=
  { cautious := orderStatuses cautiousReading o, strict := orderStatuses strictReading o }

/-- *Given* an order whose one item holds a delivered flight and a removed bag.

*When* the order's status is worked out.

*Then* it is closed under both readings. -/
@[case, checks "ONE-003.2"]
def deliveredOrder : OrderStatuses :=
  .of (orderWith (itemWith [svc .confirmed .delivered, { svc .cancelled .removed with id := "SVC-2" }]))

#guard deliveredOrder == { cautious := [.closed], strict := [.closed] }

/-- *Given* an order whose one flight service expired because the customer did
not claim it in time.

*When* the order's status is worked out.

*Then* under the cautious reading it stays opened, because the expired service
holds value.  Under the strict reading it is neither opened nor closed: no
service holds value, and the expired service is neither delivered nor
removed. -/
@[case, checks "ONE-003.4"]
def expiredService : OrderStatuses := .of (orderWith (itemWith [svc .confirmed .expired]))

#guard expiredService == { cautious := [.opened], strict := [] }

end Rules.OneOrder
