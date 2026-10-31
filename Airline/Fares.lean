import Rules.OneOrder.Offers.Restrictions

/-!
# Verified Airline's fares

Verified Airline is a fictional airline whose policy pages are in their own
repository, {lit}`samdengler/verified-airline`.  Its three fares, Basic, Main and Flex, are written here as
change and cancel rules of the model, one for each action and each stage of a
journey after payment.  The fare table and the worked examples on the pages are
computed from them by the model's own functions ({lit}`Airline/Evaluate.lean`), so
the pages type no amount.

The terms keep clear of the two points the model takes as readings of the
guide: no rule has an expiration date, and no refund is both full and fixed.
Every reading then gives the same answer, and {lit}`lake exe airline-facts` fails if
two readings ever disagree.  The terms choose nothing for the guide; they are
one airline's fares, written with the model's types.

Before payment no rule applies.  An unpaid booking is cancelled at once with
nothing to pay, as ONE-203 says, so the fares need no rule for that stage.
-/

namespace Airline

open Rules.Core Rules.OneOrder.Offers

/-- An amount in whole US dollars. -/
def usd (n : Nat) : Money := ⟨n * 100, .USD⟩

/-- The instant Verified Airline's fare terms start: midnight UTC on
1 January 2026. -/
def termsStart : Instant := ⟨1767225600⟩

/-- An instant in 2026: the given hour UTC of the given day of the year, with
1 January as day 1. -/
def day (d h : Nat) : Instant := ⟨termsStart.epochSeconds + (d - 1) * 86400 + h * 3600⟩

/-- A rule of a Verified Airline fare.  Every rule starts when the terms start,
has no expiration date and no approximate fee, and sends a refund to the
original form of payment. -/
def term (id : String) (action : Action) (stage : Stage) (allowed : Bool)
    (fee : Option Money := none) (refund : RefundTerms := .nothing) : Restriction :=
  { id, action, stage, effective := termsStart, expires := none, allowed, fee,
    feeApproximate := false, refund, toOriginalForm := true }

/-- A Verified Airline fare. -/
structure Fare where
  /-- The fare's key in the facts the pages read. -/
  key : String
  /-- The fare's name on the pages. -/
  name : String
  /-- The price of one booked item on this fare in the worked examples. -/
  price : Money
  /-- The fare's change and cancel rules. -/
  rules : List Restriction

/-- Basic: no change and nothing back at any stage. -/
def basicFare : Fare :=
  { key := "basic", name := "Basic", price := usd 189,
    rules := [
      term "BASIC-CHANGE-PAID" (.change .flight) .beforeDeparture false,
      term "BASIC-CHANGE-FLOWN" (.change .flight) .afterDeparture false,
      term "BASIC-CHANGE-MISSED" (.change .flight) .noShow false,
      term "BASIC-CANCEL-PAID" .cancel .beforeDeparture false,
      term "BASIC-CANCEL-FLOWN" .cancel .afterDeparture false,
      term "BASIC-CANCEL-MISSED" .cancel .noShow false ] }

/-- Main: a change costs a 75 dollar fee plus the fare difference until the
traveler misses a flight.  A cancellation returns 150 dollars, and nothing
after a missed flight. -/
def mainFare : Fare :=
  { key := "main", name := "Main", price := usd 320,
    rules := [
      term "MAIN-CHANGE-PAID" (.change .flight) .beforeDeparture true (fee := some (usd 75)),
      term "MAIN-CHANGE-FLOWN" (.change .flight) .afterDeparture true (fee := some (usd 75)),
      term "MAIN-CHANGE-MISSED" (.change .flight) .noShow false,
      term "MAIN-CANCEL-PAID" .cancel .beforeDeparture true (refund := .fixed (usd 150)),
      term "MAIN-CANCEL-FLOWN" .cancel .afterDeparture true (refund := .fixed (usd 150)),
      term "MAIN-CANCEL-MISSED" .cancel .noShow false ] }

/-- Flex: a change costs only the fare difference, even after a missed flight.
A cancellation returns the full price, and 100 dollars after a missed
flight. -/
def flexFare : Fare :=
  { key := "flex", name := "Flex", price := usd 520,
    rules := [
      term "FLEX-CHANGE-PAID" (.change .flight) .beforeDeparture true,
      term "FLEX-CHANGE-FLOWN" (.change .flight) .afterDeparture true,
      term "FLEX-CHANGE-MISSED" (.change .flight) .noShow true,
      term "FLEX-CANCEL-PAID" .cancel .beforeDeparture true (refund := .full),
      term "FLEX-CANCEL-FLOWN" .cancel .afterDeparture true (refund := .full),
      term "FLEX-CANCEL-MISSED" .cancel .noShow true (refund := .fixed (usd 100)) ] }

/-- The fares in the order the pages show them. -/
def fares : List Fare := [basicFare, mainFare, flexFare]

/-- The trip of the worked examples: paid at 10:00 UTC on 2 March 2026,
departing at 08:00 UTC on 20 April. -/
def trip : Journey := { paidAt := some (day 61 10), departsAt := day 110 8, noShow := false }

/-- The same trip, with the traveler missing the flight. -/
def missedTrip : Journey := { trip with noShow := true }

/-- When the worked examples ask for a change or a cancellation before
departure: 09:00 UTC on 15 March 2026. -/
def askedBeforeDeparture : Instant := day 74 9

/-- When the worked examples ask after the departure: 12:00 UTC on
21 April 2026. -/
def askedAfterDeparture : Instant := day 111 12

/-- The worked change: a Main fare bought for 320 dollars moved to a later
flight that costs 380 dollars, before departure. -/
def mainChangeExample : Fare × Money × Money := (mainFare, usd 320, usd 380)

end Airline
