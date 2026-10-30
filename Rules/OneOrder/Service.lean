import Rules.Core.Attributes
import Rules.Core.Party

/-!
# Services and their statuses

ONE Order as IATA's public implementation guide describes it: an order holds
order items, and each order item holds services.  A service is for one
passenger on one flight segment, and it carries two statuses, a service status
and a delivery status.  This namespace models the standard as published, next
to the airline's simplified rules in the Offer and Order namespace.
-/

namespace Rules.OneOrder

open Rules.Core

/-- The status of a service in its order: booked, cancelled, moved to another
order item, or still being confirmed.  It corresponds to the ONE Order service
status. -/
inductive ServiceStatus
  /-- Allocated to the customer after the offer item was accepted. -/
  | confirmed
  /-- Its order item was cancelled, by the airline or the seller. -/
  | cancelled
  /-- Moved to another order item by a change; the service keeps its reference. -/
  | transferred
  /-- The airline is still deciding whether to confirm it. -/
  | requested
  /-- On a waitlist; the airline confirms it if it becomes available. -/
  | waitlisted
  deriving DecidableEq, Repr, Inhabited

/-- Where a service is in its delivery.  These are the thirteen delivery
statuses of the ONE Order implementation guide. -/
inductive DeliveryStatus
  /-- The airline can provide the service and is waiting for payment. -/
  | confirmed
  /-- Paid for; the airline is preparing delivery. -/
  | readyToProceed
  /-- Delivered by the airline. -/
  | delivered
  /-- Cancelled, with its value held by the airline for the seller to reuse. -/
  | removedHoldValue
  /-- Cancelled, with no value kept in the service. -/
  | removed
  /-- The delivery provider cannot deliver it, for example for legal reasons. -/
  | unableToDeliver
  /-- No longer available because the customer did not claim it in time. -/
  | expired
  /-- Not delivered because of the airline's or the provider's limitations. -/
  | failedToDeliver
  /-- The delivery provider is delivering it. -/
  | inProgress
  /-- Not claimed because of the passenger, for example a no-show. -/
  | notClaimed
  /-- The provider is ready to start delivery. -/
  | readyToDeliver
  /-- The order management system has asked the inventory owner for it. -/
  | requested
  /-- Delivery is suspended by an airline decision. -/
  | suspended
  deriving DecidableEq, Repr, Inhabited

/-- One deliverable service in an order item: the smallest part of an order
that can be delivered on its own, for one passenger on one flight segment.  It
corresponds to a ONE Order ordered service. -/
structure Service where
  /-- The service reference.  It stays the same when the service is transferred. -/
  id : String
  /-- The passenger the service is for. -/
  passenger : Passenger
  /-- The flight segment the service is for. -/
  segment : String
  /-- The service status. -/
  status : ServiceStatus
  /-- The delivery status. -/
  delivery : DeliveryStatus
  deriving DecidableEq, Repr, Inhabited

/-- Which delivery statuses hold value.  The guide settles five of the thirteen
and is silent on the other eight, so the model takes the answer as a
parameter: a reading of the guide.  A rule that depends on value takes a
reading, and a guarantee about value counts as proven only when it holds for
every reading the guide allows.

The settled five: a confirmed service and a service ready to proceed hold value
(a new order is opened, and an order stays opened while a service holds value);
a service removed with its value held holds value; a delivered service and a
removed service hold none (a closed item holds no value). -/
structure ValueReading where
  /-- Whether a service in a delivery status still holds value. -/
  holds : DeliveryStatus → Bool
  /-- A confirmed service holds value. -/
  confirmed : holds .confirmed = true
  /-- A service ready to proceed holds value. -/
  readyToProceed : holds .readyToProceed = true
  /-- A service removed with its value held holds value. -/
  removedHoldValue : holds .removedHoldValue = true
  /-- A delivered service holds no value. -/
  delivered : holds .delivered = false
  /-- A removed service holds no value. -/
  removed : holds .removed = false

/-- Whether a service still holds value under a reading of the guide. -/
def Service.holdsValue (v : ValueReading) (s : Service) : Bool := v.holds s.delivery

end Rules.OneOrder
