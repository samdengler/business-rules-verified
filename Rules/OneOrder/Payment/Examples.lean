import Rules.Core.Attributes
import Rules.OneOrder.Examples
import Rules.OneOrder.Payment.Status
import Rules.OneOrder.Payment.Accept
import Rules.OneOrder.Payment.Outcome
import Rules.OneOrder.Payment.TimeLimit

/-!
# Examples of payments

Concrete ONE Order payment scenarios the build computes.  Each
{attr}`@[case]` declaration is shown in the review document with its computed
value, and each {lit}`#guard` fails the build if that value changes.
-/

namespace Rules.OneOrder.Payment

open Rules.Core

/-! ## The order the examples pay for -/

/-- A flight service for a passenger on a segment, confirmed and waiting for
payment. -/
def flight (pax seg : String) : Service :=
  { id := "SVC-" ++ pax ++ "-" ++ seg, passenger := ⟨pax⟩, segment := seg,
    status := .confirmed, delivery := .confirmed }

/-- A return trip for one passenger at 100.00 EUR: an outbound and an inbound
flight. -/
def tripItem : OrderItem :=
  { id := "TRIP", fromOfferItem := "OI-TRIP", price := ⟨10000, .EUR⟩,
    services := [flight "PAX-1" "SEG-OUT", flight "PAX-1" "SEG-IN"] }

/-- A checked bag on the outbound flight at 40.00 EUR. -/
def bagItem : OrderItem :=
  { id := "BAG", fromOfferItem := "OI-BAG", price := ⟨4000, .EUR⟩,
    services := [{ flight "PAX-1" "SEG-OUT" with id := "SVC-BAG" }] }

/-- A seat on the outbound flight at no charge. -/
def seatItem : OrderItem :=
  { id := "SEAT", fromOfferItem := "OI-SEAT", price := ⟨0, .EUR⟩,
    services := [{ flight "PAX-1" "SEG-OUT" with id := "SVC-SEAT" }] }

/-- The payment time limit the airline gave: 2026-10-27 12:00 UTC. -/
def payBy : Instant := ⟨1793102400⟩

/-- An instant a number of seconds after the payment time limit, or before it
for a negative number. -/
def payByPlus (seconds : Int) : Instant := ⟨(payBy.epochSeconds + seconds).toNat⟩

/-- The trip and the bag, both unpaid with the same payment time limit. -/
def tripAndBag : PayableOrder :=
  { items := [⟨tripItem, some payBy⟩, ⟨bagItem, some payBy⟩], payments := [] }

/-- The trip, the bag and the free seat, all unpaid with the same payment time
limit. -/
def tripBagSeat : PayableOrder :=
  { items := [⟨tripItem, some payBy⟩, ⟨bagItem, some payBy⟩, ⟨seatItem, some payBy⟩],
    payments := [] }

/-- One payment method's transaction in euros. -/
def part (id : String) (method : Method) (requested surcharge : Nat) (status : PaymentStatus) :
    MethodPart :=
  { id, method, requested := ⟨requested, .EUR⟩, surcharge := ⟨surcharge, .EUR⟩, status }

/-- A payment in euros covering some order items. -/
def payment (id : String) (covers : List String) (parts : List MethodPart) : Transaction :=
  { id, covers, currency := .EUR, parts }

/-- The order after some payments: each payment's outcome applied to the items
in turn, and the payments recorded. -/
def PayableOrder.after (o : PayableOrder) (ps : List Transaction) : PayableOrder :=
  { items := ps.foldl (fun items p => applyOutcome p items) o.items, payments := o.payments ++ ps }

/-- One order item as an example shows it: its reference, whether it is paid,
the delivery statuses of its services and its payment time limit. -/
structure ItemView where
  /-- The order item reference. -/
  item : String
  /-- Whether a SUCCESSFUL payment covers it. -/
  paid : Bool
  /-- The delivery status of each of its services. -/
  delivery : List DeliveryStatus
  /-- Its payment time limit, if it has one. -/
  timeLimit : Option Instant
  deriving DecidableEq, Repr

/-- An order as an example shows it: the status of each payment and each item. -/
structure OrderView where
  /-- The status of each payment, in the order they were made. -/
  payments : List PaymentStatus
  /-- Each order item. -/
  items : List ItemView
  deriving DecidableEq, Repr

/-- Show an order. -/
def OrderView.of (o : PayableOrder) : OrderView :=
  { payments := o.payments.map (·.status),
    items := o.items.map fun pi =>
      { item := pi.item.id, paid := isPaid o.payments pi.item.id,
        delivery := pi.item.services.map (·.delivery), timeLimit := pi.timeLimit } }

/-! ## Payment status from its methods -/

/-- A payment's status for two method outcomes. -/
structure StatusRow where
  /-- The outcome of the settlement plan transaction. -/
  settlementPlan : PaymentStatus
  /-- The outcome of the card transaction. -/
  card : PaymentStatus
  /-- The payment's status. -/
  payment : PaymentStatus
  deriving DecidableEq, Repr

/-- The status of the trip payment split across a settlement plan and a card,
for the given outcomes of the two transactions. -/
def statusRow (sp card : PaymentStatus) : StatusRow :=
  { settlementPlan := sp, card,
    payment := (payment "PAY-1" ["TRIP"]
      [part "TX-1" .settlementPlan 2000 0 sp, part "TX-2" .card 8000 200 card]).status }

/-- *Given* the 100.00 EUR trip, paid with 20.00 EUR by settlement plan and
80.00 EUR by card in one payment.

*When* the two transactions have different outcomes.

*Then* the payment succeeds only when both succeed.  It is pending while the
card is still pending, and it fails as soon as either method fails. -/
@[case, checks "ONE-301.1 ONE-301.2 ONE-301.3"]
def statusFromMethods : List StatusRow :=
  [statusRow .successful .successful, statusRow .successful .pending,
   statusRow .pending .failed, statusRow .successful .failed]

#guard statusFromMethods ==
  [⟨.successful, .successful, .successful⟩, ⟨.successful, .pending, .pending⟩,
   ⟨.pending, .failed, .failed⟩, ⟨.successful, .failed, .failed⟩]

/-! ## Paid items and the effects of an outcome -/

/-- *Given* the trip at 100.00 EUR and the bag at 40.00 EUR, both unpaid.

*When* the seller pays for both in one payment: 100.00 EUR by settlement plan,
which succeeds, and 40.00 EUR by card, which is declined.

*Then* the whole payment fails.  Neither item is paid, and their services stay
confirmed with their payment time limits. -/
@[case, checks "ONE-301.1 ONE-302.3 ONE-305.3"]
def declinedCardForBag : OrderView :=
  .of (tripAndBag.after [payment "PAY-1" ["TRIP", "BAG"]
    [part "TX-1" .settlementPlan 10000 0 .successful, part "TX-2" .card 4000 0 .failed]])

#guard declinedCardForBag ==
  { payments := [.failed],
    items := [⟨"TRIP", false, [.confirmed, .confirmed], some payBy⟩,
              ⟨"BAG", false, [.confirmed], some payBy⟩] }

/-- *Given* the trip at 100.00 EUR and the bag at 40.00 EUR, both unpaid.

*When* the seller pays for them in two payments: the trip by settlement plan,
which succeeds, and the bag by card, which is declined.

*Then* the trip is paid: its flights are ready to proceed and it has no payment
time limit.  The bag is not paid and is unchanged. -/
@[case, checks "ONE-302.1 ONE-302.2 ONE-305.1 ONE-305.2 ONE-305.3 ONE-305.5"]
def twoPaymentsOneDeclined : OrderView :=
  .of (tripAndBag.after
    [payment "PAY-1" ["TRIP"] [part "TX-1" .settlementPlan 10000 0 .successful],
     payment "PAY-2" ["BAG"] [part "TX-2" .card 4000 0 .failed]])

#guard twoPaymentsOneDeclined ==
  { payments := [.successful, .failed],
    items := [⟨"TRIP", true, [.readyToProceed, .readyToProceed], none⟩,
              ⟨"BAG", false, [.confirmed], some payBy⟩] }

/-- *Given* the trip at 100.00 EUR, unpaid.

*When* the customer starts a redirected card payment for it and has not yet
completed it.

*Then* the payment is pending, the trip is not paid, and its flights stay
confirmed with their payment time limit. -/
@[case, checks "ONE-302.2 ONE-305.4"]
def pendingRedirect : OrderView :=
  .of (tripAndBag.after [payment "PAY-1" ["TRIP"] [part "TX-1" .card 10000 0 .pending]])

#guard pendingRedirect ==
  { payments := [.pending],
    items := [⟨"TRIP", false, [.confirmed, .confirmed], some payBy⟩,
              ⟨"BAG", false, [.confirmed], some payBy⟩] }

/-! ## Recording outcomes -/

/-- The final reading: a transaction leaves PENDING once and never moves again. -/
def finalReading : OutcomeReading where
  allows a b := a == .pending || a == b
  pendingToSuccessful := rfl
  pendingToFailed := rfl

/-- The chargeback reading: as the final reading, and a SUCCESSFUL card
transaction may later fail, for example after a chargeback. -/
def chargebackReading : OutcomeReading where
  allows a b := a == .pending || a == b || (a == .successful && b == .failed)
  pendingToSuccessful := rfl
  pendingToFailed := rfl

/-- The late capture reading: as the final reading, and a FAILED transaction may
later succeed, for example when a customer completes a redirected payment after
the airline marked it failed. -/
def lateCaptureReading : OutcomeReading where
  allows a b := a == .pending || a == b || (a == .failed && b == .successful)
  pendingToSuccessful := rfl
  pendingToFailed := rfl

/-- One method's transaction before and after an outcome was reported. -/
structure MethodRow where
  /-- The transaction reference. -/
  transaction : String
  /-- The payment method. -/
  method : Method
  /-- Its status before the report. -/
  before : PaymentStatus
  /-- Its status after the report. -/
  after : PaymentStatus
  deriving DecidableEq, Repr

/-- A payment before and after an outcome was reported. -/
structure Recorded where
  /-- Each method's transaction. -/
  methods : List MethodRow
  /-- The payment's status before the report. -/
  paymentBefore : PaymentStatus
  /-- The payment's status after the report. -/
  paymentAfter : PaymentStatus
  deriving DecidableEq, Repr

/-- Show a payment before and after a report. -/
def Recorded.of (before after : Transaction) : Recorded :=
  { methods := (before.parts.zip after.parts).map fun (m, m') =>
      { transaction := m.id, method := m.method, before := m.status, after := m'.status },
    paymentBefore := before.status, paymentAfter := after.status }

/-- The trip payment with its settlement plan part settled and its card part
waiting on a redirected payment. -/
def redirectWaiting : Transaction :=
  payment "PAY-1" ["TRIP"]
    [part "TX-1" .settlementPlan 2000 0 .successful, part "TX-2" .card 8000 200 .pending]

/-- *Given* the trip payment: 20.00 EUR by settlement plan, already successful,
and 80.00 EUR by card through a redirect, still pending.

*When* the customer completes the redirect and the airline reports the card
transaction successful.

*Then* the card transaction is recorded as successful, the settlement plan
transaction is unchanged, and the payment becomes successful. -/
@[case, checks "ONE-303.1 ONE-303.2"]
def redirectCompletes : Recorded :=
  .of redirectWaiting (recordOutcome finalReading redirectWaiting "TX-2" .successful)

#guard redirectCompletes ==
  { methods := [⟨"TX-1", .settlementPlan, .successful, .successful⟩,
                ⟨"TX-2", .card, .pending, .successful⟩],
    paymentBefore := .pending, paymentAfter := .successful }

/-- A payment's status after a report, under two readings of the guide. -/
structure Readings where
  /-- The payment's status before the report. -/
  before : PaymentStatus
  /-- Its status after the report, under the final reading. -/
  underFinalReading : PaymentStatus
  /-- Its status after the report, under the other reading. -/
  underOtherReading : PaymentStatus
  deriving DecidableEq, Repr

/-- The trip paid in full by card, successful. -/
def paidByCard : Transaction := payment "PAY-1" ["TRIP"] [part "TX-1" .card 10000 0 .successful]

/-- *Given* the trip paid by card, with a successful payment.

*When* the card holder disputes the charge and the airline reports the card
transaction failed.

*Then* under the final reading the payment stays successful.  Under the
chargeback reading, where a successful transaction may later fail, the payment
becomes failed. -/
@[case, checks "ONE-303.3"]
def chargeback : Readings :=
  { before := paidByCard.status,
    underFinalReading := (recordOutcome finalReading paidByCard "TX-1" .failed).status,
    underOtherReading := (recordOutcome chargebackReading paidByCard "TX-1" .failed).status }

#guard chargeback ==
  { before := .successful, underFinalReading := .successful, underOtherReading := .failed }

/-- What happened to a redirected payment completed after the time limit. -/
structure LateCapture where
  /-- The payment's status once the time limit passed. -/
  paymentAtLimit : PaymentStatus
  /-- The trip's delivery statuses once the time limit passed. -/
  tripAtLimit : List DeliveryStatus
  /-- The payment's status after the late report, under the final reading. -/
  underFinalReading : PaymentStatus
  /-- The payment's status after the late report, under the late capture reading. -/
  underLateCaptureReading : PaymentStatus
  /-- The trip's delivery statuses after the late report is applied, under the
  late capture reading. -/
  tripAfterCapture : List DeliveryStatus
  deriving DecidableEq, Repr

/-- The removal the examples use: the services are cancelled and removed. -/
def cancelRemove : Removal := ⟨.cancelled, .removed⟩

/-- The trip, unpaid, with a redirected card payment for it still pending. -/
def tripAwaitingRedirect : PayableOrder :=
  { items := [⟨tripItem, some payBy⟩],
    payments := [payment "PAY-1" ["TRIP"] [part "TX-1" .card 10000 0 .pending]] }

/-- The trip order once its payment time limit has passed. -/
def tripAtLimit : PayableOrder := expireUnpaid cancelRemove payBy tripAwaitingRedirect

/-- *Given* the trip at 100.00 EUR, unpaid, with a redirected card payment for
it still pending.

*When* the payment time limit passes, and one minute later the customer
completes the redirect and the airline reports the card transaction successful.

*Then* at the limit the trip is removed and the payment fails.  Under the final
reading the late report changes nothing.  Under the late capture reading the
payment becomes successful, but the trip's flights stay removed: the customer
has paid for nothing. -/
@[case, checks "ONE-303.3 ONE-306.1 ONE-306.2"]
def lateRedirectCapture : LateCapture :=
  let atLimit := tripAtLimit.payments.head!
  let captured := recordOutcome lateCaptureReading atLimit "TX-1" .successful
  { paymentAtLimit := atLimit.status,
    tripAtLimit := tripAtLimit.items.flatMap (·.item.services.map (·.delivery)),
    underFinalReading := (recordOutcome finalReading atLimit "TX-1" .successful).status,
    underLateCaptureReading := captured.status,
    tripAfterCapture :=
      (applyOutcome captured tripAtLimit.items).flatMap (·.item.services.map (·.delivery)) }

#guard lateRedirectCapture ==
  { paymentAtLimit := .failed, tripAtLimit := [.removed, .removed],
    underFinalReading := .failed, underLateCaptureReading := .successful,
    tripAfterCapture := [.removed, .removed] }

/-! ## Accepting a payment -/

/-- What one payment method is charged. -/
structure ChargeRow where
  /-- The payment method. -/
  method : Method
  /-- The amount requested from it. -/
  requested : Money
  /-- Its surcharge. -/
  surcharge : Money
  /-- The amount charged to it. -/
  charged : Money
  deriving DecidableEq, Repr

/-- What an accepted payment charges. -/
structure Charges where
  /-- Each method's charge. -/
  methods : List ChargeRow
  /-- The total charged. -/
  total : Money
  deriving DecidableEq, Repr

/-- Try a payment, and show what it charges if it is accepted. -/
def tryPayment (o : PayableOrder) (p : Transaction) (now : Instant) :
    Except PaymentRejection Charges :=
  (acceptPayment o p now).map fun cs =>
    { methods := (p.parts.zip cs).map fun (m, c) =>
        { method := m.method, requested := m.requested, surcharge := m.surcharge, charged := c },
      total := ⟨(cs.map (·.amount)).sum, p.currency⟩ }

/-- The trip paid with 20.00 EUR by settlement plan and 80.00 EUR by card, on
which the airline adds a 2.00 EUR surcharge. -/
def splitPayment : Transaction :=
  payment "PAY-1" ["TRIP"]
    [part "TX-1" .settlementPlan 2000 0 .pending, part "TX-2" .card 8000 200 .pending]

/-- *Given* the trip at 100.00 EUR, unpaid, with its payment time limit an hour
away.

*When* the seller pays 20.00 EUR by settlement plan and 80.00 EUR by card, on
which the airline adds a 2.00 EUR surcharge.

*Then* the payment is accepted.  The settlement plan is charged 20.00 EUR and
the card 82.00 EUR, 102.00 EUR in all: the price plus the surcharge. -/
@[case, checks "ONE-304.1 ONE-304.3"]
def splitPaymentCharges : Except PaymentRejection Charges :=
  tryPayment tripBagSeat splitPayment (payByPlus (-3600))

#guard splitPaymentCharges ==
  .ok { methods := [⟨.settlementPlan, ⟨2000, .EUR⟩, ⟨0, .EUR⟩, ⟨2000, .EUR⟩⟩,
                    ⟨.card, ⟨8000, .EUR⟩, ⟨200, .EUR⟩, ⟨8200, .EUR⟩⟩],
        total := ⟨10200, .EUR⟩ }

/-- *Given* the trip at 100.00 EUR, unpaid, with its payment time limit an hour
away.

*When* the seller requests 20.00 EUR from the settlement plan and 82.00 EUR
from the card, counting the card's 2.00 EUR surcharge toward the price.

*Then* the payment is rejected: the requested amounts add up to 102.00 EUR,
and the trip costs 100.00 EUR. -/
@[case, checks "ONE-304.2"]
def surchargeCountedAsPrice : Except PaymentRejection Charges :=
  tryPayment tripBagSeat
    (payment "PAY-1" ["TRIP"]
      [part "TX-1" .settlementPlan 2000 0 .pending, part "TX-2" .card 8200 200 .pending])
    (payByPlus (-3600))

#guard surchargeCountedAsPrice == .error .amountMismatch

/-- *Given* the trip at 100.00 EUR, unpaid, with a payment time limit of
2026-10-27 12:00 UTC.

*When* the seller pays for it in full at 12:01 UTC.

*Then* the payment is rejected because the time limit has passed. -/
@[case, checks "ONE-304.4"]
def paymentAfterTimeLimit : Except PaymentRejection Charges :=
  tryPayment tripBagSeat splitPayment (payByPlus 60)

#guard paymentAfterTimeLimit == .error .timeLimitPassed

/-- *Given* the free seat, unpaid, with its payment time limit an hour away.

*When* the seller commits to pay for it with the commitment method and an
amount of zero.

*Then* the payment is accepted, and nothing is charged. -/
@[case, checks "ONE-304.5 ONE-304.6"]
def commitmentForFreeSeat : Except PaymentRejection Charges :=
  tryPayment tripBagSeat (payment "PAY-1" ["SEAT"] [part "TX-1" .commitment 0 0 .pending])
    (payByPlus (-3600))

#guard commitmentForFreeSeat ==
  .ok { methods := [⟨.commitment, ⟨0, .EUR⟩, ⟨0, .EUR⟩, ⟨0, .EUR⟩⟩], total := ⟨0, .EUR⟩ }

/-- *Given* the bag at 40.00 EUR and the free seat, both unpaid, with their
payment time limit an hour away.

*When* the seller pays for both in one payment: 40.00 EUR by card and a
commitment of zero for the seat.

*Then* the payment is rejected: the commitment method may only cover items
with nothing to pay, and the bag costs 40.00 EUR.  A card payment of 40.00 EUR
alone may cover both. -/
@[case, checks "ONE-304.6"]
def commitmentBesideCard : Except PaymentRejection Charges :=
  tryPayment tripBagSeat
    (payment "PAY-1" ["BAG", "SEAT"]
      [part "TX-1" .card 4000 0 .pending, part "TX-2" .commitment 0 0 .pending])
    (payByPlus (-3600))

#guard commitmentBesideCard == .error .commitmentWithAmountDue

/-! ## Payment time limits -/

/-- *Given* the trip and the bag, due by 2026-10-27 12:00 UTC, and the free
seat, due a day later.  The bag was paid by card.  A redirected card payment
for the trip is still pending.

*When* the trip's payment time limit passes, with removal to the statuses
CANCELLED and REMOVED.

*Then* the trip is removed and its pending payment fails.  The paid bag stays
ready to proceed, and the seat, whose limit has not passed, is unchanged. -/
@[case, checks "ONE-306.1 ONE-306.2 ONE-306.3 ONE-306.4"]
def unpaidAtTimeLimit : OrderView :=
  .of (expireUnpaid cancelRemove payBy
    ({ tripBagSeat with
        items := [⟨tripItem, some payBy⟩, ⟨bagItem, some payBy⟩,
                  ⟨seatItem, some (payByPlus 86400)⟩] }.after
      [payment "PAY-1" ["BAG"] [part "TX-1" .card 4000 0 .successful],
       payment "PAY-2" ["TRIP"] [part "TX-2" .card 10000 0 .pending]]))

#guard unpaidAtTimeLimit ==
  { payments := [.successful, .failed],
    items := [⟨"TRIP", false, [.removed, .removed], some payBy⟩,
              ⟨"BAG", true, [.readyToProceed], none⟩,
              ⟨"SEAT", false, [.confirmed], some (payByPlus 86400)⟩] }

/-- *Given* an order created without payment, where the airline gave the trip
no payment time limit.

*When* a year has passed and nothing has been paid.

*Then* the trip is still in the order with its flights confirmed, holding its
seats with nothing paid. -/
@[case, checks "ONE-306.5"]
def noTimeLimit : OrderView :=
  .of (expireUnpaid cancelRemove (payByPlus (365 * 86400))
    { items := [⟨tripItem, none⟩], payments := [] })

#guard noTimeLimit ==
  { payments := [], items := [⟨"TRIP", false, [.confirmed, .confirmed], none⟩] }

/-- The statuses of an item removed at its payment time limit, for one choice of
delivery status. -/
structure RemovalRow where
  /-- The delivery status the removed item's services take. -/
  removedAs : DeliveryStatus
  /-- The item's statuses under the cautious reading of the guide. -/
  cautious : List ItemStatus
  /-- The item's statuses under the strict reading of the guide. -/
  strict : List ItemStatus
  deriving DecidableEq, Repr

/-- The trip's statuses after its payment time limit passes unpaid, when its
services are cancelled and take the given delivery status. -/
def removalRow (d : DeliveryStatus) : RemovalRow :=
  let items := (expireUnpaid ⟨.cancelled, d⟩ payBy { items := [⟨tripItem, some payBy⟩], payments := [] }).items
  { removedAs := d,
    cautious := items.flatMap (itemStatuses cautiousReading ·.item),
    strict := items.flatMap (itemStatuses strictReading ·.item) }

/-- *Given* the trip at 100.00 EUR, unpaid, with a payment time limit.

*When* the limit passes and the trip is removed, its services cancelled and
given one of three delivery statuses.

*Then* with REMOVED the item is cancelled under both readings of the guide.
With EXPIRED it stays active under the cautious reading, where an expired
service holds value.  With REMOVED HOLD VALUE it stays active under both. -/
@[case, checks "ONE-306.6"]
def removalStatuses : List RemovalRow :=
  [removalRow .removed, removalRow .expired, removalRow .removedHoldValue]

#guard removalStatuses ==
  [⟨.removed, [.cancelled], [.cancelled]⟩, ⟨.expired, [.active], [.cancelled]⟩,
   ⟨.removedHoldValue, [.active], [.active]⟩]

end Rules.OneOrder.Payment
