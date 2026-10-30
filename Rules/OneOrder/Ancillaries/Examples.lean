import Rules.Core.Attributes
import Rules.OneOrder.Ancillaries.Add
import Rules.OneOrder.Ancillaries.Cancel
import Rules.OneOrder.Ancillaries.Replace
import Rules.OneOrder.Ancillaries.Seats
import Rules.OneOrder.Ancillaries.AlaCarte
import Rules.OneOrder.Ancillaries.Bundle
import Rules.OneOrder.Delivery.Examples

/-!
# Examples of ancillaries, seats and a-la-carte items

Concrete orders with bags and seats that the build computes.  The seat numbers
and the bag price follow the guide's worked examples; the orders, passengers
and other prices are our own.
-/

namespace Rules.OneOrder.Ancillaries

open Rules.Core
open Rules.OneOrder.Delivery (isLive)

/-! ## Orders, services and details -/

/-- An amount in whole euros. -/
def eur (n : Nat) : Money := ⟨n * 100, .EUR⟩

/-- A service for a passenger on a segment, confirmed, with the delivery
status given. -/
def ancSvc (id pax seg : String) (delivery : DeliveryStatus := .readyToProceed) : Service :=
  { id, passenger := ⟨pax⟩, segment := seg, status := .confirmed, delivery }

/-- An order item holding the services given. -/
def ancItem (id : String) (price : Money) (services : List Service) : OrderItem :=
  { id, fromOfferItem := "OI-" ++ id, price, services }

/-- An order holding the items given. -/
def ancOrder (items : List OrderItem) : Order :=
  { id := "ORD-ANC", items, createdAt := ⟨1793000000⟩ }

/-- Service details from a list of the services that are not flights, each
with its kind and the parent it names.  Every service the list leaves out is a
flight that names no parent. -/
def detailsOf (l : List (String × ServiceKind × Option String)) : ServiceDetails where
  kind id := ((l.find? (·.1 == id)).map (·.2.1)).getD .flight
  parent id := (l.find? (·.1 == id)).bind (·.2.2)

/-- The taxonomy reading of flight related: seats, bags, meals and lounge
access are flight related, and insurance, a journey service, is not. -/
def taxonomyRelated : ServiceKind → Bool
  | .insurance => false
  | _ => true

/-! ## Dependent services and their parent -/

/-- Two passengers on flight SEG1, as in the seat worked example: one order
item for both flights, a bag for PAX01 that names its flight, and seats 12B
and 12C, each in its own item, that name no flight. -/
def seatExampleOrder : Order :=
  ancOrder
    [ ancItem "ITM-FLT" (eur 1000) [ancSvc "FLT-1" "PAX01" "SEG1", ancSvc "FLT-2" "PAX02" "SEG1"],
      ancItem "ITM-BAG" (eur 50) [ancSvc "BAG-1" "PAX01" "SEG1"],
      ancItem "ITM-12B" (eur 20) [ancSvc "SEAT-12B" "PAX01" "SEG1"],
      ancItem "ITM-12C" (eur 20) [ancSvc "SEAT-12C" "PAX02" "SEG1"] ]

/-- The details of the seat example order: the bag names flight FLT-1 as its
parent; the seats name none. -/
def seatExampleDetails : ServiceDetails :=
  detailsOf [("BAG-1", .bag, some "FLT-1"), ("SEAT-12B", .seat "12B", none), ("SEAT-12C", .seat "12C", none)]

/-- The dependents found under one reading of the link. -/
structure DependentsFound where
  /-- The reading of the link between dependent and parent. -/
  reading : String
  /-- The references of the dependents found. -/
  dependents : List String
  deriving DecidableEq, Repr

/-- *Given* the seat example order: flights for PAX01 and PAX02 on SEG1, a bag
for PAX01 that names its flight as parent, and seats 12B for PAX01 and 12C for
PAX02 that name no flight.

*When* the dependents of PAX01's flight are worked out under each reading of
the link.

*Then* by reference only the bag depends on the flight; through passenger and
segment the bag and seat 12B do.  Under the reference reading a change to
PAX01's flight reports no impact on seat 12B. -/
@[case, checks "ONE-601.1 ONE-601.2 ONE-601.3 ONE-601.4"]
def seatWithoutReference : List DependentsFound :=
  [("by reference", LinkReading.reference), ("by passenger and segment", .passengerSegment)].map
    fun (name, r) =>
      { reading := name,
        dependents := (dependents r seatExampleDetails seatExampleOrder (ancSvc "FLT-1" "PAX01" "SEG1")).map (·.id) }

#guard seatWithoutReference ==
  [⟨"by reference", ["BAG-1"]⟩, ⟨"by passenger and segment", ["BAG-1", "SEAT-12B"]⟩]

/-! ## Adding ancillaries -/

/-- An order with one paid flight for PAX-1 on SEG-OUT at 300.00 EUR. -/
def flightOnlyOrder : Order := ancOrder [ancItem "ITM-FLT" (eur 300) [ancSvc "FLT-OUT" "PAX-1" "SEG-OUT"]]

/-- The details of the services added in the examples: two bags and an
insurance. -/
def addDetails : ServiceDetails :=
  detailsOf [("BAG-OUT", .bag, none), ("BAG-IN", .bag, none), ("INS-1", .insurance, none)]

/-- What came of one request to add services. -/
structure AddCase where
  /-- What the request adds. -/
  request : String
  /-- Why it was refused, if it was. -/
  refusal : Option AddRejection
  /-- How many order items the order holds afterwards. -/
  items : Nat
  deriving DecidableEq, Repr

/-- Add one item to the flight-only order under the taxonomy reading and
summarise the result. -/
def AddCase.of (request : String) (i : OrderItem) : AddCase :=
  match addServices taxonomyRelated addDetails flightOnlyOrder [i] with
  | .ok o => { request, refusal := none, items := o.items.length }
  | .error e => { request, refusal := some e, items := flightOnlyOrder.items.length }

/-- *Given* an order with one paid flight for PAX-1 on SEG-OUT, and the
taxonomy reading, under which bags are flight related and insurance is not.

*When* the seller adds, in turn, a bag on SEG-OUT, a bag on SEG-IN and travel
insurance.

*Then* the bag on SEG-OUT is added.  The bag on SEG-IN is refused: the
passenger holds no flight on that segment.  The insurance is added with no
flight. -/
@[case, checks "ONE-602.1 ONE-602.2 ONE-602.3"]
def addingAncillaries : List AddCase :=
  [ AddCase.of "bag on SEG-OUT" (ancItem "ITM-BAG-OUT" (eur 50) [ancSvc "BAG-OUT" "PAX-1" "SEG-OUT" .confirmed]),
    AddCase.of "bag on SEG-IN" (ancItem "ITM-BAG-IN" (eur 50) [ancSvc "BAG-IN" "PAX-1" "SEG-IN" .confirmed]),
    AddCase.of "travel insurance" (ancItem "ITM-INS" (eur 30) [ancSvc "INS-1" "PAX-1" "SEG-OUT" .confirmed]) ]

#guard addingAncillaries ==
  [ ⟨"bag on SEG-OUT", none, 2⟩, ⟨"bag on SEG-IN", some (.noFlight "BAG-IN"), 1⟩,
    ⟨"travel insurance", none, 2⟩ ]

/-- The flight-only order with a paid bag for PAX-1 on SEG-OUT in its own
item. -/
def flightAndBagOrder : Order :=
  ancOrder
    [ ancItem "ITM-FLT" (eur 300) [ancSvc "FLT-OUT" "PAX-1" "SEG-OUT"],
      ancItem "ITM-BAG" (eur 50) [ancSvc "BAG-OUT" "PAX-1" "SEG-OUT"] ]

/-- A paid change that moves PAX-1 from the flight on SEG-OUT to a flight on
SEG-NEW, at the same price. -/
def moveToNewFlight : Change.ItemChange :=
  { item := "ITM-FLT", newItem := "ITM-FLT-2", fromOfferItem := "OI-NEW", newPrice := eur 300,
    kept := [], added := [ancSvc "FLT-NEW" "PAX-1" "SEG-NEW" .confirmed] }

/-- What a change did to the flight-related ancillaries of an order. -/
structure CoverAfterChange where
  /-- The live flight-related ancillaries with no live flight, before. -/
  ancillariesWithoutFlightBefore : List String
  /-- The old flight's service status afterwards. -/
  oldFlight : Option ServiceStatus
  /-- The bag's service status afterwards. -/
  bag : Option ServiceStatus
  /-- The bag's segment afterwards. -/
  bagSegment : String
  /-- The live flight-related ancillaries with no live flight, afterwards. -/
  ancillariesWithoutFlightAfter : List String
  deriving DecidableEq, Repr

/-- The status of a service in an order, by reference, if the order holds
it. -/
def statusIn (o : Order) (id : String) : Option ServiceStatus :=
  ((services o).find? (·.id == id)).map (·.status)

/-- *Given* an order with a paid flight for PAX-1 on SEG-OUT and a paid bag for
the same passenger and segment in its own item, under the taxonomy reading.

*When* the seller makes a paid change that moves PAX-1 to a flight on SEG-NEW.

*Then* the old flight is cancelled and the bag stays confirmed on SEG-OUT,
which the passenger no longer flies.  Before the change every bag had its
flight; afterwards the bag has none. -/
@[case, checks "ONE-602.4"]
def bagLeftByFlightChange : Except Change.ChangeRejection CoverAfterChange :=
  (Change.changeItem Delivery.strictMoves flightAndBagOrder moveToNewFlight).map fun o =>
    { ancillariesWithoutFlightBefore := (uncovered taxonomyRelated addDetails flightAndBagOrder).map (·.id),
      oldFlight := statusIn o "FLT-OUT",
      bag := statusIn o "BAG-OUT",
      bagSegment := (((services o).find? (·.id == "BAG-OUT")).map (·.segment)).getD "",
      ancillariesWithoutFlightAfter := (uncovered taxonomyRelated addDetails o).map (·.id) }

#guard bagLeftByFlightChange ==
  .ok { ancillariesWithoutFlightBefore := [], oldFlight := some .cancelled, bag := some .confirmed,
        bagSegment := "SEG-OUT", ancillariesWithoutFlightAfter := ["BAG-OUT"] }

/-! ## Cancelling a flight with its ancillaries -/

/-- The add bag worked example as an order: a flight for PAX-1 on SEG-OUT, and
an extra bag for the same passenger and segment that names the flight as its
parent, in its own item. -/
def extraBagOrder : Order :=
  ancOrder
    [ ancItem "ITM-FLT" (eur 300) [ancSvc "FLT-OUT" "PAX-1" "SEG-OUT"],
      ancItem "ITM-XBAG" (eur 50) [ancSvc "XBAG-OUT" "PAX-1" "SEG-OUT"] ]

/-- The details of the extra bag order: the bag names the flight. -/
def extraBagDetails : ServiceDetails := detailsOf [("XBAG-OUT", .bag, some "FLT-OUT")]

/-- The items' conditions: the flight may be cancelled; the extra bag may not,
as in the add bag worked example. -/
def extraBagConditions (item : String) : Bool := item != "ITM-XBAG"

/-- What came of one cancellation request under one reading. -/
structure CancelCase where
  /-- The reading of what happens to dependents. -/
  reading : String
  /-- The items the seller names. -/
  named : List String
  /-- Why the request was refused, if it was. -/
  refusal : Option CancelRejection
  /-- The flight's service status afterwards. -/
  flight : Option ServiceStatus
  /-- The extra bag's service status afterwards. -/
  bag : Option ServiceStatus
  deriving DecidableEq, Repr

/-- Cancel items of the extra bag order under a reading and summarise. -/
def CancelCase.of (reading : String) (h : DependentHandling) (named : List String) : CancelCase :=
  match cancelItems Delivery.strictMoves h .passengerSegment extraBagDetails extraBagConditions extraBagOrder named with
  | .ok o => { reading, named, refusal := none, flight := statusIn o "FLT-OUT", bag := statusIn o "XBAG-OUT" }
  | .error e => { reading, named, refusal := some e, flight := statusIn extraBagOrder "FLT-OUT",
                  bag := statusIn extraBagOrder "XBAG-OUT" }

/-- *Given* the add bag worked example: a flight for PAX-1 on SEG-OUT, and an
extra bag on the same flight in its own item, whose conditions do not allow
cancellation.

*When* the seller cancels the flight item alone, under each reading of what
happens to its dependents.

*Then* where dependents are cancelled with the flight, the bag is cancelled
against its own conditions.  Where the seller must name them too, the request
is refused.  Where they stay in place, the flight is cancelled and the bag
stays confirmed on a flight the passenger no longer holds. -/
@[case, checks "ONE-603.1 ONE-603.3 ONE-603.4 ONE-603.5"]
def cancelFlightWithBag : List CancelCase :=
  [ CancelCase.of "cancel with the flight" .cancelWithFlight ["ITM-FLT"],
    CancelCase.of "refuse until named" .refuseUnlessNamed ["ITM-FLT"],
    CancelCase.of "leave in place" .leaveInPlace ["ITM-FLT"] ]

#guard cancelFlightWithBag ==
  [ ⟨"cancel with the flight", ["ITM-FLT"], none, some .cancelled, some .cancelled⟩,
    ⟨"refuse until named", ["ITM-FLT"], some (.dependentNotNamed "XBAG-OUT"), some .confirmed,
      some .confirmed⟩,
    ⟨"leave in place", ["ITM-FLT"], none, some .cancelled, some .confirmed⟩ ]

/-- *Given* the same order: a flight, and an extra bag whose conditions do not
allow cancellation.

*When* the seller, under the reading where a cancellation is refused until
the dependents are named, cancels the flight alone, and then the flight and
the bag together.

*Then* both requests are refused: the first because the bag is not named, the
second because the bag's conditions do not allow cancellation.  The flight
cannot be cancelled at all. -/
@[case, checks "ONE-603.2 ONE-603.6"]
def refuseUntilNamedBlocks : List CancelCase :=
  [ CancelCase.of "refuse until named" .refuseUnlessNamed ["ITM-FLT"],
    CancelCase.of "refuse until named" .refuseUnlessNamed ["ITM-FLT", "ITM-XBAG"] ]

#guard refuseUntilNamedBlocks ==
  [ ⟨"refuse until named", ["ITM-FLT"], some (.dependentNotNamed "XBAG-OUT"), some .confirmed,
      some .confirmed⟩,
    ⟨"refuse until named", ["ITM-FLT", "ITM-XBAG"], some (.notCancellable "ITM-XBAG"), some .confirmed,
      some .confirmed⟩ ]

/-! ## Dependents when a flight is replaced -/

/-- A paid flight for PAX-1 on SEG-1, with paid seat 12C and a bag on the same
flight, each in its own item and naming no flight. -/
def paidSeatOrder : Order :=
  ancOrder
    [ ancItem "ITM-FLT" (eur 300) [ancSvc "FLT-1" "PAX-1" "SEG-1"],
      ancItem "ITM-12C" (eur 50) [ancSvc "SEAT-12C" "PAX-1" "SEG-1"],
      ancItem "ITM-BAG" (eur 40) [ancSvc "BAG-1" "PAX-1" "SEG-1"] ]

/-- The details of the paid seat order. -/
def paidSeatDetails : ServiceDetails := detailsOf [("SEAT-12C", .seat "12C", none), ("BAG-1", .bag, none)]

/-- A reading under which every dependent moves with its flight. -/
def everythingMoves : ServiceKind → DependentEffect := fun _ => .move

/-- A reading under which bags move and seats must be reshopped. -/
def seatsReshopped : ServiceKind → DependentEffect
  | .seat _ => .reshop
  | _ => .move

/-- Seat 12C on the new flight SEG-2, already held by PAX-9. -/
def heldOnNewFlight : List SeatAssignment := [⟨⟨"PAX-9"⟩, "SEG-2", "12C"⟩]

/-- The effect stated for one dependent when a flight is replaced, under one
reading. -/
structure ReplacementLine where
  /-- The reading of the effect for each kind of service. -/
  reading : String
  /-- The dependent service. -/
  service : String
  /-- The effect stated for it. -/
  effect : DependentEffect
  /-- The segment it moves to, if it moves. -/
  movesTo : Option String
  /-- Another passenger who already holds the seat it moves to, if any. -/
  seatAlreadyHeldBy : Option String
  deriving DecidableEq, Repr

/-- Replace PAX-1's flight with one on SEG-2 under a reading and list the
effect on each dependent. -/
def ReplacementLine.of (reading : String) (e : ServiceKind → DependentEffect) : List ReplacementLine :=
  (replaceFlight e .passengerSegment paidSeatDetails paidSeatOrder (ancSvc "FLT-1" "PAX-1" "SEG-1") "SEG-2").map
    fun x =>
      { reading, service := x.service, effect := x.effect, movesTo := x.moved.map (·.segment),
        seatAlreadyHeldBy := (heldOnNewFlight.find? fun b =>
          (movedSeats paidSeatDetails [x]).any fun a =>
            a.segment == b.segment && a.seat == b.seat && a.passenger != b.passenger).map (·.passenger.id) }

/-- *Given* a paid flight for PAX-1 on SEG-1 with paid seat 12C and a bag, and a
new flight on SEG-2 on which PAX-9 already holds seat 12C.

*When* the airline replaces PAX-1's flight with the one on SEG-2, under two
readings of the effect on each kind of dependent.

*Then* where every dependent moves, seat 12C and the bag move to SEG-2, and
seat 12C on the new flight is already PAX-9's.  Where seats are reshopped,
only the bag moves and the customer must choose a seat again. -/
@[case, checks "ONE-604.1 ONE-604.2 ONE-604.3 ONE-604.4"]
def seatMovedOntoTakenSeat : List ReplacementLine :=
  ReplacementLine.of "every dependent moves" everythingMoves ++
    ReplacementLine.of "seats are reshopped" seatsReshopped

#guard seatMovedOntoTakenSeat ==
  [ ⟨"every dependent moves", "SEAT-12C", .move, some "SEG-2", some "PAX-9"⟩,
    ⟨"every dependent moves", "BAG-1", .move, some "SEG-2", none⟩,
    ⟨"seats are reshopped", "SEAT-12C", .reshop, none, none⟩,
    ⟨"seats are reshopped", "BAG-1", .move, some "SEG-2", none⟩ ]

/-! ## Choosing seats -/

/-- The seat map of SEG1: 12B, 12C and 14A are available. -/
def seg1Map : List SeatMap := [{ segment := "SEG1", available := ["12B", "12C", "14A"] }]

/-- Two passengers on flight SEG1, with no seats yet. -/
def twoPassengerOrder : Order :=
  ancOrder [ancItem "ITM-FLT" (eur 1000) [ancSvc "FLT-1" "PAX01" "SEG1", ancSvc "FLT-2" "PAX02" "SEG1"]]

/-- A seat chosen for a passenger on SEG1 at 20.00 EUR. -/
def seatChoice (pax seat : String) : SeatChoice :=
  { passenger := ⟨pax⟩, segment := "SEG1", seat, offerItem := "OI-SEAT-STD", price := eur 20 }

/-- A seat a passenger holds: passenger, segment and seat number. -/
structure HeldSeat where
  /-- The passenger. -/
  passenger : String
  /-- The flight segment. -/
  segment : String
  /-- The seat number. -/
  seat : String
  deriving DecidableEq, Repr

/-- What came of a seat request: why it was refused, if it was, and the seats
the order holds afterwards. -/
structure SeatCase where
  /-- Why the request was refused, if it was. -/
  refusal : Option SeatRejection
  /-- The seats the order holds afterwards. -/
  held : List HeldSeat
  deriving DecidableEq, Repr

/-- Make a seat request and summarise. -/
def SeatCase.of (maps : List SeatMap) (d : ServiceDetails) (o : Order) (cs : List SeatChoice) : SeatCase :=
  let shown (d : ServiceDetails) (o : Order) :=
    (seatsHeld d o).map fun a => HeldSeat.mk a.passenger.id a.segment a.seat
  match chooseSeats maps d o cs with
  | .ok (o', d') => { refusal := none, held := shown d' o' }
  | .error e => { refusal := some e, held := shown d o }

/-- *Given* two passengers on flight SEG1 with no seats, and a seat map that
marks 12B available.

*When* the seller chooses 12B for PAX01 and 12B for PAX02 in one request.

*Then* both choices pass the seat map, and both passengers hold seat 12B on
SEG1. -/
@[case, checks "ONE-605.2 ONE-605.3"]
def sameSeatTwice : SeatCase :=
  .of seg1Map (detailsOf []) twoPassengerOrder [seatChoice "PAX01" "12B", seatChoice "PAX02" "12B"]

#guard sameSeatTwice ==
  { refusal := none, held := [⟨"PAX01", "SEG1", "12B"⟩, ⟨"PAX02", "SEG1", "12B"⟩] }

/-- The two passengers' order once PAX01 holds seat 12B, and its details. -/
def withSeat12B : Order × ServiceDetails :=
  match chooseSeats seg1Map (detailsOf []) twoPassengerOrder [seatChoice "PAX01" "12B"] with
  | .ok r => r
  | .error _ => (twoPassengerOrder, detailsOf [])

/-- The seat map of SEG1 once 12B is taken: 12C and 14A are available. -/
def seg1MapAfter12B : List SeatMap := [{ segment := "SEG1", available := ["12C", "14A"] }]

/-- *Given* PAX01 holds seat 12B on SEG1, and the seat map marks 12C and 14A
available.

*When* the seller chooses 14A for PAX01 in a second request.

*Then* the choice passes the seat map, and PAX01 holds both 12B and 14A on
SEG1, each in its own order item. -/
@[case, checks "ONE-605.2 ONE-605.4"]
def secondSeatSamePassenger : SeatCase :=
  .of seg1MapAfter12B withSeat12B.2 withSeat12B.1 [seatChoice "PAX01" "14A"]

#guard secondSeatSamePassenger ==
  { refusal := none, held := [⟨"PAX01", "SEG1", "12B"⟩, ⟨"PAX01", "SEG1", "14A"⟩] }

/-- *Given* PAX01 holds seat 12B on SEG1, and the seat map marks 12C and 14A
available.

*When* the seller chooses 12B for PAX02.

*Then* the request is refused: the seat map does not mark 12B available. -/
@[case, checks "ONE-605.1"]
def occupiedSeatRefused : SeatCase :=
  .of seg1MapAfter12B withSeat12B.2 withSeat12B.1 [seatChoice "PAX02" "12B"]

#guard occupiedSeatRefused ==
  { refusal := some (.notAvailable "SEG1" "12B"), held := [⟨"PAX01", "SEG1", "12B"⟩] }

/-! ## A-la-carte offer items -/

/-- The extra bag of the add bag worked example: 50.00 EUR a unit, for PAX-1 on
the outbound and inbound journeys, one segment each. -/
def extraBagItem : AlaCarteItem :=
  { id := "OI-XBAG", kind := .bag, unitPrice := eur 50, passengers := [⟨"PAX-1"⟩],
    segments := ["SEG-OUT", "SEG-IN"] }

/-- What an a-la-carte choice produced. -/
structure AlaCarteCase where
  /-- How many order items the one offer item became. -/
  orderItems : Nat
  /-- Each order item's price. -/
  prices : List Money
  /-- The total price. -/
  total : Money
  deriving DecidableEq, Repr

/-- Summarise the order items of an a-la-carte choice. -/
def AlaCarteCase.of (items : List OrderItem) : AlaCarteCase :=
  { orderItems := items.length, prices := items.map (·.price),
    total := ⟨(items.map (·.price.amount)).sum, .EUR⟩ }

/-- *Given* the extra bag of the add bag worked example at 50.00 EUR a unit,
for PAX-1 on the outbound and inbound journeys.

*When* the seller chooses it for PAX-1 on both journeys at quantity 1.

*Then* the one offer item becomes two order items of 50.00 EUR, one per
journey, and the bag costs 100.00 EUR. -/
@[case, checks "ONE-606.2 ONE-606.3 ONE-606.4 ONE-606.5"]
def bagOverTwoJourneys : Except AlaCarteRejection AlaCarteCase :=
  (chooseAlaCarte "ORD-ANC" extraBagItem
    { passengers := [⟨"PAX-1"⟩], segments := ["SEG-OUT", "SEG-IN"], quantity := 1 }).map AlaCarteCase.of

#guard bagOverTwoJourneys == .ok { orderItems := 2, prices := [eur 50, eur 50], total := eur 100 }

/-- *Given* the same extra bag, offered for PAX-1 only.

*When* the seller chooses it for PAX-2 on the outbound journey.

*Then* the choice is refused: the offer item does not list PAX-2. -/
@[case, checks "ONE-606.1"]
def bagForIneligiblePassenger : Except AlaCarteRejection AlaCarteCase :=
  (chooseAlaCarte "ORD-ANC" extraBagItem
    { passengers := [⟨"PAX-2"⟩], segments := ["SEG-OUT"], quantity := 1 }).map AlaCarteCase.of

#guard bagForIneligiblePassenger == .error (.passengerNotEligible "PAX-2")

/-! ## Removing a service from a bundle -/

/-- The seat worked example's bundle: one order item at 1,000.00 EUR holding
both passengers' flights and bags, all paid. -/
def bundleOrder : Order :=
  ancOrder
    [ ancItem "ITM-BUNDLE" (eur 1000)
        [ ancSvc "FLT-1" "PAX01" "SEG1", ancSvc "BAG-1" "PAX01" "SEG1",
          ancSvc "FLT-2" "PAX02" "SEG1", ancSvc "BAG-2" "PAX02" "SEG1" ] ]

/-- The details of the bundle: two bags; the rest are flights. -/
def bundleDetails : ServiceDetails := detailsOf [("BAG-1", .bag, none), ("BAG-2", .bag, none)]

/-- A reading with stated component prices: 450.00 EUR a flight and 50.00 EUR a
bag, which add up to the bundle price. -/
def statedComponents : BundleShare where
  share _ s := if bundleDetails.isFlight s then 45000 else 5000

/-- A reading with stand-alone prices: 470.00 EUR a flight and 60.00 EUR a
bag, what each costs bought alone. -/
def standAlonePrices : BundleShare where
  share _ s := if bundleDetails.isFlight s then 47000 else 6000

/-- A reading that gives no share to any service: the bundle is priced only as
a whole. -/
def noShare : BundleShare where
  share _ _ := 0

/-- What removing services from the bundle returns under one reading. -/
structure BundleCase where
  /-- The reading of how the bundle price splits. -/
  reading : String
  /-- What is removed. -/
  removed : String
  /-- The amount returned. -/
  returned : Money
  deriving DecidableEq, Repr

/-- Remove services from the bundle under a reading and summarise. -/
def BundleCase.of (reading : String) (sh : BundleShare) (removed : String) (ids : List String) :
    BundleCase :=
  { reading, removed,
    returned := match removeFromBundle Delivery.strictMoves sh bundleOrder "ITM-BUNDLE" ids with
      | .ok (_, m) => m
      | .error _ => eur 0 }

/-- *Given* the seat worked example's bundle: one order item at 1,000.00 EUR
holding both passengers' flights and bags, all paid.

*When* the seller removes PAX02's flight and bag, and then, separately, every
service, under three readings of how the bundle price splits.

*Then* with stated component prices, PAX02's part returns 500.00 EUR and the
whole bundle returns 1,000.00 EUR.  With stand-alone prices, the whole bundle
returns 1,060.00 EUR, more than was paid.  With no share, nothing is
returned, even for the whole bundle. -/
@[case, checks "ONE-607.2 ONE-607.3 ONE-607.4"]
def bundleShares : List BundleCase :=
  [("stated component prices", statedComponents), ("stand-alone prices", standAlonePrices),
    ("no share", noShare)].flatMap fun (name, sh) =>
    [ BundleCase.of name sh "PAX02's flight and bag" ["FLT-2", "BAG-2"],
      BundleCase.of name sh "every service" ["FLT-1", "BAG-1", "FLT-2", "BAG-2"] ]

#guard bundleShares ==
  [ ⟨"stated component prices", "PAX02's flight and bag", eur 500⟩,
    ⟨"stated component prices", "every service", eur 1000⟩,
    ⟨"stand-alone prices", "PAX02's flight and bag", eur 530⟩,
    ⟨"stand-alone prices", "every service", eur 1060⟩,
    ⟨"no share", "PAX02's flight and bag", eur 0⟩,
    ⟨"no share", "every service", eur 0⟩ ]

/-- One service of the bundle afterwards: its reference and statuses. -/
structure BundleLine where
  /-- The service reference. -/
  service : String
  /-- The service status. -/
  status : ServiceStatus
  /-- The delivery status. -/
  delivery : DeliveryStatus
  deriving DecidableEq, Repr

/-- The bundle after services are removed: its price and its services. -/
structure BundleAfter where
  /-- The item's price afterwards. -/
  price : Money
  /-- The item's services afterwards. -/
  services : List BundleLine
  deriving DecidableEq, Repr

/-- *Given* the same bundle at 1,000.00 EUR.

*When* the seller removes PAX02's flight and bag.

*Then* PAX02's flight and bag are CANCELLED with delivery status REMOVED,
PAX01's flight and bag are as they were, and the item keeps its price of
1,000.00 EUR. -/
@[case, checks "ONE-607.1"]
def bundleAfterRemoval : Except BundleRejection BundleAfter :=
  (removeFromBundle Delivery.strictMoves statedComponents bundleOrder "ITM-BUNDLE" ["FLT-2", "BAG-2"]).map fun (o, _) =>
    let i := o.items.headD default
    { price := i.price, services := i.services.map fun s => ⟨s.id, s.status, s.delivery⟩ }

#guard bundleAfterRemoval ==
  .ok { price := eur 1000,
        services := [⟨"FLT-1", .confirmed, .readyToProceed⟩, ⟨"BAG-1", .confirmed, .readyToProceed⟩,
                     ⟨"FLT-2", .cancelled, .removed⟩, ⟨"BAG-2", .cancelled, .removed⟩] }

end Rules.OneOrder.Ancillaries
