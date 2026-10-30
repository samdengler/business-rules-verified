import Lean.Data.Json
import Airline.Fares

/-!
# The facts the airline pages read

Evaluates Parliament Air's fares with the model's functions and states the
results as JSON, which {lit}`lake exe airline-facts` prints and
{lit}`scripts/render_airline.py` reads.  For each fare and each stage after
payment, it takes the rule in force ({lit}`ruleInForce`), what a change is quoted
({lit}`voluntaryChange`) and what a cancellation returns ({lit}`cancellationRefund`).  It
also prices the worked examples, a change through {lit}`priceDifferential`.

Every fact is computed under every reading the model leaves open (whether
expiration dates end rules, which amount a refund marked full and fixed
returns, and what happens to a penalty above the refundable value) and under
both ways of charging a fee.  If two of them give different answers, the
facts are an error that names the fact, and the executable fails.
-/

namespace Airline

open Lean Rules.Core Rules.OneOrder.Offers Rules.OneOrder.Change

/-- One way of reading the guide's open points, with one way of charging a
fee. -/
structure Case where
  /-- Whether expiration dates end rules. -/
  expiry : ExpiryReading
  /-- Which amount a refund marked full and fixed returns. -/
  fullOrFixed : FullOrFixed
  /-- What happens to a penalty above the refundable value. -/
  excess : ExcessPenalty
  /-- Whether a fee is netted or charged separately. -/
  handling : PenaltyHandling

/-- Every combination of the readings and of the ways of charging a fee. -/
def cases : List Case :=
  [ExpiryReading.ignored, .ends].flatMap fun e =>
  [FullOrFixed.full, .fixed].flatMap fun f =>
  [ExcessPenalty.collect, .waive].flatMap fun x =>
  [PenaltyHandling.netted, .separate].map fun h => ⟨e, f, x, h⟩

/-- A fact computed under every case, or an error naming the fact when two
cases disagree. -/
def agree (fact : String) (f : Case → Json) : Except String Json :=
  match cases.map f with
  | [] => .error s!"no cases to compute {fact}"
  | j :: js =>
    if js.all (·.compress == j.compress) then .ok j
    else .error s!"the readings disagree on {fact}: {((j :: js).map (·.compress)).eraseDups}"

/-- An ISO 4217 code. -/
def currencyCode : Currency → String
  | .USD => "USD"
  | .EUR => "EUR"
  | .GBP => "GBP"

/-- An amount as the pages read it: minor units and a currency. -/
def money (m : Money) : Json :=
  Json.mkObj [("cents", toJson m.amount), ("currency", currencyCode m.currency)]

/-- The stages after payment, with their keys in the facts. -/
def stages : List (String × Stage) :=
  [("beforeDeparture", .beforeDeparture), ("afterDeparture", .afterDeparture), ("noShow", .noShow)]

/-- The journey and the instant at which a stage is probed. -/
def probe : Stage → Journey × Instant
  | .beforePayment => ({ trip with paidAt := none }, askedBeforeDeparture)
  | .beforeDeparture => (trip, askedBeforeDeparture)
  | .afterDeparture => (trip, askedAfterDeparture)
  | .noShow => (missedTrip, askedAfterDeparture)

/-- The reference of the rule in force, or null. -/
def ruleRef (c : Case) (fare : Fare) (s : Stage) (a : Action) : Json :=
  let (j, now) := probe s
  match ruleInForce c.expiry fare.rules j a now with
  | some r => toJson r.id
  | none => Json.null

/-- A change request for a booked item at an instant. -/
def changeRequest (c : Case) (now : Instant) (old new : Money) : ChangeRequest :=
  { kind := .flight, requestedAt := now, oldPrice := old, newPrice := new,
    handling := c.handling, settlement := .refund }

/-- What a flight change at a stage is quoted: refused, no rule, or allowed
with the fee as its penalty.  The probe moves the item to a flight at the same
price, so the fee is the whole quote. -/
def changeFact (c : Case) (fare : Fare) (s : Stage) : Json :=
  let (j, now) := probe s
  let decision := match voluntaryChange c.expiry fare.rules j (changeRequest c now fare.price fare.price) with
    | .noRule => [("decision", toJson "noRule")]
    | .refused => [("decision", toJson "refused")]
    | .allowed q approx =>
      [("decision", toJson "allowed"), ("fee", money q.penalty), ("approximate", toJson approx)]
  Json.mkObj (("rule", ruleRef c fare s (.change .flight)) :: decision)

/-- An unused item at a price, with no taxes, fees or charges in it. -/
def itemAt (price : Money) : CancelledItem := { price, charges := [] }

/-- What a cancellation at a stage returns.  The kind comes from the refund at
two prices: the whole price both times is a full refund, the same amount both
times a fixed one, and zero both times nothing. -/
def cancelFact (c : Case) (fare : Fare) (s : Stage) : Json :=
  let (j, now) := probe s
  let at_ p := cancellationRefund c.expiry c.fullOrFixed fare.rules j now (itemAt p)
  let p := fare.price
  let p' : Money := ⟨p.amount + 100, p.currency⟩
  let outcome := match at_ p, at_ p' with
    | .refund a toOriginal, .refund a' _ =>
      let kind :=
        if a.amount = 0 ∧ a'.amount = 0 then "nothing"
        else if a = p ∧ a' = p' then "full"
        else if a = a' then "fixed"
        else "other"
      [("kind", toJson kind), ("refund", money a), ("toOriginalForm", toJson toOriginal)]
    | _, _ => [("kind", toJson "noRule")]
  Json.mkObj (("rule", ruleRef c fare s .cancel) :: outcome)

/-- The facts of one action over the stages after payment. -/
def overStages (what : String) (fare : Fare) (f : Case → Fare → Stage → Json) :
    Except String Json := do
  let parts ← stages.mapM fun (key, s) => do
    return (key, ← agree s!"{fare.key} {what} {key}" (f · fare s))
  return Json.mkObj parts

/-- One fare's facts: its name, its example price, and what a change and a
cancellation give at each stage. -/
def fareFacts (fare : Fare) : Except String Json := do
  return Json.mkObj [
    ("name", toJson fare.name),
    ("price", money fare.price),
    ("change", ← overStages "change" fare changeFact),
    ("cancel", ← overStages "cancel" fare cancelFact)]

/-- The worked change: what the customer pays, or gets back, for a change
before departure, priced as ONE-201 prices it. -/
def changeExample (fare : Fare) (old new : Money) : Except String Json :=
  agree s!"the {fare.key} change example" fun c =>
    match voluntaryChange c.expiry fare.rules trip (changeRequest c askedBeforeDeparture old new) with
    | .allowed q _ =>
      match priceDifferential c.excess q with
      | .ok d =>
        let net : Int := (d.dueToAirline.amount : Int) - d.dueByAirline.amount
        Json.mkObj [
          ("fare", toJson fare.key), ("oldPrice", money old), ("newPrice", money new),
          ("fee", money q.penalty),
          ("youPay", money ⟨net.toNat, old.currency⟩), ("weReturn", money ⟨(-net).toNat, old.currency⟩)]
      | .error _ => Json.mkObj [("error", toJson "mixed currencies")]
    | .refused => Json.mkObj [("error", toJson "refused")]
    | .noRule => Json.mkObj [("error", toJson "no rule in force")]

/-- A worked cancellation of one item on a fare before departure. -/
def cancelExample (fare : Fare) : Except String Json :=
  agree s!"the {fare.key} cancellation example" fun c =>
    match cancellationRefund c.expiry c.fullOrFixed fare.rules trip askedBeforeDeparture (itemAt fare.price) with
    | .refund a _ => Json.mkObj [("fare", toJson fare.key), ("price", money fare.price), ("refund", money a)]
    | .noRule => Json.mkObj [("error", toJson "no rule in force")]

/-- Every fact the pages read, as one JSON document, or the first fact on
which two readings disagree. -/
def facts : Except String Json := do
  let fareObjs ← fares.mapM fun f => return (f.key, ← fareFacts f)
  let (mf, old, new) := mainChangeExample
  let cancels ← fares.mapM fun f => return (f.key ++ "Cancel", ← cancelExample f)
  return Json.mkObj [
    ("generatedBy", toJson "lake exe airline-facts"),
    ("cases", toJson cases.length),
    ("fareOrder", toJson (fares.map (·.key))),
    ("fares", Json.mkObj fareObjs),
    ("examples", Json.mkObj ((mf.key ++ "Change", ← changeExample mf old new) :: cancels))]

/-- The facts as the executable prints them. -/
def factsText : Except String String := (·.pretty) <$> facts

end Airline
