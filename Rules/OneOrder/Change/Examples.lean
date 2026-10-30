import Rules.Core.Attributes
import Rules.OneOrder.Examples
import Rules.OneOrder.Change.Balance
import Rules.OneOrder.Change.Cancel
import Rules.OneOrder.Change.Transfer

/-!
# Examples of changes and cancellations

Concrete changes and cancellations the build computes.  The amounts follow the
guide's worked examples where the survey recorded them; the orders and
references are our own.
-/

namespace Rules.OneOrder.Change

open Rules.Core

/-- An amount in whole euros. -/
def euros (n : Nat) : Money := ⟨n * 100, .EUR⟩

/-! ## Price differentials -/

/-- One priced change or cancellation: what it is, what the customer pays, what
the airline returns, and the type code. -/
structure PricedCase where
  /-- What is priced. -/
  case : String
  /-- What the customer pays the airline. -/
  dueToAirline : Money
  /-- What the airline returns or stores for the customer. -/
  dueByAirline : Money
  /-- The type code. -/
  type : DifferentialType
  deriving DecidableEq, Repr

/-- Price a change under a reading of the guide and show the result, or
nothing if the change is rejected. -/
def PricedCase.of (case : String) (r : ExcessPenalty) (q : ChangeQuote) : Option PricedCase :=
  match priceDifferential r q with
  | .ok d => some { case, dueToAirline := d.dueToAirline, dueByAirline := d.dueByAirline, type := d.type }
  | .error _ => none

/-- A priced change next to what the formula of ONE-201.5 requires: the new
price, less the old price, plus the penalty, plus the forfeited amount, shown
as an amount to or by the airline. -/
structure FormulaCase where
  /-- What is priced. -/
  case : String
  /-- What the customer pays the airline. -/
  dueToAirline : Money
  /-- What the airline returns or stores for the customer. -/
  dueByAirline : Money
  /-- The type code. -/
  type : DifferentialType
  /-- What the customer would pay under the formula. -/
  formulaToAirline : Money
  /-- What the airline would return under the formula. -/
  formulaByAirline : Money
  deriving DecidableEq, Repr

/-- Price a change under a reading of the guide and show it next to the
formula, or nothing if the change is rejected. -/
def FormulaCase.of (case : String) (r : ExcessPenalty) (q : ChangeQuote) : Option FormulaCase :=
  let f : Int := (q.newPrice.amount : Int) - q.oldPrice.amount + q.penalty.amount + q.forfeited.amount
  match priceDifferential r q with
  | .ok d => some { case, dueToAirline := d.dueToAirline, dueByAirline := d.dueByAirline, type := d.type,
                    formulaToAirline := ⟨f.toNat, q.oldPrice.currency⟩,
                    formulaByAirline := ⟨(-f).toNat, q.oldPrice.currency⟩ }
  | .error _ => none

/-- *Given* a paid trip at 1,000.00 EUR, of which 120.00 EUR is forfeited,
changed to a trip at 900.00 EUR with a penalty of 40.00 EUR netted.  These are
the figures of worked example {lit}`EXM_ORD_003C`.

*When* the airline prices the change.

*Then* the customer pays 60.00 EUR, the airline returns nothing, and the type
code is AddCol, as in the worked example. -/
@[case, checks "ONE-201.2 ONE-202.1"]
def changeWithCollection : List PricedCase :=
  [PricedCase.of "change to a cheaper trip" .collect
    { oldPrice := euros 1000, newPrice := euros 900, penalty := euros 40, forfeited := euros 120,
      handling := .netted, settlement := .refund }].filterMap id

#guard changeWithCollection ==
  [{ case := "change to a cheaper trip", dueToAirline := euros 60, dueByAirline := euros 0, type := .addCol }]

/-- *Given* a paid order at 1,000.00 EUR, of which 20.00 EUR is forfeited,
cancelled with a penalty of 50.00 EUR netted and a refund.  These are the
figures of worked example {lit}`EXM_ORD_030B`.

*When* the airline prices the cancellation.

*Then* the airline refunds 930.00 EUR and the type code is Refund, as in the
worked example. -/
@[case, checks "ONE-201.3 ONE-202.1"]
def cancellationWithForfeit : List PricedCase :=
  [PricedCase.of "cancellation" .collect
    { oldPrice := euros 1000, newPrice := euros 0, penalty := euros 50, forfeited := euros 20,
      handling := .netted, settlement := .refund }].filterMap id

#guard cancellationWithForfeit ==
  [{ case := "cancellation", dueToAirline := euros 0, dueByAirline := euros 930, type := .refund }]

/-- *Given* a paid trip at 1,000.00 EUR changed to a trip at 840.00 EUR with a
penalty of 60.00 EUR, where the airline keeps what it owes in a value store.
The amounts due match worked example {lit}`EXM_ORD_003G`.

*When* the airline prices the change with the penalty netted, and again with
the penalty charged separately.

*Then* netted, the customer pays nothing and 100.00 EUR goes to a value store.
Charged separately, the customer pays 60.00 EUR and 160.00 EUR goes to a value
store.  Either way the customer is 100.00 EUR better off. -/
@[case, checks "ONE-201.2 ONE-201.3 ONE-202.2 ONE-202.3"]
def penaltyNettedOrSeparate : List PricedCase :=
  [PricedCase.of "penalty netted" .collect
    { oldPrice := euros 1000, newPrice := euros 840, penalty := euros 60, forfeited := euros 0,
      handling := .netted, settlement := .valueStore },
   PricedCase.of "penalty charged separately" .collect
    { oldPrice := euros 1000, newPrice := euros 840, penalty := euros 60, forfeited := euros 0,
      handling := .separate, settlement := .valueStore }].filterMap id

#guard penaltyNettedOrSeparate ==
  [{ case := "penalty netted", dueToAirline := euros 0, dueByAirline := euros 100, type := .residual },
   { case := "penalty charged separately", dueToAirline := euros 60, dueByAirline := euros 160,
     type := .addColAndResidual }]

/-- *Given* a change priced in euros whose penalty is stated in US dollars.
The guide's sample change record shows a similar mismatch between the
currency of its prices and that of its due amount.

*When* the airline prices the change.

*Then* the change is rejected unpriced. -/
@[case, checks "ONE-201.1"]
def mixedCurrencyChange : Except QuoteRejection PriceDifferential :=
  priceDifferential .collect
    { oldPrice := euros 1000, newPrice := euros 900, penalty := ⟨4000, .USD⟩, forfeited := euros 0,
      handling := .netted, settlement := .refund }

#guard mixedCurrencyChange == .error .mixedCurrency

/-- *Given* a paid order at 1,000.00 EUR, cancelled with no penalty and no
forfeit, where the seller asks to keep the value for later use.  This is
worked example {lit}`EXM_ORD_030E`.

*When* the airline prices the cancellation.

*Then* the differential is typed Reusable with both due amounts zero, as in the
worked example.  The formula of ONE-201.5 requires 1,000.00 EUR due by the
airline. -/
@[case, checks "ONE-201.4 ONE-201.5"]
def respendCancellation : List FormulaCase :=
  [FormulaCase.of "keep the value for later use" .collect
    { oldPrice := euros 1000, newPrice := euros 0, penalty := euros 0, forfeited := euros 0,
      handling := .netted, settlement := .respend }].filterMap id

#guard respendCancellation ==
  [{ case := "keep the value for later use", dueToAirline := euros 0, dueByAirline := euros 0,
     type := .reusable, formulaToAirline := euros 0, formulaByAirline := euros 1000 }]

/-- *Given* the cancellation of worked example {lit}`EXM_ORD_030B` (a paid
order at 1,000.00 EUR with 20.00 EUR forfeited) with a penalty of
1,000.00 EUR netted in place of 50.00 EUR.  The refundable value is
980.00 EUR, less than the penalty.

*When* the airline prices the cancellation under each reading of the guide.

*Then* under the reading that collects the whole penalty, the customer owes
20.00 EUR on a cancellation.  Under the reading that waives the excess,
nothing is due either way, while the formula of ONE-201.5 requires
20.00 EUR due to the airline. -/
@[case, checks "ONE-201.5 ONE-202.4"]
def penaltyAboveRefund : List FormulaCase :=
  let q : ChangeQuote :=
    { oldPrice := euros 1000, newPrice := euros 0, penalty := euros 1000, forfeited := euros 20,
      handling := .netted, settlement := .refund }
  [FormulaCase.of "collect the whole penalty" .collect q,
   FormulaCase.of "waive the excess" .waive q].filterMap id

#guard penaltyAboveRefund ==
  [{ case := "collect the whole penalty", dueToAirline := euros 20, dueByAirline := euros 0,
     type := .addCol, formulaToAirline := euros 20, formulaByAirline := euros 0 },
   { case := "waive the excess", dueToAirline := euros 0, dueByAirline := euros 0,
     type := .evenExchange, formulaToAirline := euros 20, formulaByAirline := euros 0 }]

/-! ## Cancelling an order -/

/-- A return trip for one passenger at 1,000.00 EUR: one order item with an
outbound and an inbound flight, both in the given delivery status. -/
def tripOrder (delivery : DeliveryStatus) : Order where
  id := "ORD-CHG-1"
  items :=
    [ { id := "ORDITM-1", fromOfferItem := "OI-1", price := euros 1000,
        services :=
          [ { id := "SVC-OUT", passenger := ⟨"PAX-1"⟩, segment := "SEG-OUT", status := .confirmed,
              delivery := delivery },
            { id := "SVC-IN", passenger := ⟨"PAX-1"⟩, segment := "SEG-IN", status := .confirmed,
              delivery := delivery } ] } ]
  createdAt := ⟨1793102400⟩

/-- A payment received for the trip order. -/
def tripPayment (amount : Money) : Rules.OfferOrder.Payment :=
  { id := "PAY-CHG-1", order := "ORD-CHG-1", amount := amount }

/-- How a cancellation goes. -/
inductive CancelRoute
  /-- Cancelled at once, with no offer. -/
  | atOnce
  /-- Through a cancellation offer. -/
  | throughOffer
  /-- Rejected unpriced. -/
  | rejected
  deriving DecidableEq, Repr

/-- What a request to cancel an order led to. -/
structure CancelSummary where
  /-- The payments received for the order. -/
  received : Money
  /-- How the order is cancelled. -/
  route : CancelRoute
  /-- What the airline owes on the offer; zero when the order is cancelled at
  once. -/
  dueByAirline : Money
  /-- The order's statuses under the two readings of the guide: after the
  cancellation if it was made at once, and otherwise while the offer is open. -/
  orderStatus : OrderStatuses
  deriving DecidableEq, Repr

/-- Summarise a request to cancel an order. -/
def CancelSummary.of (o : Order) (payments : List Rules.OfferOrder.Payment) (t : CancelTerms) :
    CancelSummary :=
  let received : Money := ⟨Rules.OfferOrder.totalPaid payments o.id, .EUR⟩
  match requestCancellation .collect o payments t with
  | .cancelled o' => { received, route := .atOnce, dueByAirline := euros 0, orderStatus := .of o' }
  | .offer d => { received, route := .throughOffer, dueByAirline := d.dueByAirline, orderStatus := .of o }
  | .rejected _ => { received, route := .rejected, dueByAirline := euros 0, orderStatus := .of o }

/-- Cancellation terms with no penalty and no forfeit, settled by a refund. -/
def freeCancellation : CancelTerms :=
  { penalty := euros 0, forfeited := euros 0, handling := .netted, settlement := .refund }

/-- *Given* the trip order at 1,000.00 EUR, confirmed and waiting for payment,
with no payment received.

*When* the seller asks to cancel it.

*Then* it is cancelled at once, with no offer and nothing due.  Every service
is cancelled and removed, and the order is closed under both readings. -/
@[case, checks "ONE-203.1 ONE-203.2"]
def unpaidCancellation : CancelSummary :=
  .of (tripOrder .confirmed) [] freeCancellation

#guard unpaidCancellation ==
  { received := euros 0, route := .atOnce, dueByAirline := euros 0,
    orderStatus := { cautious := [.closed], strict := [.closed] } }

/-- *Given* the trip order at 1,000.00 EUR, paid in full and ready to proceed,
with a cancellation penalty of 50.00 EUR netted and 20.00 EUR forfeited.

*When* the seller asks to cancel it.

*Then* it needs a cancellation offer, which refunds 930.00 EUR.  The order stays
opened until the seller accepts the offer. -/
@[case, checks "ONE-203.3"]
def paidCancellation : CancelSummary :=
  .of (tripOrder .readyToProceed) [tripPayment (euros 1000)]
    { penalty := euros 50, forfeited := euros 20, handling := .netted, settlement := .refund }

#guard paidCancellation ==
  { received := euros 1000, route := .throughOffer, dueByAirline := euros 930,
    orderStatus := { cautious := [.opened], strict := [.opened] } }

/-- *Given* the trip order at 1,000.00 EUR, still waiting for full payment,
with 300.00 EUR received, and no penalty or forfeit.

*When* the seller asks to cancel it.

*Then* it needs a cancellation offer, as for any order with a payment.  The
offer is priced from the order's price and has 1,000.00 EUR due by the
airline, more than the 300.00 EUR received. -/
@[case, checks "ONE-203.3 ONE-203.4"]
def partlyPaidCancellation : CancelSummary :=
  .of (tripOrder .confirmed) [tripPayment (euros 300)] freeCancellation

#guard partlyPaidCancellation ==
  { received := euros 300, route := .throughOffer, dueByAirline := euros 1000,
    orderStatus := { cautious := [.opened], strict := [.opened] } }

/-! ## Changing an order item -/

/-- One order item after a change, with its statuses under the two readings
of the guide. -/
structure ItemAfterChange where
  /-- The order item reference. -/
  item : String
  /-- The item's price. -/
  price : Money
  /-- The item's statuses under the cautious reading. -/
  cautious : List ItemStatus
  /-- The item's statuses under the strict reading. -/
  strict : List ItemStatus
  deriving DecidableEq, Repr

/-- One service after a change, with the item that holds it. -/
structure ServiceAfterChange where
  /-- The order item reference. -/
  item : String
  /-- The service reference. -/
  service : String
  /-- The service status. -/
  status : ServiceStatus
  /-- The delivery status. -/
  delivery : DeliveryStatus
  deriving DecidableEq, Repr

/-- The order after a change: its items and its services. -/
structure ChangedOrder where
  /-- The order items and their statuses. -/
  items : List ItemAfterChange
  /-- The services, item by item. -/
  services : List ServiceAfterChange
  deriving DecidableEq, Repr

/-- Summarise an order after a change. -/
def ChangedOrder.of (o : Order) : ChangedOrder where
  items := o.items.map fun i =>
    { item := i.id, price := i.price, cautious := itemStatuses cautiousReading i,
      strict := itemStatuses strictReading i }
  services := o.items.flatMap fun i =>
    i.services.map fun s => { item := i.id, service := s.id, status := s.status, delivery := s.delivery }

/-- A paid change of the trip order's item to a new item at 900.00 EUR with a
new inbound flight, keeping the services given. -/
def tripChange (newItem : String) (kept : List String) : ItemChange :=
  { item := "ORDITM-1", newItem := newItem, fromOfferItem := "OI-2", newPrice := euros 900,
    kept := kept,
    added := [{ id := "SVC-IN-2", passenger := ⟨"PAX-1"⟩, segment := "SEG-IN-2", status := .confirmed,
                delivery := .readyToProceed }] }

/-- *Given* the trip order, paid and ready to proceed.

*When* the seller accepts and pays a change that keeps the outbound flight and
replaces the inbound flight, in a new item at 900.00 EUR.  This is the shape of
worked example {lit}`EXM_ORD_003B`.

*Then* the new item holds the outbound service under the same reference, and
the original copy is transferred and still READY TO PROCEED.  The replaced
inbound service is cancelled and removed.  Under both readings the original
item is active, where the worked example shows it cancelled, and the outbound
service holds value in both items. -/
@[case, checks "ONE-204.1 ONE-204.2 ONE-204.3 ONE-204.5"]
def changeKeepingOutbound : Except ChangeRejection ChangedOrder :=
  (changeItem (tripOrder .readyToProceed) (tripChange "ORDITM-2" ["SVC-OUT"])).map ChangedOrder.of

#guard changeKeepingOutbound == .ok
  { items :=
      [ { item := "ORDITM-1", price := euros 1000, cautious := [.active], strict := [.active] },
        { item := "ORDITM-2", price := euros 900, cautious := [.active], strict := [.active] } ],
    services :=
      [ { item := "ORDITM-1", service := "SVC-OUT", status := .transferred, delivery := .readyToProceed },
        { item := "ORDITM-1", service := "SVC-IN", status := .cancelled, delivery := .removed },
        { item := "ORDITM-2", service := "SVC-OUT", status := .confirmed, delivery := .readyToProceed },
        { item := "ORDITM-2", service := "SVC-IN-2", status := .confirmed,
          delivery := .readyToProceed } ] }

/-- *Given* the trip order, paid and ready to proceed.

*When* the seller accepts and pays a change that keeps no service and puts a
new inbound flight in a new item at 900.00 EUR.

*Then* both original services are cancelled and removed, and the original item
is cancelled under both readings. -/
@[case, checks "ONE-204.3"]
def changeReplacingAll : Except ChangeRejection ChangedOrder :=
  (changeItem (tripOrder .readyToProceed) (tripChange "ORDITM-2" [])).map ChangedOrder.of

#guard changeReplacingAll == .ok
  { items :=
      [ { item := "ORDITM-1", price := euros 1000, cautious := [.cancelled], strict := [.cancelled] },
        { item := "ORDITM-2", price := euros 900, cautious := [.active], strict := [.active] } ],
    services :=
      [ { item := "ORDITM-1", service := "SVC-OUT", status := .cancelled, delivery := .removed },
        { item := "ORDITM-1", service := "SVC-IN", status := .cancelled, delivery := .removed },
        { item := "ORDITM-2", service := "SVC-IN-2", status := .confirmed,
          delivery := .readyToProceed } ] }

/-- *Given* the trip order, paid and ready to proceed.

*When* the seller asks for a change whose new item would reuse the reference
of the item being changed.

*Then* the change is refused, so the order's item references stay distinct. -/
@[case, checks "ONE-204.4"]
def changeReusingReference : Except ChangeRejection ChangedOrder :=
  (changeItem (tripOrder .readyToProceed) (tripChange "ORDITM-1" ["SVC-OUT"])).map ChangedOrder.of

#guard changeReusingReference == .error .duplicateItemReference

/-! ## Order balance -/

/-- The money on an order at one stage, next to the price of its live items. -/
structure BalanceRow where
  /-- The stage of the order. -/
  stage : String
  /-- Everything the customer has paid. -/
  paid : Money
  /-- Everything the airline has returned. -/
  refunded : Money
  /-- The price of the items that hold value, the same under both readings
  here. -/
  liveItems : Money
  /-- The penalties recorded. -/
  penalties : Money
  /-- The forfeited amounts recorded. -/
  forfeited : Money
  /-- Whether payments less refunds equal live items plus penalties plus
  forfeited amounts. -/
  balanced : Bool
  deriving DecidableEq, Repr

/-- Show an order's ledger at one stage, under the strict reading. -/
def BalanceRow.of (stage : String) (o : Order) (l : Ledger) : BalanceRow :=
  { stage, paid := ⟨l.paid, .EUR⟩, refunded := ⟨l.refunded, .EUR⟩,
    liveItems := ⟨liveValue strictReading o, .EUR⟩, penalties := ⟨l.penalties, .EUR⟩,
    forfeited := ⟨l.forfeited, .EUR⟩,
    balanced := decide ((l.paid : Int) - l.refunded = liveValue strictReading o + l.penalties + l.forfeited) }

/-- The trip order's ledger after a change to a 900.00 EUR trip with a
40.00 EUR penalty and 120.00 EUR forfeited, keeping the services given. -/
def balanceAfter (stage : String) (kept : List String) : Option BalanceRow :=
  let l : Ledger := { paid := 100000, refunded := 0, penalties := 0, forfeited := 0 }
  let q : ChangeQuote :=
    { oldPrice := euros 1000, newPrice := euros 900, penalty := euros 40, forfeited := euros 120,
      handling := .netted, settlement := .refund }
  match changeItem (tripOrder .readyToProceed) (tripChange "ORDITM-2" kept), priceDifferential .collect q with
  | .ok o', .ok d => some (.of stage o' (settle l d))
  | _, _ => none

/-- *Given* the trip order, paid 1,000.00 EUR and ready to proceed, with nothing
refunded and nothing recorded.  It is balanced.

*When* the seller accepts and pays a change to a 900.00 EUR trip with a
40.00 EUR penalty and 120.00 EUR forfeited, the figures of worked example
{lit}`EXM_ORD_003C`.  The change keeps the outbound flight, or keeps nothing.

*Then* the customer pays 60.00 EUR more either way.  With nothing kept, the
order balances: 1,060.00 EUR paid equals 900.00 EUR of live items plus
160.00 EUR recorded.  With the outbound flight kept, the original item still
counts as live, and the order does not balance. -/
@[case, checks "ONE-205.1 ONE-205.2 ONE-205.3"]
def changeBalance : List BalanceRow :=
  [some (.of "before the change" (tripOrder .readyToProceed)
      { paid := 100000, refunded := 0, penalties := 0, forfeited := 0 }),
   balanceAfter "after a change keeping the outbound flight" ["SVC-OUT"],
   balanceAfter "after a change keeping nothing" []].filterMap id

#guard changeBalance ==
  [{ stage := "before the change", paid := euros 1000, refunded := euros 0, liveItems := euros 1000,
     penalties := euros 0, forfeited := euros 0, balanced := true },
   { stage := "after a change keeping the outbound flight", paid := euros 1060, refunded := euros 0,
     liveItems := euros 1900, penalties := euros 40, forfeited := euros 120, balanced := false },
   { stage := "after a change keeping nothing", paid := euros 1060, refunded := euros 0,
     liveItems := euros 900, penalties := euros 40, forfeited := euros 120, balanced := true }]

end Rules.OneOrder.Change
