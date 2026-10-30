import Rules.Core.Attributes
import Rules.OneOrder.Payment.Accept
import Rules.OneOrder.Offers.TimeLimits
import Rules.OneOrder.Offers.Price
import Rules.OneOrder.Offers.Restrictions

/-!
# Examples of offers, prices and conditions

Concrete offers, restrictions and prices the build computes.  Each
{attr}`@[case]` declaration is shown in the review document with its computed
value, and each {lit}`#guard` fails the build if that value changes.  The
offers, references and most amounts are our own; where an example follows a
case in the guide, its docstring says so.
-/

namespace Rules.OneOrder.Offers

open Rules.Core

/-- An amount in whole euros. -/
def eur (n : Nat) : Money := ⟨n * 100, .EUR⟩

/-- An instant on 27 October 2026, at the given hour and minute UTC. -/
def oct27 (h m : Nat) : Instant := ⟨1793059200 + h * 3600 + m * 60⟩

/-- An instant on 28 October 2026, at the given hour and minute UTC. -/
def oct28 (h m : Nat) : Instant := ⟨1793145600 + h * 3600 + m * 60⟩

/-! ## Guarantees on an offer -/

/-- A flight for one passenger at 300.00 EUR. -/
def flight : OfferItem :=
  { id := "OI-FLT", price := eur 300, passengers := [⟨"PAX-1"⟩], segments := ["SEG-OUT"] }

/-- A checked bag for the same passenger and flight at 40.00 EUR. -/
def bag : OfferItem :=
  { id := "OI-BAG", price := eur 40, passengers := [⟨"PAX-1"⟩], segments := ["SEG-OUT"] }

/-- An offer item without time limits. -/
def noLimits : ItemLimits :=
  { priceGuarantee := none, inventoryGuarantee := none, payWithin := none, payBy := none }

/-- An offer valid until 12:00 UTC on 27 October 2026, with the given items. -/
def offerUntilNoon (items : List TimedOfferItem) : TimedOffer :=
  { id := "OFF-T-1", items, expiresAt := oct27 12 0, currency := .EUR }

/-- The flight with its price guaranteed until 11:00 and its seat until 11:30. -/
def guaranteedFlight : TimedOfferItem :=
  ⟨flight, { noLimits with priceGuarantee := some (oct27 11 0),
                           inventoryGuarantee := some (oct27 11 30) }⟩

/-- The bag with no guarantees. -/
def unguaranteedBag : TimedOfferItem := ⟨bag, noLimits⟩

/-- What one offer item guarantees at one instant. -/
structure GuaranteeRow where
  /-- The instant. -/
  time : Instant
  /-- The offer item. -/
  item : String
  /-- Whether its price is guaranteed. -/
  price : Bool
  /-- Whether its inventory is guaranteed. -/
  inventory : Bool
  deriving DecidableEq, Repr

/-- What each item of an offer guarantees at each of some instants, under a
reading of the guide. -/
def guaranteeRows (b : GuaranteeEnd) (o : TimedOffer) (times : List Instant) :
    List GuaranteeRow :=
  times.flatMap fun t => o.items.map fun oi =>
    let g := guaranteesAt b o oi t
    { time := t, item := oi.item.id, price := g.price, inventory := g.inventory }

/-- *Given* an offer valid until 12:00 UTC with a flight whose price is
guaranteed until 11:00 and whose seat is guaranteed until 11:30, and a bag
with no guarantees.

*When* the guarantees are read at 10:00, 11:15 and 11:45.

*Then* at 10:00 the flight's price and seat are guaranteed.  At 11:15 only its
seat is, and at 11:45 neither is.  The bag's price and inventory are never
guaranteed, although the offer is still valid.  Both readings of the guide give
the same answers, since no instant falls on a limit. -/
@[case, checks "ONE-501.1 ONE-501.2 ONE-501.3"]
def guaranteesThroughTheMorning : List GuaranteeRow :=
  guaranteeRows .exclusive (offerUntilNoon [guaranteedFlight, unguaranteedBag])
    [oct27 10 0, oct27 11 15, oct27 11 45]

#guard guaranteesThroughTheMorning ==
  [ { time := oct27 10 0, item := "OI-FLT", price := true, inventory := true },
    { time := oct27 10 0, item := "OI-BAG", price := false, inventory := false },
    { time := oct27 11 15, item := "OI-FLT", price := false, inventory := true },
    { time := oct27 11 15, item := "OI-BAG", price := false, inventory := false },
    { time := oct27 11 45, item := "OI-FLT", price := false, inventory := false },
    { time := oct27 11 45, item := "OI-BAG", price := false, inventory := false } ]

#guard guaranteesThroughTheMorning ==
  guaranteeRows .inclusive (offerUntilNoon [guaranteedFlight, unguaranteedBag])
    [oct27 10 0, oct27 11 15, oct27 11 45]

/-- An item's price guarantee at one instant: what its own limit says, and what
the rule says under each reading of the guide. -/
structure CappedGuarantee where
  /-- Whether the instant is before the item's own price guarantee limit. -/
  limitAlone : Bool
  /-- Whether the rule guarantees the price, under the reading that a guarantee
  ends at its instant. -/
  exclusive : Bool
  /-- Whether the rule guarantees the price, under the reading that a guarantee
  still holds at its instant. -/
  inclusive : Bool
  deriving DecidableEq, Repr

/-- The flight with its price guaranteed until 13:00, an hour after the offer
expires. -/
def lateGuaranteeFlight : TimedOfferItem :=
  ⟨flight, { noLimits with priceGuarantee := some (oct27 13 0) }⟩

/-- *Given* an offer valid until 12:00 UTC with a flight whose price guarantee
ends at 13:00, an hour after the offer expires.  This is the case the survey
noted for the Offers and Time Limits pages.

*When* the guarantee is read at 12:30.

*Then* the item's own limit has not passed, but the rule does not guarantee
the price under either reading: no guarantee outlasts the offer. -/
@[case, checks "ONE-501.4"]
def guaranteeAfterExpiry : CappedGuarantee :=
  let o := offerUntilNoon [lateGuaranteeFlight]
  { limitAlone := decide (oct27 12 30 < oct27 13 0),
    exclusive := (guaranteesAt .exclusive o lateGuaranteeFlight (oct27 12 30)).price,
    inclusive := (guaranteesAt .inclusive o lateGuaranteeFlight (oct27 12 30)).price }

#guard guaranteeAfterExpiry == { limitAlone := true, exclusive := false, inclusive := false }

/-- An item's price guarantee at the offer's expiry instant, and what accepting
the offer at that instant gives. -/
structure GuaranteeAtExpiry where
  /-- Whether the price is guaranteed under the reading that a guarantee ends at
  its instant. -/
  exclusive : Bool
  /-- Whether the price is guaranteed under the reading that a guarantee still
  holds at its instant. -/
  inclusive : Bool
  /-- Why accepting the offer at that instant is rejected, if it is. -/
  acceptance : Option Rules.OfferOrder.Rejection
  deriving DecidableEq, Repr

/-- The flight with its price guaranteed until 12:00, the instant the offer
expires. -/
def noonGuaranteeFlight : TimedOfferItem :=
  ⟨flight, { noLimits with priceGuarantee := some (oct27 12 0) }⟩

/-- *Given* an offer valid until 12:00 UTC with a flight whose price guarantee
also ends at 12:00.

*When* the guarantee is read at 12:00, and the customer accepts the offer at
12:00.

*Then* the offer is rejected as expired.  Under the reading that a guarantee
ends at its instant, the price is not guaranteed.  Under the reading that it
still holds at its instant, the price is guaranteed for an offer that can no
longer be accepted. -/
@[case, checks "ONE-501.5"]
def guaranteeAtExpiry : GuaranteeAtExpiry :=
  let o := offerUntilNoon [noonGuaranteeFlight]
  { exclusive := (guaranteesAt .exclusive o noonGuaranteeFlight (oct27 12 0)).price,
    inclusive := (guaranteesAt .inclusive o noonGuaranteeFlight (oct27 12 0)).price,
    acceptance :=
      match accept o.toOffer (oct27 12 0) "ORD-T-1" with
      | .error e => some e
      | .ok _ => none }

#guard guaranteeAtExpiry == { exclusive := false, inclusive := true, acceptance := some .expired }

/-! ## Time limits of a new order -/

/-- The reading that sends a lapsed price back for a new offer and takes the
earlier of two payment time limits. -/
def repriceReading : CreationReading :=
  { guaranteeEnd := .exclusive, lapsedPrice := .reprice, bothForms := .earlier }

/-- The reading that creates the order at the offered price when a price
guarantee has lapsed. -/
def offeredPriceReading : CreationReading :=
  { repriceReading with lapsedPrice := .offeredPrice }

/-- One order item as created: the offer item it came from, its payment time
limit and its price guarantee. -/
structure NewItemRow where
  /-- The offer item it came from. -/
  fromOfferItem : String
  /-- The instant by which it must be paid. -/
  paymentBy : Option Instant
  /-- The instant until which its price is guaranteed. -/
  priceGuarantee : Option Instant
  deriving DecidableEq, Repr

/-- The order items of a new order, or why it was not created. -/
def newItemRows (r : CreationReading) (o : TimedOffer) (now : Instant) :
    Except CreateRejection (List NewItemRow) :=
  (createOrder r o now "ORD-T-1").map fun n => n.items.map fun i =>
    { fromOfferItem := i.item.fromOfferItem, paymentBy := i.paymentBy,
      priceGuarantee := i.priceGuarantee }

/-- The flight with its price guaranteed until 11:30 and 72 hours to pay after
the order is created. -/
def flightPayWithin : TimedOfferItem :=
  ⟨flight, { noLimits with priceGuarantee := some (oct27 11 30), payWithin := some (72 * 3600) }⟩

/-- The bag to be paid by 12:00 UTC on 28 October 2026. -/
def bagPayBy : TimedOfferItem :=
  ⟨bag, { noLimits with payBy := some (oct28 12 0) }⟩

/-- *Given* an offer valid until 12:00 UTC on 27 October.  Its flight has a
price guarantee until 11:30 and 72 hours to pay after the order is created.
Its bag must be paid by 12:00 UTC on 28 October.

*When* the customer accepts the offer at 11:00.

*Then* the flight's order item must be paid by 11:00 on 30 October, 72 hours
after creation, and keeps its price guarantee until 11:30.  The bag's order
item must be paid by 12:00 on 28 October and has no price guarantee. -/
@[case, checks "ONE-502.1 ONE-502.2 ONE-502.3"]
def newOrderLimits : Except CreateRejection (List NewItemRow) :=
  newItemRows repriceReading (offerUntilNoon [flightPayWithin, bagPayBy]) (oct27 11 0)

#guard newOrderLimits ==
  .ok [ { fromOfferItem := "OI-FLT", paymentBy := some ⟨(oct27 11 0).epochSeconds + 72 * 3600⟩,
          priceGuarantee := some (oct27 11 30) },
        { fromOfferItem := "OI-BAG", paymentBy := some (oct28 12 0), priceGuarantee := none } ]

/-- The payment time limit an order item takes under one reading of the
guide. -/
structure BothFormsRow where
  /-- The reading. -/
  reading : BothForms
  /-- The instant by which the order item must be paid. -/
  paymentBy : Option Instant
  deriving DecidableEq, Repr

/-- *Given* an offer item that states its payment time limit both as 72 hours
after the order is created and as 12:00 UTC on 28 October.

*When* the order is created at 11:00 on 27 October.

*Then* the order item must be paid by 11:00 on 30 October if the duration
applies, and by 12:00 on 28 October if the fixed date and time applies or the
earlier of the two does. -/
@[case, checks "ONE-502.1 ONE-502.2"]
def bothFormsReadings : List BothFormsRow :=
  let l : ItemLimits := { noLimits with payWithin := some (72 * 3600), payBy := some (oct28 12 0) }
  [.duration, .fixed, .earlier].map fun r => { reading := r, paymentBy := paymentLimitAt r (oct27 11 0) l }

#guard bothFormsReadings ==
  [ { reading := .duration, paymentBy := some ⟨(oct27 11 0).epochSeconds + 72 * 3600⟩ },
    { reading := .fixed, paymentBy := some (oct28 12 0) },
    { reading := .earlier, paymentBy := some (oct28 12 0) } ]

/-- What accepting an offer gives under one reading of the guide. -/
structure LapsedRow where
  /-- What happens when a price guarantee has lapsed. -/
  reading : LapsedPrice
  /-- Whether the item's price is still guaranteed at acceptance. -/
  priceGuaranteed : Bool
  /-- The prices of the order items created, or why no order was created. -/
  outcome : Except CreateRejection (List Money)
  deriving DecidableEq, Repr

/-- An offer made at 10:00 and valid for two hours, with the flight's price
guaranteed for 30 minutes. -/
def shortGuaranteeOffer : TimedOffer :=
  offerUntilNoon [⟨flight, { noLimits with priceGuarantee := some (oct27 10 30) }⟩]

/-- *Given* an offer made at 10:00 UTC and valid until 12:00, whose flight at
300.00 EUR has its price guaranteed for 30 minutes, until 10:30.  This is the
case the survey noted for the Time Limits and Pricing Offers pages.

*When* the customer accepts the offer at 11:59, one minute before it expires.

*Then* the price is no longer guaranteed.  Under the reading that asks for a
new offer, no order is created.  Under the reading that keeps the offered
price, the order is created with the flight at 300.00 EUR, a price the
airline no longer stands behind. -/
@[case, checks "ONE-502.4"]
def lapsedGuaranteeAccepted : List LapsedRow :=
  [repriceReading, offeredPriceReading].map fun r =>
    { reading := r.lapsedPrice,
      priceGuaranteed := shortGuaranteeOffer.items.all fun oi =>
        (guaranteesAt r.guaranteeEnd shortGuaranteeOffer oi (oct27 11 59)).price,
      outcome := (createOrder r shortGuaranteeOffer (oct27 11 59) "ORD-T-1").map
        fun n => n.items.map (·.item.price) }

#guard lapsedGuaranteeAccepted ==
  [ { reading := .reprice, priceGuaranteed := false, outcome := .error .priceGuaranteeLapsed },
    { reading := .offeredPrice, priceGuaranteed := false, outcome := .ok [eur 300] } ]

/-- A new order item's payment time limit next to the order's creation. -/
structure LimitAtCreation where
  /-- When the order was created. -/
  createdAt : Instant
  /-- The instant by which the order item must be paid. -/
  paymentBy : Option Instant
  /-- Whether the payment time limit is before the creation instant. -/
  overdueAtCreation : Bool
  deriving DecidableEq, Repr

/-- Show a new order's first item's payment time limit next to the order's
creation. -/
def LimitAtCreation.of (n : NewOrder) : LimitAtCreation :=
  let paymentBy := n.items.head?.bind (·.paymentBy)
  { createdAt := n.createdAt, paymentBy,
    overdueAtCreation := paymentBy.any (· < n.createdAt) }

/-- *Given* an offer valid until 12:00 UTC whose bag must be paid by 10:30, a
fixed date and time.

*When* the customer accepts the offer at 11:00.

*Then* the order is created, and its bag item must be paid by 10:30, half an
hour before the order existed. -/
@[case, checks "ONE-502.5"]
def fixedLimitBeforeCreation : Except CreateRejection LimitAtCreation :=
  (createOrder repriceReading (offerUntilNoon [⟨bag, { noLimits with payBy := some (oct27 10 30) }⟩])
    (oct27 11 0) "ORD-T-1").map LimitAtCreation.of

#guard fixedLimitBeforeCreation ==
  .ok { createdAt := oct27 11 0, paymentBy := some (oct27 10 30), overdueAtCreation := true }

/-- A payment made at the instant an order is created, next to the order item's
payment time limit. -/
structure PaymentAtCreation where
  /-- When the order was created and the payment made. -/
  createdAt : Instant
  /-- The instant by which the order item must be paid. -/
  paymentBy : Option Instant
  /-- The amounts charged, or why the payment was rejected. -/
  payment : Except Payment.PaymentRejection (List Money)
  deriving DecidableEq, Repr

/-- A card payment of 300.00 EUR for the flight's order item. -/
def flightCardPayment : Payment.Transaction :=
  { id := "PAY-T-1", covers := ["ORD-T-1-OI-FLT"], currency := .EUR,
    parts := [{ id := "TX-T-1", method := .card, requested := eur 300, surcharge := eur 0,
                status := .successful }] }

/-- *Given* an offer valid until 12:00 UTC whose flight at 300.00 EUR has a
payment time limit of zero: payment is due at order creation.

*When* the customer accepts the offer at 11:00 and pays 300.00 EUR by card at
11:00.

*Then* the order item must be paid by 11:00, and the payment rule of ONE-304
rejects the payment because the time limit has been reached.  No payment for
the item is ever on time. -/
@[case, checks "ONE-502.6"]
def zeroDurationPayment : Except CreateRejection PaymentAtCreation :=
  (createOrder repriceReading (offerUntilNoon [⟨flight, { noLimits with payWithin := some 0 }⟩])
    (oct27 11 0) "ORD-T-1").map fun n =>
      { createdAt := n.createdAt, paymentBy := n.items.head?.bind (·.paymentBy),
        payment := Payment.acceptPayment n.payable flightCardPayment n.createdAt }

#guard zeroDurationPayment ==
  .ok { createdAt := oct27 11 0, paymentBy := some (oct27 11 0), payment := .error .timeLimitPassed }

/-! ## The rule in force -/

/-- An instant in January 2019, on the given day at the given hour UTC. -/
def jan (d h : Nat) : Instant := ⟨1546300800 + (d - 1) * 86400 + h * 3600⟩

/-- An instant in February 2019, on the given day at the given hour UTC. -/
def feb (d h : Nat) : Instant := ⟨1548979200 + (d - 1) * 86400 + h * 3600⟩

/-- A journey paid at 10:00 UTC on 1 January 2019, departing at 10:00 UTC on 1
February.  The dates are those of the guide's restriction example. -/
def journey : Journey := { paidAt := some (jan 1 10), departsAt := feb 1 10, noShow := false }

/-- A rule with no fee, no expiration date and no refund, for the given action
and stage, starting at the given instant. -/
def rule (id : String) (a : Action) (s : Stage) (effective : Instant) (allowed : Bool) :
    Restriction :=
  { id, action := a, stage := s, effective, expires := none, allowed, fee := none,
    feeApproximate := false, refund := .nothing, toOriginalForm := false }

/-- Flight change rules over the journey.  Before payment a change is free.
After payment it costs 30.00 EUR, and 60.00 EUR from 20 January.  The rule
described as no change from seven days before departure starts on 24 January,
more than eight days before.  After departure and at a no show, no change is allowed.
A name change is free before departure, and no rule covers it at a no show. -/
def changeRules : List Restriction :=
  [ rule "FLT-0" (.change .flight) .beforePayment (jan 1 0) true,
    { rule "FLT-1" (.change .flight) .beforeDeparture (jan 1 0) true with fee := some (eur 30) },
    { rule "FLT-2" (.change .flight) .beforeDeparture (jan 20 0) true with fee := some (eur 60) },
    rule "FLT-3" (.change .flight) .beforeDeparture (jan 24 0) false,
    rule "FLT-4" (.change .flight) .afterDeparture (feb 1 10) false,
    rule "FLT-5" (.change .flight) .noShow (feb 1 10) false,
    rule "NAME-1" (.change .name) .beforeDeparture (jan 1 0) true ]

/-- The rule in force at one instant of a journey. -/
structure InForceRow where
  /-- The instant. -/
  time : Instant
  /-- The stage of the journey. -/
  stage : Stage
  /-- The rule in force, if any. -/
  rule : Option String
  deriving DecidableEq, Repr

/-- *Given* the journey paid on 1 January and departing on 1 February, with the
flight change rules: free before payment, 30.00 EUR after payment, 60.00 EUR
from 20 January, and no change from 24 January.

*When* the rule in force for a flight change is read on 1 January at 08:00,
10 January, 22 January, 24 January at 12:00 and 3 February.

*Then* the rules in force are the free change before payment, the 30.00 EUR
rule, the 60.00 EUR rule, the rule that forbids changes, and the rule after
departure.  On 24 January at noon the flight is just under eight days away,
and the rule described as seven days before departure is already in force. -/
@[case, checks "ONE-503.1 ONE-503.2 ONE-503.3"]
def ruleOverJourney : List InForceRow :=
  [jan 1 8, jan 10 0, jan 22 0, jan 24 12, feb 3 0].map fun t =>
    { time := t, stage := journey.stageAt t,
      rule := (ruleInForce .ignored changeRules journey (.change .flight) t).map (·.id) }

#guard ruleOverJourney ==
  [ { time := jan 1 8, stage := .beforePayment, rule := some "FLT-0" },
    { time := jan 10 0, stage := .beforeDeparture, rule := some "FLT-1" },
    { time := jan 22 0, stage := .beforeDeparture, rule := some "FLT-2" },
    { time := jan 24 12, stage := .beforeDeparture, rule := some "FLT-3" },
    { time := feb 3 0, stage := .afterDeparture, rule := some "FLT-4" } ]

/-- The rule in force under each reading of the guide. -/
structure ReadingRow where
  /-- What is read. -/
  case : String
  /-- The rule in force when expiration dates change nothing. -/
  ignored : Option String
  /-- The rule in force when expiration dates end rules. -/
  ends : Option String
  deriving DecidableEq, Repr

/-- The rule in force under each reading of the guide. -/
def ReadingRow.of (case : String) (rules : List Restriction) (j : Journey) (a : Action)
    (t : Instant) : ReadingRow :=
  { case, ignored := (ruleInForce .ignored rules j a t).map (·.id),
    ends := (ruleInForce .ends rules j a t).map (·.id) }

/-- Flight change rules before departure where the first expires on 10 January
and the next starts on 15 January. -/
def expiringRules : List Restriction :=
  [ { rule "EXP-1" (.change .flight) .beforeDeparture (jan 1 0) true with
      fee := some (eur 30), expires := some (jan 10 0) },
    { rule "EXP-2" (.change .flight) .beforeDeparture (jan 15 0) true with fee := some (eur 60) } ]

/-- *Given* the journey paid on 1 January, with a flight change rule that starts
on 1 January and expires on 10 January, and another that starts on
15 January.

*When* the rule in force is read on 5, 12 and 16 January under each reading of
the guide.

*Then* on 5 and 16 January both readings agree.  On 12 January the first rule
is in force when expiration dates change nothing, and no rule is in force when
they end rules. -/
@[case, checks "ONE-503.4"]
def expiryReadings : List ReadingRow :=
  [("5 January", jan 5 0), ("12 January", jan 12 0), ("16 January", jan 16 0)].map fun (c, t) =>
    .of c expiringRules journey (.change .flight) t

#guard expiryReadings ==
  [ { case := "5 January", ignored := some "EXP-1", ends := some "EXP-1" },
    { case := "12 January", ignored := some "EXP-1", ends := none },
    { case := "16 January", ignored := some "EXP-2", ends := some "EXP-2" } ]

/-- *Given* two journeys.  In the first, paid at 10:00 on 1 January, the only
flight change rule before departure starts on 2 January.  In the second, the
only name change rule before departure starts and expires at 00:00 on
20 January; one of the guide's examples gives a rule equal effective and
expiration dates.

*When* the rule in force is read at 18:00 on 1 January in the first, and at
12:00 on 20 January in the second.

*Then* the first has no rule in force under either reading, although the stage
has a rule.  The second has its rule in force when expiration dates change
nothing, and none when they end rules: that rule is never in force. -/
@[case, checks "ONE-503.5"]
def noRuleInForce : List ReadingRow :=
  [ .of "before the stage's first rule starts"
      [rule "LATE-1" (.change .flight) .beforeDeparture (jan 2 0) true] journey (.change .flight)
      (jan 1 18),
    .of "rule that expires as it starts"
      [{ rule "SAME-1" (.change .name) .beforeDeparture (jan 20 0) true with expires := some (jan 20 0) }]
      journey (.change .name) (jan 20 12) ]

#guard noRuleInForce ==
  [ { case := "before the stage's first rule starts", ignored := none, ends := none },
    { case := "rule that expires as it starts", ignored := some "SAME-1", ends := none } ]

/-! ## Voluntary changes -/

/-- What the rules decide about a change, in short. -/
inductive Verdict
  /-- No rule is in force. -/
  | noRule
  /-- The change is refused. -/
  | refused
  /-- The change is allowed. -/
  | allowed
  deriving DecidableEq, Repr

/-- A change request and what the rules decide: the verdict, the penalty
quoted, and the amounts due once ONE-201 prices the quote. -/
structure ChangeRow where
  /-- The change asked for. -/
  request : String
  /-- What the rules decide. -/
  verdict : Verdict
  /-- The penalty quoted, if the change is allowed. -/
  penalty : Option Money
  /-- What the customer pays the airline, if the change is allowed. -/
  dueToAirline : Option Money
  /-- What the airline returns, if the change is allowed. -/
  dueByAirline : Option Money
  deriving DecidableEq, Repr

/-- Decide a change and price it as ONE-201 does, under the reading that
collects the whole penalty. -/
def ChangeRow.of (request : String) (j : Journey) (req : ChangeRequest) : ChangeRow :=
  match voluntaryChange .ignored changeRules j req with
  | .noRule => { request, verdict := .noRule, penalty := none, dueToAirline := none, dueByAirline := none }
  | .refused => { request, verdict := .refused, penalty := none, dueToAirline := none, dueByAirline := none }
  | .allowed q _ =>
    match Change.priceDifferential .collect q with
    | .ok d => { request, verdict := .allowed, penalty := some q.penalty,
                 dueToAirline := some d.dueToAirline, dueByAirline := some d.dueByAirline }
    | .error _ => { request, verdict := .allowed, penalty := some q.penalty,
                    dueToAirline := none, dueByAirline := none }

/-- A change of a 500.00 EUR item asked for at an instant, to a new item at the
given price, with the fee netted and any money owed refunded. -/
def changeOf (kind : ChangeKind) (t : Instant) (newPrice : Nat) : ChangeRequest :=
  { kind, requestedAt := t, oldPrice := eur 500, newPrice := eur newPrice, handling := .netted,
    settlement := .refund }

/-- *Given* the journey and its change rules, and a trip at 500.00 EUR.

*When* the customer asks on 10 January for a flight change to a trip at
550.00 EUR, on 24 January at noon for the same change, and on 10 January for a
name change.  A customer who did not show up for the flight then asks for a
name change on 2 February.

*Then* the first change is allowed with the 30.00 EUR fee as its penalty, and
the customer pays 80.00 EUR: the fee plus the fare difference of 50.00 EUR.
The second is refused.  The name change is allowed with no penalty and costs
nothing.  At the no show no rule covers a name change, so the rules give no
answer. -/
@[case, checks "ONE-504.1 ONE-504.2 ONE-504.3 ONE-504.4"]
def changeDecisions : List ChangeRow :=
  [ .of "flight change on 10 January" journey (changeOf .flight (jan 10 0) 550),
    .of "flight change on 24 January" journey (changeOf .flight (jan 24 12) 550),
    .of "name change on 10 January" journey (changeOf .name (jan 10 0) 500),
    .of "name change after a no show" { journey with noShow := true } (changeOf .name (feb 2 0) 500) ]

#guard changeDecisions ==
  [ { request := "flight change on 10 January", verdict := .allowed, penalty := some (eur 30),
      dueToAirline := some (eur 80), dueByAirline := some (eur 0) },
    { request := "flight change on 24 January", verdict := .refused, penalty := none,
      dueToAirline := none, dueByAirline := none },
    { request := "name change on 10 January", verdict := .allowed, penalty := some (eur 0),
      dueToAirline := some (eur 0), dueByAirline := some (eur 0) },
    { request := "name change after a no show", verdict := .noRule, penalty := none,
      dueToAirline := none, dueByAirline := none } ]

/-! ## Voluntary cancellations -/

/-- Cancel rules over the journey.  Before 20 January a cancellation returns the
whole price to the original form of payment, from 20 January it returns
100.00 EUR, and from 24 January and at a no show it is not allowed. -/
def cancelRules : List Restriction :=
  [ { rule "CNX-1" .cancel .beforeDeparture (jan 1 0) true with
      refund := .full, toOriginalForm := true },
    { rule "CNX-2" .cancel .beforeDeparture (jan 20 0) true with refund := .fixed (eur 100) },
    rule "CNX-3" .cancel .beforeDeparture (jan 24 0) false,
    rule "CNX-4" .cancel .noShow (feb 1 10) false ]

/-- A trip at 500.00 EUR whose price holds an airport tax of 25.00 EUR flagged
refundable and a carrier charge of 40.00 EUR that is not. -/
def tripWithTaxes : CancelledItem :=
  { price := eur 500,
    charges := [ { code := "AIRPORT", amount := eur 25, refundable := true },
                 { code := "CARRIER", amount := eur 40, refundable := false } ] }

/-- A voluntary cancellation and what the rules return. -/
structure RefundRow where
  /-- The cancellation. -/
  case : String
  /-- What the rules decide. -/
  decision : RefundDecision
  /-- The taxes, fees and charges in the price flagged refundable. -/
  refundableCharges : Money
  deriving DecidableEq, Repr

/-- Decide a cancellation of the trip under a reading of the guide. -/
def RefundRow.of (case : String) (ff : FullOrFixed) (rules : List Restriction) (j : Journey)
    (t : Instant) : RefundRow :=
  { case, decision := cancellationRefund .ignored ff rules j t tripWithTaxes,
    refundableCharges := ⟨tripWithTaxes.refundableCharges, .EUR⟩ }

/-- *Given* the journey, its cancel rules and the trip at 500.00 EUR with a
refundable airport tax of 25.00 EUR.

*When* the customer cancels on 10 January and on 22 January.

*Then* on 10 January the whole 500.00 EUR is returned to the original form of
payment.  On 22 January the fixed 100.00 EUR is returned, and not to the
original form of payment. -/
@[case, checks "ONE-505.2 ONE-505.3 ONE-505.4"]
def refundOverJourney : List RefundRow :=
  [ .of "10 January" .full cancelRules journey (jan 10 0),
    .of "22 January" .full cancelRules journey (jan 22 0) ]

#guard refundOverJourney ==
  [ { case := "10 January", decision := .refund (eur 500) true, refundableCharges := eur 25 },
    { case := "22 January", decision := .refund (eur 100) false, refundableCharges := eur 25 } ]

/-- *Given* the journey, its cancel rules and the trip at 500.00 EUR with a
refundable airport tax of 25.00 EUR.

*When* the customer cancels on 25 January, and a customer who did not show up
for the flight cancels on 2 February.

*Then* both cancellations return nothing, since the rule in force forbids
cancellation, and the refundable airport tax is kept with the fare. -/
@[case, checks "ONE-505.1 ONE-505.5"]
def nonRefundableFareTaxes : List RefundRow :=
  [ .of "25 January" .full cancelRules journey (jan 25 0),
    .of "2 February, after a no show" .full cancelRules { journey with noShow := true } (feb 2 0) ]

#guard nonRefundableFareTaxes ==
  [ { case := "25 January", decision := .refund (eur 0) false, refundableCharges := eur 25 },
    { case := "2 February, after a no show", decision := .refund (eur 0) false,
      refundableCharges := eur 25 } ]

/-- A refund under one reading of the guide. -/
structure FullOrFixedRow where
  /-- Which amount a refund marked full and given a fixed amount returns. -/
  reading : FullOrFixed
  /-- What the rules decide. -/
  decision : RefundDecision
  /-- The taxes, fees and charges in the price flagged refundable. -/
  refundableCharges : Money
  deriving DecidableEq, Repr

/-- *Given* the trip at 500.00 EUR with a refundable airport tax of 25.00 EUR,
and a cancel rule that marks its refund as full and also gives a fixed amount
of 1.00 EUR.  One example in the guide has a rule like this.

*When* the customer cancels on 10 January, under each reading of the guide.

*Then* reading the refund as full returns 500.00 EUR.  Reading it as the fixed
amount returns 1.00 EUR, less than the refundable airport tax. -/
@[case, checks "ONE-505.5"]
def fullMarkedWithAmount : List FullOrFixedRow :=
  let rules := [{ rule "CNX-B" .cancel .beforeDeparture (jan 1 0) true with
                  refund := .fullWithAmount (eur 1) }]
  [FullOrFixed.full, .fixed].map fun ff =>
    { reading := ff, decision := cancellationRefund .ignored ff rules journey (jan 10 0) tripWithTaxes,
      refundableCharges := ⟨tripWithTaxes.refundableCharges, .EUR⟩ }

#guard fullMarkedWithAmount ==
  [ { reading := .full, decision := .refund (eur 500) false, refundableCharges := eur 25 },
    { reading := .fixed, decision := .refund (eur 1) false, refundableCharges := eur 25 } ]

/-! ## Price totals -/

/-- A price with no surcharges, fees, taxes or consumption taxes. -/
def bare (beforeDiscount discount : Money) : PriceParts :=
  { beforeDiscount, discount, surcharges := [], fees := [], taxes := [], consumption := [],
    excludedTax := ⟨0, beforeDiscount.currency⟩ }

/-- *Given* a price of 100.00 EUR before a discount of 5.00 EUR, with a tax of
20.00 EUR.  The guide's one example that adds up has a base of 95.00 and a tax
of 20.00 for a total of 115.00.

*When* the price is totalled.

*Then* the base amount is 95.00 EUR, the tax summary total 20.00 EUR and the
total 115.00 EUR. -/
@[case, checks "ONE-506.3 ONE-506.4 ONE-506.5"]
def priceThatAddsUp : Except PriceRejection PriceTotal :=
  priceTotal .lines
    { bare (eur 100) (eur 5) with taxes := [{ code := "TAX", amount := eur 20, refundable := true }] }

#guard priceThatAddsUp ==
  .ok { base := eur 95, taxTotal := eur 20, excludedTax := eur 0, total := eur 115 }

/-- *Given* a price of 100.00 EUR before a discount of 120.00 EUR.

*When* the price is totalled.

*Then* it is rejected: the discount is larger than the amount before
discounts. -/
@[case, checks "ONE-506.2"]
def discountAboveBase : Except PriceRejection PriceTotal :=
  priceTotal .lines (bare (eur 100) (eur 120))

#guard discountAboveBase == .error .discountAboveBase

/-- *Given* a price whose gross amount is in pounds and whose consumption tax is
in euros.  The guide's Australian example states its gross amount in
Australian dollars and its tax in euros; the model has no Australian dollar, so
pounds stand in.

*When* the price is totalled.

*Then* it is rejected for mixing currencies. -/
@[case, checks "ONE-506.1"]
def priceInTwoCurrencies : Except PriceRejection PriceTotal :=
  priceTotal .lines
    { bare ⟨11000, .GBP⟩ ⟨0, .GBP⟩ with
      consumption := [{ code := "GST", taxable := ⟨10000, .GBP⟩, tax := eur 10, included := true }] }

#guard priceInTwoCurrencies == .error .mixedCurrency

/-- A price's total under one reading of the guide. -/
structure ExcludedTaxRow where
  /-- Where the consumption tax not included comes from. -/
  reading : ExcludedTax
  /-- The consumption tax added to the total. -/
  excludedTax : Option Money
  /-- The total price. -/
  total : Option Money
  deriving DecidableEq, Repr

/-- A base of 452.15 USD with an HST line at 13 percent, 58.78 USD, marked as
not included in the price, and a stated total of excluded tax of zero.  It has
the shape of the guide's Canadian example; the model has no Canadian dollar, so
US dollars stand in. -/
def hstPrice : PriceParts :=
  { bare ⟨45215, .USD⟩ ⟨0, .USD⟩ with
    consumption := [{ code := "HST", taxable := ⟨45215, .USD⟩, tax := ⟨5878, .USD⟩, included := false }] }

/-- *Given* a base of 452.15 USD with an HST line of 58.78 USD marked as not
included in the price, and a stated total of excluded tax of zero.

*When* the price is totalled under each reading of the guide.

*Then* taking the excluded tax from the lines gives a total of 510.93 USD.
Trusting the stated total gives 452.15 USD, leaving out the 58.78 USD of HST
the line says is not included. -/
@[case, checks "ONE-506.5 ONE-506.6"]
def excludedTaxReadings : List ExcludedTaxRow :=
  [ExcludedTax.lines, .statedTotal].map fun x =>
    match priceTotal x hstPrice with
    | .ok t => { reading := x, excludedTax := some t.excludedTax, total := some t.total }
    | .error _ => { reading := x, excludedTax := none, total := none }

#guard excludedTaxReadings ==
  [ { reading := .lines, excludedTax := some ⟨5878, .USD⟩, total := some ⟨51093, .USD⟩ },
    { reading := .statedTotal, excludedTax := some ⟨0, .USD⟩, total := some ⟨45215, .USD⟩ } ]

end Rules.OneOrder.Offers
