import Rules.Core.Attributes
import Rules.OneOrder.Examples
import Rules.OneOrder.Delivery.Moves

/-!
# Examples of delivery status moves

Concrete delivery scenarios the build computes.  Each {attr}`@[case]`
declaration is shown in the review document with its computed value, and each
{lit}`#guard` fails the build if that value changes.
-/

namespace Rules.OneOrder.Delivery

open Rules.Core

/-- The strict reading of the sources: every move they leave undecided is
refused. -/
def strictMoves : MoveReading :=
  { deliverBeforePayment := false, unableReturns := false, cancelInProgress := false,
    notClaimedInProgress := false }

/-- The loose reading of the sources: every move they leave undecided is
allowed. -/
def looseMoves : MoveReading :=
  { deliverBeforePayment := true, unableReturns := true, cancelInProgress := true,
    notClaimedInProgress := true }

/-- The thirteen delivery statuses. -/
def allStatuses : List DeliveryStatus :=
  [.requested, .confirmed, .readyToProceed, .readyToDeliver, .inProgress, .delivered,
   .removedHoldValue, .removed, .expired, .notClaimed, .unableToDeliver, .failedToDeliver,
   .suspended]

/-- The fifteen delivery events. -/
def allEvents : List DeliveryEvent :=
  [.confirm, .pay, .prepare, .start, .deliver, .remove, .removeHoldValue, .releaseValue,
   .expire, .notClaimed, .unable, .constraintLifted, .fail, .suspend, .resume]

/-- The events the rule accepts, under a reading, for a service that is in a
delivery status and is not suspended. -/
def acceptedEvents (m : MoveReading) (s : DeliveryStatus) : List DeliveryEvent :=
  allEvents.filter fun e => (step m ⟨s, none⟩ e).isSome

/-! ## Moves between delivery statuses -/

/-- One move in the delivery status table: a status, an event, and the status
the event leads to. -/
structure Move where
  /-- The status before the event. -/
  before : DeliveryStatus
  /-- The event. -/
  event : DeliveryEvent
  /-- The status after the event. -/
  after : DeliveryStatus
  deriving DecidableEq, Repr

/-- *Given* each delivery status, under the strict reading, where every move
the sources leave undecided is refused.

*When* each event other than a suspension happens to a service in it.

*Then* these 28 moves are allowed, and every other event is refused.  The
review document draws them as the delivery state diagram.  Suspension is
covered by the rule for suspended services. -/
@[case, checks "ONE-101.6"]
def moveTable : List Move :=
  allStatuses.flatMap fun s => allEvents.filterMap fun e => (move strictMoves s e).map (⟨s, e, ·⟩)

#guard moveTable.length == 28
#guard moveTable.take 9 ==
  [⟨.requested, .confirm, .confirmed⟩, ⟨.confirmed, .pay, .readyToProceed⟩,
   ⟨.confirmed, .remove, .removed⟩, ⟨.confirmed, .removeHoldValue, .removedHoldValue⟩,
   ⟨.confirmed, .expire, .expired⟩, ⟨.confirmed, .notClaimed, .notClaimed⟩,
   ⟨.confirmed, .unable, .unableToDeliver⟩, ⟨.confirmed, .fail, .failedToDeliver⟩,
   ⟨.readyToProceed, .prepare, .readyToDeliver⟩]
#guard moveTable.contains ⟨.readyToProceed, .deliver, .delivered⟩
#guard moveTable.contains ⟨.removedHoldValue, .releaseValue, .removed⟩

/-- A move one reading of the sources allows and the other refuses. -/
structure UndecidedMove where
  /-- The status before the event. -/
  status : DeliveryStatus
  /-- The event. -/
  event : DeliveryEvent
  /-- The status the loose reading moves the service to. -/
  movesTo : DeliveryStatus
  deriving DecidableEq, Repr

/-- *Given* each delivery status and each event.

*When* the event happens to a service in the status, under the strict reading
and under the loose reading.

*Then* seven moves are allowed under the loose reading and refused under the
strict one: delivery of a CONFIRMED service before payment, the cancellation
or NOT CLAIMED end of a service IN PROGRESS, and the return of an UNABLE TO
DELIVER service to READY TO PROCEED. -/
@[case, checks "ONE-101.6"]
def undecidedMoves : List UndecidedMove :=
  allStatuses.flatMap fun s => allEvents.filterMap fun e =>
    match move strictMoves s e, move looseMoves s e with
    | none, some t => some ⟨s, e, t⟩
    | _, _ => none

#guard undecidedMoves ==
  [⟨.confirmed, .prepare, .readyToDeliver⟩, ⟨.confirmed, .start, .inProgress⟩,
   ⟨.confirmed, .deliver, .delivered⟩, ⟨.inProgress, .remove, .removed⟩,
   ⟨.inProgress, .removeHoldValue, .removedHoldValue⟩, ⟨.inProgress, .notClaimed, .notClaimed⟩,
   ⟨.unableToDeliver, .constraintLifted, .readyToProceed⟩]

/-- The delivery statuses a service passes through, one after each event,
under the two readings of the sources. -/
structure Walk where
  /-- The statuses under the strict reading, where every undecided move is refused. -/
  strict : List DeliveryStatus
  /-- The statuses under the loose reading, where every undecided move is allowed. -/
  loose : List DeliveryStatus
  deriving DecidableEq, Repr

/-- Walk a service from a delivery status through a sequence of events under
both readings. -/
def Walk.of (s : DeliveryStatus) (es : List DeliveryEvent) : Walk :=
  { strict := visits strictMoves ⟨s, none⟩ es, loose := visits looseMoves ⟨s, none⟩ es }

/-- *Given* a flight service that is CONFIRMED and waiting for payment.

*When* payment succeeds, and then the passenger flies and the provider reports
the flight delivered.

*Then* the flight is READY TO PROCEED and then DELIVERED under both readings.
It skips READY TO DELIVER and IN PROGRESS, as the services in the Order Closing
worked example do. -/
@[case, checks "ONE-101.2 ONE-101.3"]
def paidFlightDelivered : Walk := .of .confirmed [.pay, .deliver]

#guard paidFlightDelivered ==
  { strict := [.readyToProceed, .delivered], loose := [.readyToProceed, .delivered] }

/-- *Given* a bag service that is CONFIRMED, with no payment yet.

*When* the provider reports the bag delivered.

*Then* under the strict reading the report is refused and the bag stays
CONFIRMED.  Under the loose reading the bag is DELIVERED though nobody paid
for it. -/
@[case, checks "ONE-101.4 ONE-101.5"]
def deliveredBeforePayment : Walk := .of .confirmed [.deliver]

#guard deliveredBeforePayment == { strict := [.confirmed], loose := [.delivered] }
#guard !paymentSucceeds looseMoves ⟨.confirmed, none⟩ [.deliver]

/-- *Given* a flight service that is CONFIRMED, with no payment yet.

*When* a force majeure event prevents delivery, the constraint then lifts, and
the passenger flies.

*Then* under the strict reading the flight stays UNABLE TO DELIVER.  Under the
loose reading it returns to READY TO PROCEED when the constraint lifts and is
then DELIVERED, though nobody paid for it. -/
@[case, checks "ONE-101.4 ONE-101.5"]
def unpaidAfterForceMajeure : Walk := .of .confirmed [.unable, .constraintLifted, .deliver]

#guard unpaidAfterForceMajeure ==
  { strict := [.unableToDeliver, .unableToDeliver, .unableToDeliver],
    loose := [.unableToDeliver, .readyToProceed, .delivered] }
#guard !paymentSucceeds looseMoves ⟨.confirmed, none⟩ [.unable, .constraintLifted, .deliver]

/-! ## Services that end without delivery -/

/-- A cancelled bag whose value the airline holds, before and after the value
is released. -/
structure HeldValue where
  /-- The bag's delivery status after the cancellation. -/
  afterCancellation : DeliveryStatus
  /-- The order's statuses while the value is held, under the two readings of the guide. -/
  orderWhileHeld : OrderStatuses
  /-- The bag's delivery status after the value is released. -/
  afterRelease : DeliveryStatus
  /-- The order's statuses after the value is released. -/
  orderAfterRelease : OrderStatuses
  deriving DecidableEq, Repr

/-- *Given* an order whose one service is a paid bag, READY TO PROCEED.

*When* the customer cancels the bag and the airline holds its value for reuse,
and later the value is refunded.

*Then* the bag is REMOVED HOLD VALUE and the order stays opened while the value
is held.  Once the value is refunded the bag is REMOVED and the order is
closed.  Both hold under either reading of the guide. -/
@[case, checks "ONE-102.1 ONE-102.2"]
def reusableCancellation : HeldValue :=
  let held := (step strictMoves ⟨.readyToProceed, none⟩ .removeHoldValue).getD default
  let released := (step strictMoves held .releaseValue).getD held
  let order (d : DeliveryStatus) := OrderStatuses.of (orderWith (itemWith [svc .cancelled d]))
  { afterCancellation := held.status, orderWhileHeld := order held.status,
    afterRelease := released.status, orderAfterRelease := order released.status }

#guard reusableCancellation ==
  { afterCancellation := .removedHoldValue,
    orderWhileHeld := { cautious := [.opened], strict := [.opened] },
    afterRelease := .removed,
    orderAfterRelease := { cautious := [.closed], strict := [.closed] } }

/-- How one outcome ends a paid flight, and whether the flight still holds
value. -/
structure Outcome where
  /-- The event. -/
  event : DeliveryEvent
  /-- The flight's delivery status after the event. -/
  status : DeliveryStatus
  /-- Whether the flight holds value under the cautious reading of the guide. -/
  cautiousHoldsValue : Bool
  /-- Whether the flight holds value under the strict reading of the guide. -/
  strictHoldsValue : Bool
  deriving DecidableEq, Repr

/-- *Given* a paid flight service, READY TO PROCEED.

*When* its consumption time limit passes, or the passenger does not show, or a
force majeure event prevents the flight, or the airline fails to operate it.

*Then* the flight becomes EXPIRED, NOT CLAIMED, UNABLE TO DELIVER or FAILED TO
DELIVER.  The guide does not say whether any of these holds value: under the
cautious reading each does, and under the strict reading none does. -/
@[case, checks "ONE-102.3 ONE-102.4 ONE-102.5 ONE-102.6"]
def outcomesOfPaidFlight : List Outcome :=
  [DeliveryEvent.expire, .notClaimed, .unable, .fail].filterMap fun e =>
    (move strictMoves .readyToProceed e).map fun s =>
      ⟨e, s, cautiousReading.holds s, strictReading.holds s⟩

#guard outcomesOfPaidFlight ==
  [⟨.expire, .expired, true, false⟩, ⟨.notClaimed, .notClaimed, true, false⟩,
   ⟨.unable, .unableToDeliver, true, false⟩, ⟨.fail, .failedToDeliver, true, false⟩]

/-! ## Final delivery statuses -/

/-- The events a service in one delivery status accepts. -/
structure StatusEvents where
  /-- The delivery status. -/
  status : DeliveryStatus
  /-- The events accepted for a service in it. -/
  accepts : List DeliveryEvent
  deriving DecidableEq, Repr

/-- *Given* each delivery status but SUSPENDED, under the loose reading, where
every move the sources leave undecided is allowed.

*When* each event happens to a service in it.

*Then* a service that is DELIVERED, REMOVED, EXPIRED, NOT CLAIMED or FAILED TO
DELIVER accepts no event.  Every other status accepts at least one. -/
@[case, checks "ONE-103.1"]
def eventsAccepted : List StatusEvents :=
  (allStatuses.filter (· != .suspended)).map fun s => ⟨s, acceptedEvents looseMoves s⟩

#guard (eventsAccepted.filter (·.accepts.isEmpty)).map (·.status) ==
  [.delivered, .removed, .expired, .notClaimed, .failedToDeliver]
#guard eventsAccepted.length == 12

/-- The ways out of UNABLE TO DELIVER under the two readings of the sources. -/
structure WayOut where
  /-- The events an UNABLE TO DELIVER service accepts under the strict reading. -/
  strictAccepts : List DeliveryEvent
  /-- The events it accepts under the loose reading. -/
  looseAccepts : List DeliveryEvent
  /-- Its delivery status after the airline suspends it and then removes it,
  under the strict reading. -/
  afterSuspendAndRemove : DeliveryStatus
  deriving DecidableEq, Repr

/-- *Given* a flight service that is UNABLE TO DELIVER because of a force
majeure event.

*When* the events it accepts are listed under each reading, and the airline
suspends it and then removes it.

*Then* under the strict reading its only accepted event is a suspension, so the
only way to a final status is to suspend it and then remove it.  Under the
loose reading it can also return to READY TO PROCEED. -/
@[case, checks "ONE-103.2"]
def unableToDeliverWayOut : WayOut :=
  { strictAccepts := acceptedEvents strictMoves .unableToDeliver,
    looseAccepts := acceptedEvents looseMoves .unableToDeliver,
    afterSuspendAndRemove := (run strictMoves ⟨.unableToDeliver, none⟩ [.suspend, .remove]).status }

#guard unableToDeliverWayOut ==
  { strictAccepts := [.suspend], looseAccepts := [.constraintLifted, .suspend],
    afterSuspendAndRemove := .removed }

/-- A closed order and the events its services accept. -/
structure ClosedOrder where
  /-- The order's statuses under the two readings of the guide. -/
  orderStatus : OrderStatuses
  /-- The events its services accept under the loose reading of the sources. -/
  accepts : List DeliveryEvent
  deriving DecidableEq, Repr

/-- *Given* an order whose one item holds a delivered flight and a removed bag.

*When* each event happens to each of its services, under the loose reading of
the sources.

*Then* the order is closed under both readings of the guide, and no event is
accepted for either service. -/
@[case, checks "ONE-103.3"]
def closedOrderEvents : ClosedOrder :=
  let item := itemWith [svc .confirmed .delivered, { svc .cancelled .removed with id := "SVC-2" }]
  { orderStatus := .of (orderWith item),
    accepts := item.services.flatMap fun s => acceptedEvents looseMoves s.delivery }

#guard closedOrderEvents == { orderStatus := { cautious := [.closed], strict := [.closed] }, accepts := [] }

/-- *Given* an order whose one flight service is NOT CLAIMED because the
passenger did not show.

*When* the order's status is worked out.

*Then* the flight's status is final, but the order is not closed.  Under the
cautious reading it stays opened, and since no event leaves NOT CLAIMED it
stays opened for good.  Under the strict reading it has no status. -/
@[case, checks "ONE-103.4"]
def noShowOrder : OrderStatuses := .of (orderWith (itemWith [svc .confirmed .notClaimed]))

#guard noShowOrder == { cautious := [.opened], strict := [] }

/-- *Given* an order whose one flight service is FAILED TO DELIVER because the
airline could not operate the flight.

*When* the order's status is worked out.

*Then* the flight's status is final, but the order is not closed.  Under the
cautious reading it stays opened for good; under the strict reading it has no
status, and the flight's value is gone with no refund. -/
@[case, checks "ONE-103.4"]
def failedDeliveryOrder : OrderStatuses := .of (orderWith (itemWith [svc .confirmed .failedToDeliver]))

#guard failedDeliveryOrder == { cautious := [.opened], strict := [] }

/-! ## Suspended services -/

/-- A suspended lounge access and a provider's report that arrives during the
suspension. -/
structure SuspensionWalk where
  /-- The lounge access's delivery status once the airline suspends it. -/
  afterSuspension : DeliveryStatus
  /-- Whether the provider's report that it delivered the lounge access is accepted. -/
  deliveryReportAccepted : Bool
  /-- The delivery status once the airline lifts the suspension. -/
  afterLifting : DeliveryStatus
  deriving DecidableEq, Repr

/-- *Given* a paid lounge access, READY TO PROCEED.

*When* the airline suspends it on suspected fraud, the lounge provider then
reports it delivered, and the airline later lifts the suspension.

*Then* the lounge access is SUSPENDED, the provider's report is refused, and
lifting the suspension returns it to READY TO PROCEED. -/
@[case, checks "ONE-104.1 ONE-104.2 ONE-104.4"]
def fraudSuspension : SuspensionWalk :=
  let suspended := (step strictMoves ⟨.readyToProceed, none⟩ .suspend).getD default
  { afterSuspension := suspended.status,
    deliveryReportAccepted := (step strictMoves suspended .deliver).isSome,
    afterLifting := ((step strictMoves suspended .resume).getD suspended).status }

#guard fraudSuspension ==
  { afterSuspension := .suspended, deliveryReportAccepted := false, afterLifting := .readyToProceed }

/-- A suspended bag and two cancellations. -/
structure SuspendedCancellation where
  /-- Whether a cancellation that holds the bag's value is accepted. -/
  holdValueAccepted : Bool
  /-- The bag's delivery status after a cancellation that keeps none of its value. -/
  afterRemoval : DeliveryStatus
  deriving DecidableEq, Repr

/-- *Given* a paid bag, READY TO PROCEED, that the airline has suspended.

*When* the bag is cancelled with its value held, and then cancelled with none
of its value kept.

*Then* the first cancellation is refused, since a suspended service moves only
back to the status it left or to REMOVED.  The second makes the bag
REMOVED. -/
@[case, checks "ONE-104.3 ONE-104.4"]
def suspendedThenCancelled : SuspendedCancellation :=
  let suspended := (step strictMoves ⟨.readyToProceed, none⟩ .suspend).getD default
  { holdValueAccepted := (step strictMoves suspended .removeHoldValue).isSome,
    afterRemoval := ((step strictMoves suspended .remove).getD suspended).status }

#guard suspendedThenCancelled == { holdValueAccepted := false, afterRemoval := .removed }

end Rules.OneOrder.Delivery
