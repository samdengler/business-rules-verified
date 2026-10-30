import Rules.Core.Attributes
import Rules.OneOrder.Examples
import Rules.OneOrder.Change.Examples
import Rules.OneOrder.AirlineChange.FollowUp
import Rules.OneOrder.AirlineChange.Decline
import Rules.OneOrder.AirlineChange.FlightCancel
import Rules.OneOrder.AirlineChange.Reaccommodate

/-!
# Examples of airline changes

Concrete airline changes the build computes.  The fees follow the itinerary
change worked example; the orders, prices and dates are our own.
-/

namespace Rules.OneOrder.AirlineChange

open Rules.Core
open Rules.OneOrder.Change

/-! ## Notices, dates and readings -/

/-- 2026-11-03 10:00 UTC, two days before the time limit. -/
def nov3 : Instant := ⟨1793700000⟩

/-- 2026-11-04 12:00 UTC, a day before the time limit. -/
def nov4 : Instant := ⟨1793793600⟩

/-- 2026-11-05 12:00 UTC, the time limit of the notices below. -/
def noticeLimit : Instant := ⟨1793880000⟩

/-- 2026-11-06 09:00 UTC, the morning after the time limit. -/
def nov6Morning : Instant := ⟨1793955600⟩

/-- 2026-11-06 12:00 UTC, a day after the time limit. -/
def nov6 : Instant := ⟨1793966400⟩

/-- 2026-11-20 09:00 UTC, when the affected flight departs. -/
def flightDeparts : Instant := ⟨1795165200⟩

/-- 2026-11-21 12:00 UTC, a day after the affected flight departs. -/
def afterDeparture : Instant := ⟨1795262400⟩

/-- A notice that a departure moved by 10 minutes, with no follow-up action,
as in the worked examples. -/
def timeChangeNotice : ChangeNotice :=
  { id := "NTC-TIME", reason := .scheduleChange, departure := flightDeparts, followUps := [] }

/-- The itinerary change notice: Accept, Cancel, Reshop and ContactAirline,
each with a time limit of 5 November 12:00 UTC and Auto-acceptance, as in the
itinerary change worked example. -/
def itineraryNotice : ChangeNotice :=
  { id := "NTC-ITIN", reason := .itineraryChange, departure := flightDeparts,
    followUps := [FollowUpAction.accept, .cancel, .reshop, .contactAirline].map fun a =>
      { action := a, timeLimit := some noticeLimit, consequence := some .autoAccept } }

/-- An itinerary change notice that offers Accept with Auto-cancellation, the
pairing the follow-up actions page shows. -/
def acceptOrCancelNotice : ChangeNotice :=
  { id := "NTC-ACC", reason := .itineraryChange, departure := flightDeparts,
    followUps := [{ action := .accept, timeLimit := some noticeLimit, consequence := some .autoCancel }] }

/-- A notice that offers Cancel with neither a time limit nor a consequence,
like the guide's Cancel example. -/
def cancelOnlyNotice : ChangeNotice :=
  { id := "NTC-CNX", reason := .flightCancelled, departure := flightDeparts,
    followUps := [{ action := .cancel, timeLimit := none, consequence := none }] }

/-- A notice that offers Accept with Auto-acceptance and a time limit a day
after the affected flight departs. -/
def lateLimitNotice : ChangeNotice :=
  { id := "NTC-LATE", reason := .scheduleChange, departure := flightDeparts,
    followUps := [{ action := .accept, timeLimit := some afterDeparture, consequence := some .autoAccept }] }

/-- The reading that adds nothing to the sources: a time limit with no stated
consequence leads to nothing, and the order does not record contacting the
airline. -/
def literalFollowUps : FollowUpReading := { defaultConsequence := none, contactRecorded := false }

/-- A reading that fills both gaps: a time limit with no stated consequence
leads to Auto-acceptance, and the order records contacting the airline as the
seller's answer. -/
def filledFollowUps : FollowUpReading :=
  { defaultConsequence := some .autoAccept, contactRecorded := true }

/-! ## Follow-up actions and time limits -/

/-- How a notice stands after what the seller did. -/
structure Standing where
  /-- The notice and what the seller did. -/
  case : String
  /-- When the notice is looked at. -/
  checked : Instant
  /-- How the notice stands then. -/
  standing : Resolution
  deriving DecidableEq, Repr

/-- *Given* a notice that a departure moved by 10 minutes, with no follow-up
action, and the itinerary change notice, which offers Accept, Cancel, Reshop
and ContactAirline until 5 November 12:00 UTC with Auto-acceptance.

*When* each notice is looked at after what the seller did, under the reading
that adds nothing to the sources.

*Then* the time change needs only acknowledgement.  The itinerary change is
pending a day before the time limit.  A Cancel on 3 November answers it.  A
Cancel on 6 November comes after the time limit, and Auto-acceptance applies,
as it does when the seller never answers. -/
@[case, checks "ONE-701.1 ONE-701.2 ONE-701.4 ONE-702.1 ONE-702.3"]
def noticeStandings : List Standing :=
  [ ⟨"10-minute time change", nov4, resolve literalFollowUps timeChangeNotice [] nov4⟩,
    ⟨"itinerary change, no answer", nov4, resolve literalFollowUps itineraryNotice [] nov4⟩,
    ⟨"itinerary change, Cancel on 3 November", nov6,
      resolve literalFollowUps itineraryNotice [⟨.cancel, nov3⟩] nov6⟩,
    ⟨"itinerary change, Cancel on 6 November", nov6,
      resolve literalFollowUps itineraryNotice [⟨.cancel, nov6Morning⟩] nov6⟩,
    ⟨"itinerary change, no answer", nov6, resolve literalFollowUps itineraryNotice [] nov6⟩ ]

#guard noticeStandings ==
  [ ⟨"10-minute time change", nov4, .acknowledgeOnly⟩,
    ⟨"itinerary change, no answer", nov4, .pending⟩,
    ⟨"itinerary change, Cancel on 3 November", nov6, .answered .cancel⟩,
    ⟨"itinerary change, Cancel on 6 November", nov6, .lapsed .autoAccept⟩,
    ⟨"itinerary change, no answer", nov6, .lapsed .autoAccept⟩ ]

/-- How a notice stands under a reading of the sources. -/
structure ReadingStanding where
  /-- The reading. -/
  reading : String
  /-- How the notice stands. -/
  standing : Resolution
  deriving DecidableEq, Repr

/-- *Given* the itinerary change notice, which offers ContactAirline among its
follow-up actions until 5 November 12:00 UTC with Auto-acceptance.  The seller
phones the airline on 3 November, two days before the time limit.

*When* the notice is looked at on 6 November, under each reading.

*Then* where the order does not record contacting the airline, Auto-acceptance
applies although the seller acted in time.  Where it records it, the notice is
answered with ContactAirline. -/
@[case, checks "ONE-701.5"]
def contactThenAutoAccept : List ReadingStanding :=
  [ ⟨"contacting the airline is not recorded",
      resolve literalFollowUps itineraryNotice [⟨.contactAirline, nov3⟩] nov6⟩,
    ⟨"contacting the airline is recorded",
      resolve filledFollowUps itineraryNotice [⟨.contactAirline, nov3⟩] nov6⟩ ]

#guard contactThenAutoAccept ==
  [ ⟨"contacting the airline is not recorded", .lapsed .autoAccept⟩,
    ⟨"contacting the airline is recorded", .answered .contactAirline⟩ ]

/-- The consequence of inaction that applies when the affected flight departs,
under the two readings. -/
structure AtDeparture where
  /-- The notice. -/
  case : String
  /-- The consequence under the reading that adds nothing to the sources. -/
  literal : Option Inaction
  /-- The consequence under the reading that fills both gaps. -/
  filled : Option Inaction
  deriving DecidableEq, Repr

/-- The consequence of inaction that applies to a notice when its flight
departs, under both readings. -/
def AtDeparture.of (case : String) (n : ChangeNotice) : AtDeparture :=
  { case, literal := consequenceAt literalFollowUps n n.departure,
    filled := consequenceAt filledFollowUps n n.departure }

/-- *Given* a notice that offers Cancel with neither a time limit nor a
consequence, and a notice that offers Accept with Auto-acceptance and a time
limit a day after the affected flight departs.  The seller answers neither.

*When* the flight departs on 20 November 09:00 UTC.

*Then* no consequence of inaction applies to either notice under either
reading, so both are still unresolved when the flight leaves.  The first
never lapses, even under the reading that applies Auto-acceptance when no
consequence is stated, since it has no time limit. -/
@[case, checks "ONE-702.2 ONE-702.4"]
def noticesAtDeparture : List AtDeparture :=
  [ .of "Cancel, no time limit or consequence" cancelOnlyNotice,
    .of "Accept, time limit after departure" lateLimitNotice ]

#guard noticesAtDeparture ==
  [ ⟨"Cancel, no time limit or consequence", none, none⟩,
    ⟨"Accept, time limit after departure", none, none⟩ ]

/-! ## Declining an airline change -/

/-- The price of the affected order items: a paid return trip at
1,000.00 EUR. -/
def tripPrice : Money := euros 1000

/-- The airline's terms on the trip: the 50 EUR cancellation fee and 40 EUR
change fee of the itinerary change worked example, nothing forfeited, the
penalty netted and money owed refunded. -/
def itineraryTerms : DeclineTerms :=
  { fees := { cancellation := euros 50, change := euros 40 }, forfeited := euros 0,
    handling := .netted, settlement := .refund }

/-- The narrow reading of involuntary changes: only the settled kinds, a
cancelled flight and a move to other flights, count. -/
def narrowInvoluntary : InvoluntaryReading where
  involuntary r := r == .flightCancelled || r == .itineraryChange
  flightCancelled := rfl
  itineraryChange := rfl
  customerRequest := rfl

/-- The broad reading of involuntary changes: every change but the customer's
own counts. -/
def broadInvoluntary : InvoluntaryReading where
  involuntary r := r != .customerRequest
  flightCancelled := rfl
  itineraryChange := rfl
  customerRequest := rfl

/-- What declining a change costs under a reading of the fees. -/
structure DeclineCase where
  /-- The reading of the fees. -/
  fees : String
  /-- The penalty charged. -/
  penalty : Money
  /-- What the customer pays the airline. -/
  dueToAirline : Money
  /-- What the airline returns to the customer. -/
  dueByAirline : Money
  /-- The type code. -/
  type : DifferentialType
  deriving DecidableEq, Repr

/-- Price a customer's answer to a change, or nothing if it is rejected. -/
def DeclineCase.of (label : String) (w : DeclineFees) (inv : InvoluntaryReading) (n : ChangeNotice)
    (dec : Decline) : Option DeclineCase :=
  match declineOffer .collect w inv n tripPrice itineraryTerms dec with
  | .ok d => some { fees := label, penalty := d.penalty, dueToAirline := d.dueToAirline,
                    dueByAirline := d.dueByAirline, type := d.type }
  | .error _ => none

/-- *Given* a paid return trip at 1,000.00 EUR that the airline moved to other
flights, with the 50 EUR cancellation fee of the itinerary change worked
example.

*When* the customer declines the change through Cancel, under each reading of
the fees.

*Then* where the airline's fees apply, the customer pays 50 EUR for leaving a
change the airline made and gets 950 EUR back.  Where they are waived, the
customer gets the full 1,000 EUR back. -/
@[case, checks "ONE-703.1 ONE-703.4"]
def declineByCancel : List DeclineCase :=
  [ DeclineCase.of "the airline's fees apply" .airlineTerms narrowInvoluntary itineraryNotice .cancel,
    DeclineCase.of "the fees are waived" .waived narrowInvoluntary itineraryNotice .cancel ].filterMap id

#guard declineByCancel ==
  [ ⟨"the airline's fees apply", euros 50, euros 0, euros 950, .refund⟩,
    ⟨"the fees are waived", euros 0, euros 0, euros 1000, .refund⟩ ]

/-- *Given* the same paid trip at 1,000.00 EUR that the airline moved, with
the 40 EUR change fee of the itinerary change worked example.

*When* the customer declines the change through Reshop, to other flights at
1,000.00 EUR, under each reading of the fees.

*Then* where the airline's fees apply, the customer pays the 40 EUR change fee
to move away from flights the airline chose.  Where they are waived, the
exchange is even. -/
@[case, checks "ONE-703.2 ONE-703.5"]
def declineByReshop : List DeclineCase :=
  [ DeclineCase.of "the airline's fees apply" .airlineTerms narrowInvoluntary itineraryNotice (.reshop (euros 1000)),
    DeclineCase.of "the fees are waived" .waived narrowInvoluntary itineraryNotice (.reshop (euros 1000)) ].filterMap id

#guard declineByReshop ==
  [ ⟨"the airline's fees apply", euros 40, euros 40, euros 0, .addCol⟩,
    ⟨"the fees are waived", euros 0, euros 0, euros 0, .evenExchange⟩ ]

/-- A notice that lapsed into Auto-cancellation, and what the cancellation
costs. -/
structure AutoCancelled where
  /-- How the notice stands. -/
  standing : Resolution
  /-- The penalty charged. -/
  penalty : Money
  /-- What the airline returns to the customer. -/
  dueByAirline : Money
  deriving DecidableEq, Repr

/-- *Given* the same paid trip at 1,000.00 EUR that the airline moved, and a
notice that offers Accept until 5 November 12:00 UTC with Auto-cancellation,
the pairing the follow-up actions page shows.

*When* the seller misses the time limit, and the cancellation is priced on
6 November under the reading where the airline's fees apply.

*Then* Auto-cancellation applies, and the customer loses the trip the airline
changed, pays the 50 EUR cancellation fee and gets 950 EUR back. -/
@[case, checks "ONE-702.1 ONE-703.1 ONE-703.4"]
def autoCancellation : List AutoCancelled :=
  [ (DeclineCase.of "" .airlineTerms narrowInvoluntary acceptOrCancelNotice .cancel).map fun d =>
      { standing := resolve literalFollowUps acceptOrCancelNotice [] nov6, penalty := d.penalty,
        dueByAirline := d.dueByAirline } ].filterMap id

#guard autoCancellation == [⟨.lapsed .autoCancel, euros 50, euros 950⟩]

/-- What declining a change costs under a reading of which changes are
involuntary. -/
structure ReasonCase where
  /-- The reading of involuntary changes. -/
  reading : String
  /-- Whether the change counts as involuntary. -/
  involuntary : Bool
  /-- The penalty charged. -/
  penalty : Money
  /-- What the airline returns to the customer. -/
  dueByAirline : Money
  deriving DecidableEq, Repr

/-- A notice that another carrier now operates the flight. -/
def carrierNotice : ChangeNotice :=
  { id := "NTC-CARRIER", reason := .operatingCarrierChange, departure := flightDeparts,
    followUps := [{ action := .cancel, timeLimit := some noticeLimit, consequence := none }] }

/-- Price a Cancel of a change of operating carrier under the reading that
waives the fees on involuntary changes, or nothing if it is rejected. -/
def ReasonCase.of (label : String) (inv : InvoluntaryReading) : Option ReasonCase :=
  (DeclineCase.of label .waived inv carrierNotice .cancel).map fun d =>
    { reading := label, involuntary := inv.involuntary carrierNotice.reason, penalty := d.penalty,
      dueByAirline := d.dueByAirline }

/-- *Given* the same paid trip at 1,000.00 EUR, now operated by another
carrier, and an airline that waives its fees on involuntary changes.

*When* the customer declines the change through Cancel, under each reading of
which changes are involuntary.

*Then* where only a cancelled flight and a move to other flights count, the
change of carrier is voluntary and the customer pays the 50 EUR cancellation
fee.  Where every change but the customer's own counts, the customer pays
nothing. -/
@[case, checks "ONE-703.1"]
def carrierChangeDeclined : List ReasonCase :=
  [ ReasonCase.of "only cancelled and moved flights" narrowInvoluntary,
    ReasonCase.of "every change but the customer's own" broadInvoluntary ].filterMap id

#guard carrierChangeDeclined ==
  [ ⟨"only cancelled and moved flights", false, euros 50, euros 950⟩,
    ⟨"every change but the customer's own", true, euros 0, euros 1000⟩ ]

/-! ## A flight the airline cancels -/

/-- A paid service for the first passenger on a flight segment. -/
def paidService (id seg : String) : Service :=
  { id, passenger := ⟨"PAX-1"⟩, segment := seg, status := .confirmed, delivery := .readyToProceed }

/-- A paid return trip for one passenger at 1,000.00 EUR in one order item: the
outbound flight, the inbound flight and a checked bag on the inbound flight,
all ready to proceed. -/
def paidTrip : Order where
  id := "ORD-AIR-1"
  items :=
    [ { id := "ORDITM-1", fromOfferItem := "OI-1", price := euros 1000,
        services := [paidService "SVC-OUT" "SEG-OUT", paidService "SVC-IN" "SEG-IN",
                     paidService "BAG-IN" "SEG-IN"] } ]
  createdAt := ⟨1793000000⟩

/-- The reading the flight cancellation worked example shows: nothing is
refunded. -/
def noFlightRefund : FlightRefund where
  refund _ _ := 0
  le_price _ _ := Nat.zero_le _

/-- A reading that refunds an equal share of the item's price for each of its
flights. -/
def shareByFlight : FlightRefund where
  refund i _ := min i.price.amount (i.price.amount / (i.services.map (·.segment)).dedup.length)
  le_price _ _ := min_le_left _ _

/-- An order after the airline cancels some flights in turn, and the total
refunded. -/
def cancelFlights (r : FlightRefund) (segs : List String) (o : Order) : Order × Nat :=
  segs.foldl (fun acc seg =>
    let fc := cancelFlight Delivery.strictMoves r seg acc.1
    (fc.order, acc.2 + (fc.refunds.map (·.2.amount)).sum)) (o, 0)

/-- One service of an order item: its reference, flight and statuses. -/
structure ServiceLine where
  /-- The service reference. -/
  service : String
  /-- The flight segment. -/
  segment : String
  /-- The service status. -/
  status : ServiceStatus
  /-- The delivery status. -/
  delivery : DeliveryStatus
  deriving DecidableEq, Repr

/-- An order item after the airline cancelled flights: the item, its services,
its statuses under the two readings of value, and the refund under two
readings of the refund. -/
structure FlightCancelled where
  /-- The order item reference. -/
  item : String
  /-- The item's price. -/
  price : Money
  /-- The item's services afterwards. -/
  services : List ServiceLine
  /-- The item's statuses under the cautious reading, where UNABLE TO DELIVER
  holds value. -/
  cautious : List ItemStatus
  /-- The item's statuses under the strict reading, where it holds none. -/
  strict : List ItemStatus
  /-- The refund under the reading the worked example shows. -/
  refundAsShown : Money
  /-- The refund under the reading that refunds an equal share per flight. -/
  refundByFlight : Money
  deriving DecidableEq, Repr

/-- Cancel flights of an order in turn and summarise its first order item. -/
def FlightCancelled.ofOrder (o : Order) (segs : List String) : FlightCancelled :=
  let shown := cancelFlights noFlightRefund segs o
  let byFlight := cancelFlights shareByFlight segs o
  let i := shown.1.items.headD default
  { item := i.id, price := i.price,
    services := i.services.map fun s => ⟨s.id, s.segment, s.status, s.delivery⟩,
    cautious := itemStatuses cautiousReading i, strict := itemStatuses strictReading i,
    refundAsShown := ⟨shown.2, .EUR⟩, refundByFlight := ⟨byFlight.2, .EUR⟩ }

/-- Cancel flights of the paid trip in turn and summarise its order item. -/
def FlightCancelled.of (segs : List String) : FlightCancelled := .ofOrder paidTrip segs

/-- *Given* a paid return trip at 1,000.00 EUR in one order item: the outbound
flight, the inbound flight and a bag on the inbound flight.

*When* the airline cancels the inbound flight and does not move the customer
to another one.

*Then* the inbound flight and its bag are CANCELLED with delivery status
UNABLE TO DELIVER, and the outbound flight is as it was.  The item keeps its
reference and price and stays ACTIVE under both readings, with CANCELLED
services in it.  Under the reading the worked example shows, nothing is
refunded; a reading that refunds an equal share per flight returns
500.00 EUR. -/
@[case, checks "ONE-704.1 ONE-704.2 ONE-704.3 ONE-704.4 ONE-704.5"]
def cancelInboundFlight : FlightCancelled := .of ["SEG-IN"]

#guard cancelInboundFlight ==
  { item := "ORDITM-1", price := euros 1000,
    services := [⟨"SVC-OUT", "SEG-OUT", .confirmed, .readyToProceed⟩,
                 ⟨"SVC-IN", "SEG-IN", .cancelled, .unableToDeliver⟩,
                 ⟨"BAG-IN", "SEG-IN", .cancelled, .unableToDeliver⟩],
    cautious := [.active], strict := [.active], refundAsShown := euros 0,
    refundByFlight := euros 500 }

/-- *Given* the same paid return trip at 1,000.00 EUR.

*When* the airline cancels the inbound flight and then the outbound flight,
and moves the customer to neither.

*Then* every service is CANCELLED with delivery status UNABLE TO DELIVER.
Under the strict reading the item is CANCELLED; under the cautious reading,
where UNABLE TO DELIVER holds value, it stays ACTIVE with only CANCELLED
services.  Under the reading the worked example shows, nothing is refunded for
a trip that will not operate. -/
@[case, checks "ONE-704.1 ONE-704.4 ONE-704.5"]
def cancelBothFlights : FlightCancelled := .of ["SEG-IN", "SEG-OUT"]

#guard cancelBothFlights ==
  { item := "ORDITM-1", price := euros 1000,
    services := [⟨"SVC-OUT", "SEG-OUT", .cancelled, .unableToDeliver⟩,
                 ⟨"SVC-IN", "SEG-IN", .cancelled, .unableToDeliver⟩,
                 ⟨"BAG-IN", "SEG-IN", .cancelled, .unableToDeliver⟩],
    cautious := [.active], strict := [.cancelled], refundAsShown := euros 0,
    refundByFlight := euros 1000 }

/-- The paid return trip with its bag on the inbound flight still requested
from the airline, which has not yet confirmed it. -/
def requestedBagTrip : Order :=
  { paidTrip with
    items := paidTrip.items.map fun i =>
      { i with services := i.services.map fun s =>
          if s.id = "BAG-IN" then { s with status := .requested, delivery := .requested } else s } }

/-- *Given* the paid return trip at 1,000.00 EUR, with its bag on the inbound
flight still REQUESTED from the airline.

*When* the airline cancels the inbound flight and does not move the customer
to another one.

*Then* the inbound flight is CANCELLED with delivery status UNABLE TO
DELIVER.  The bag stays REQUESTED, and live, on a flight that will not
operate, because the delivery status table has no move from REQUESTED to
UNABLE TO DELIVER. -/
@[case, checks "ONE-704.1 ONE-704.6 ONE-105.2"]
def cancelFlightWhileRequested : FlightCancelled := .ofOrder requestedBagTrip ["SEG-IN"]

#guard cancelFlightWhileRequested ==
  { item := "ORDITM-1", price := euros 1000,
    services := [⟨"SVC-OUT", "SEG-OUT", .confirmed, .readyToProceed⟩,
                 ⟨"SVC-IN", "SEG-IN", .cancelled, .unableToDeliver⟩,
                 ⟨"BAG-IN", "SEG-IN", .requested, .requested⟩],
    cautious := [.active], strict := [.active], refundAsShown := euros 0,
    refundByFlight := euros 500 }

/-! ## Re-accommodation before the seller answers -/

/-- A paid return trip for one passenger at 1,000.00 EUR in one order item, at
order version 1. -/
def paidReturn : VersionedOrder :=
  { order := { id := "ORD-AIR-2",
               items := [{ id := "ORDITM-1", fromOfferItem := "OI-1", price := euros 1000,
                           services := [paidService "SVC-OUT" "SEG-OUT", paidService "SVC-IN" "SEG-IN"] }],
               createdAt := ⟨1793000000⟩ },
    version := 1 }

/-- The airline moves both flights of the trip to other flights. -/
def moveBothFlights : Reaccommodation :=
  { item := "ORDITM-1", newItem := "ORDITM-2", kept := [], newSegments := ["SEG-OUT-2", "SEG-IN-2"] }

/-- The order when the airline notifies a re-accommodation, under a reading
of when it takes effect. -/
structure Reaccommodated where
  /-- When the change takes effect. -/
  reading : String
  /-- The order version. -/
  version : Nat
  /-- The original item's statuses under the strict reading. -/
  original : List ItemStatus
  /-- The new item's statuses under the strict reading; none if there is no new
  item. -/
  newItem : List ItemStatus
  /-- The new item's price, if there is one. -/
  newPrice : Option Money
  /-- The flights of the new item's services. -/
  newFlights : List String
  /-- The delivery statuses of the new item's services. -/
  newDelivery : List DeliveryStatus
  deriving DecidableEq, Repr

/-- Notify the re-accommodation of the paid trip under a reading and summarise
the order, or nothing if the change is rejected. -/
def Reaccommodated.of (label : String) (a : ApplyAt) : Option Reaccommodated :=
  match notifyChange Delivery.strictMoves a paidReturn moveBothFlights with
  | .ok vo =>
    let items (id : String) := vo.order.items.filter (·.id = id)
    let news := (items "ORDITM-2").flatMap (·.services)
    some { reading := label, version := vo.version,
           original := (items "ORDITM-1").flatMap (itemStatuses strictReading),
           newItem := (items "ORDITM-2").flatMap (itemStatuses strictReading),
           newPrice := (items "ORDITM-2").head?.map (·.price),
           newFlights := news.map (·.segment), newDelivery := news.map (·.delivery) }
  | .error _ => none

/-- *Given* a paid return trip at 1,000.00 EUR, ready to proceed, at order
version 1.

*When* the airline moves both flights to other flights at no price
difference and notifies the seller with Accept pending, under each reading of
when the change takes effect.

*Then* where it takes effect at notice, as in the itinerary change worked
example, the order is at version 2, the original item is CANCELLED while
Accept is pending, and the new item at 1,000.00 EUR holds the new flights
with delivery status CONFIRMED, although the customer paid in full.  Where it
waits for Accept, the order is as it was. -/
@[case, checks "ONE-705.1 ONE-705.2 ONE-705.3 ONE-705.4 ONE-705.5"]
def itineraryReaccommodated : List Reaccommodated :=
  [ Reaccommodated.of "in effect at notice" .notice,
    Reaccommodated.of "waits for Accept" .acceptance ].filterMap id

#guard itineraryReaccommodated ==
  [ ⟨"in effect at notice", 2, [.cancelled], [.active], some (euros 1000), ["SEG-OUT-2", "SEG-IN-2"],
      [.confirmed, .confirmed]⟩,
    ⟨"waits for Accept", 1, [.active], [], none, [], []⟩ ]

end Rules.OneOrder.AirlineChange
