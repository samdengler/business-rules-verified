import Rules.Core.Attributes
import Rules.OneOrder.Accounting.Commission
import Rules.OneOrder.Accounting.Clearance
import Rules.OneOrder.Accounting.Clearing
import Rules.OneOrder.Accounting.Books

/-!
# Examples of commission, accounting and settlement

Concrete commissions, clearances, clearings and books the build computes.
Amounts are in euro cents: 41000 is 410.00 EUR.  The figures follow the
sources' examples where the survey recorded them; the parties and references
are our own.
-/

namespace Rules.OneOrder.Accounting

open Rules.Core

/-! ## Commission on an order item -/

/-- An order item's commissions and what they come to. -/
structure CommissionCase where
  /-- What each commission comes to, in order. -/
  each : List Money
  /-- The total owed to the seller, if the currencies agree. -/
  total : Option Money
  deriving DecidableEq, Repr

/-- Work out an item's commissions in euros, rounding down. -/
def CommissionCase.of (cs : List Commission) : CommissionCase :=
  { each := cs.map (·.terms.value .down), total := commissionOwed .down .EUR cs }

/-- *Given* an order item with a fare of 820.00 EUR and three commissions: a
standard commission of 5 percent of the fare, a supplemental commission of
10.00 EUR, and a clearance incentive of 0.5 percent of the fare.

*When* the commission owed to the seller is worked out.

*Then* the commissions come to 41.00, 10.00 and 4.10 EUR, and the seller is owed
55.10 EUR. -/
@[case, checks "ONE-801.1 ONE-801.2 ONE-801.3"]
def tripCommissions : CommissionCase :=
  .of [⟨.standard, .percentage 500 ⟨82000, .EUR⟩⟩, ⟨.supplemental, .fixed ⟨1000, .EUR⟩⟩,
       ⟨.clearanceIncentive, .percentage 50 ⟨82000, .EUR⟩⟩]

#guard tripCommissions ==
  { each := [⟨4100, .EUR⟩, ⟨1000, .EUR⟩, ⟨410, .EUR⟩], total := some ⟨5510, .EUR⟩ }

/-- A percentage commission under the three roundings. -/
structure RoundedCommission where
  /-- Rounded down. -/
  down : Money
  /-- Rounded to the nearest cent, a half up. -/
  halfUp : Money
  /-- Rounded up. -/
  up : Money
  deriving DecidableEq, Repr

/-- *Given* a standard commission of 5 percent of a fare of 333.30 EUR.  The
exact share is 16.665 EUR.

*When* the commission is worked out under each rounding.

*Then* it is 16.66 EUR rounded down and 16.67 EUR rounded to the nearest cent
or up.  Each is less than a cent from the exact share. -/
@[case, checks "ONE-801.2"]
def roundedCommission : RoundedCommission :=
  let t : CommissionTerms := .percentage 500 ⟨33330, .EUR⟩
  { down := t.value .down, halfUp := t.value .halfUp, up := t.value .up }

#guard roundedCommission == { down := ⟨1666, .EUR⟩, halfUp := ⟨1667, .EUR⟩, up := ⟨1667, .EUR⟩ }

/-- *Given* an order item priced in euros with a standard commission of
41.00 EUR and a supplemental commission stated as 10.00 USD.

*When* the commission owed to the seller is worked out.

*Then* there is no total: the commissions are not all in the item's
currency. -/
@[case, checks "ONE-801.4"]
def mixedCurrencyCommission : CommissionCase :=
  .of [⟨.standard, .fixed ⟨4100, .EUR⟩⟩, ⟨.supplemental, .fixed ⟨1000, .USD⟩⟩]

#guard mixedCurrencyCommission ==
  { each := [⟨4100, .EUR⟩, ⟨1000, .USD⟩], total := none }

/-! ## Clearances for a payment -/

/-- The clearances for one payment and what each party ends with. -/
structure PaymentClearing where
  /-- How the payment was collected and the commission cleared. -/
  case : String
  /-- The clearances, with their net clearance amounts in cents. -/
  clearances : List ClearanceLeg
  /-- What the ORA ends with, in cents. -/
  oraEndsWith : Int
  /-- What the seller ends with, in cents. -/
  sellerEndsWith : Int
  deriving DecidableEq, Repr

/-- State the clearances for a payment of 410.00 EUR carrying a 41.00 EUR
commission. -/
def PaymentClearing.of (case : String) (collector : Collector) (handling : CommissionHandling) :
    PaymentClearing :=
  let p : PaymentCommitment :=
    { orderId := "ORD-ACC-1", paymentId := "PAY-1", currency := .EUR, amount := 41000,
      commission := 4100, collector, handling }
  { case, clearances := clearancesFor p, oraEndsWith := p.endsWith .ora,
    sellerEndsWith := p.endsWith .seller }

/-- *Given* a payment of 410.00 EUR with a seller's commission of 41.00 EUR.

*When* the payment is cleared in three ways: the seller collects it through
EasyPay and nets the commission; the seller collects it and the commission is
cleared separately; the airline collects it by card.

*Then* netted, the seller pays the ORA 369.00 EUR.  Separately, the seller pays
410.00 EUR and the ORA pays back 41.00 EUR.  Collected by the airline, the ORA
pays the seller 41.00 EUR.  Each way the ORA ends with 369.00 EUR and the seller
with 41.00 EUR: the commission is cleared once. -/
@[case, checks "ONE-802.1 ONE-802.2 ONE-802.3 ONE-802.4"]
def commissionClearedOnce : List PaymentClearing :=
  [.of "seller collects, commission netted" .seller .netted,
   .of "seller collects, commission separate" .seller .separate,
   .of "airline collects" .airline .netted]

#guard commissionClearedOnce ==
  [{ case := "seller collects, commission netted", clearances := [⟨.seller, .ora, 36900⟩],
     oraEndsWith := 36900, sellerEndsWith := 4100 },
   { case := "seller collects, commission separate",
     clearances := [⟨.seller, .ora, 41000⟩, ⟨.ora, .seller, 4100⟩],
     oraEndsWith := 36900, sellerEndsWith := 4100 },
   { case := "airline collects", clearances := [⟨.ora, .seller, 4100⟩],
     oraEndsWith := 36900, sellerEndsWith := 4100 }]

/-- The net clearance amount the ORA pays the seller for one refund, under the
three readings of commission recall. -/
structure RefundRow where
  /-- The amount refunded, in cents. -/
  refund : Nat
  /-- With no commission recalled. -/
  noRecall : Int
  /-- With the commission first paid recalled in full. -/
  full : Int
  /-- With the share of the commission matching the share refunded recalled. -/
  proportional : Int
  deriving DecidableEq, Repr

/-- The clearance amounts for a refund of a 75.00 EUR payment that carried
7.50 EUR of commission. -/
def RefundRow.of (refund : Nat) : RefundRow :=
  let r : SellerRefund := { refund, payment := 7500, commission := 750 }
  { refund, noRecall := (refundClearance .noRecall r).amount, full := (refundClearance .full r).amount,
    proportional := (refundClearance .proportional r).amount }

/-- *Given* a payment of 75.00 EUR, made through the seller, that carried a
commission of 7.50 EUR.  These are the figures of the source's refund example.

*When* it is refunded in full through the seller, and when 5.00 EUR of it is
refunded.

*Then* for the full refund the ORA pays the seller 75.00 EUR if no commission
is recalled and 67.50 EUR otherwise.  For the partial refund it pays 5.00 EUR
with no recall and 4.50 EUR with proportional recall.  With the commission
recalled in full the amount is minus 2.50 EUR: the seller pays the ORA for the
customer's refund. -/
@[case, checks "ONE-802.5 ONE-802.6"]
def refundClearances : List RefundRow := [.of 7500, .of 500]

#guard refundClearances ==
  [{ refund := 7500, noRecall := 7500, full := 6750, proportional := 6750 },
   { refund := 500, noRecall := 500, full := -250, proportional := 450 }]

/-! ## Accepting a clearance -/

/-- A clearance from a seller to an airline for 300.00 EUR through a
settlement plan, on order ORD-ACC-1, payment PAY-1. -/
def clearance (id : String) : Clearance :=
  { id, orderId := "ORD-ACC-1", paymentId := "PAY-1", payer := "SELLER-S", payee := "AIRLINE-A",
    amount := 30000, method := .settlementPlan, remittanceDate := "2026-11-16", signed := false }

/-- What the Clearance Manager decided about one clearance. -/
structure Decision where
  /-- The clearance ID. -/
  clearance : String
  /-- Accepted, or the reason it was rejected. -/
  outcome : Except ClearanceRejection Unit
  deriving DecidableEq, Repr

/-- Submit clearances in turn and record each decision. -/
def decisions (r : RepeatReading) : List Clearance → List Clearance → List Decision
  | _, [] => []
  | acc, c :: cs =>
    match submit r acc c with
    | .ok acc' => ⟨c.id, .ok ()⟩ :: decisions r acc' cs
    | .error e => ⟨c.id, .error e⟩ :: decisions r acc cs

/-- *Given* a payment of 410.00 EUR split across two payment methods: 300.00
EUR through a settlement plan and 110.00 EUR through EasyPay, each with its own
payment ID.

*When* the ORA sends a clearance for each.

*Then* the Clearance Manager accepts both, and each is recorded after the
clearances accepted before. -/
@[case, checks "ONE-803.3"]
def splitPaymentCleared : List Decision :=
  decisions ⟨false⟩ []
    [clearance "CLR-1", { clearance "CLR-2" with paymentId := "PAY-2", amount := 11000, method := .easyPay }]

#guard splitPaymentCleared == [⟨"CLR-1", .ok ()⟩, ⟨"CLR-2", .ok ()⟩]

/-- *Given* an accepted clearance CLR-1 for order ORD-ACC-1 and payment PAY-1,
not signed by both parties.

*When* the ORA sends CLR-1 again, and then an unsigned clearance CLR-3 for the
same order and payment.

*Then* the Clearance Manager rejects the first as a repeated clearance ID and
the second as a repeated payment. -/
@[case, checks "ONE-803.1 ONE-803.2"]
def repeatedClearances : List Decision :=
  decisions ⟨false⟩ [] [clearance "CLR-1", clearance "CLR-1", clearance "CLR-3"]

#guard repeatedClearances ==
  [⟨"CLR-1", .ok ()⟩, ⟨"CLR-1", .error .repeatedId⟩, ⟨"CLR-3", .error .repeatedPayment⟩]

/-- The clearances accepted under the two readings of the repeat check. -/
structure AcceptedUnderReadings where
  /-- Accepted when signed clearances are checked only for a repeated ID. -/
  idOnly : List String
  /-- Accepted when signed clearances are also checked for a repeated payment. -/
  idAndPayment : List String
  deriving DecidableEq, Repr

/-- *Given* two clearances for order ORD-ACC-1 and payment PAY-1, both signed
by both parties, with clearance IDs CLR-1 and CLR-2.

*When* the ORA sends both.

*Then* when signed clearances are checked only for a repeated ID, both are
accepted and the payment can be settled twice.  When they are also checked for
a repeated payment, only CLR-1 is accepted. -/
@[case, checks "ONE-803.4 ONE-803.5"]
def signedTwice : AcceptedUnderReadings :=
  let cs := [{ clearance "CLR-1" with signed := true }, { clearance "CLR-2" with signed := true }]
  { idOnly := (submitAll ⟨false⟩ [] cs).map (·.id), idAndPayment := (submitAll ⟨true⟩ [] cs).map (·.id) }

#guard signedTwice == { idOnly := ["CLR-1", "CLR-2"], idAndPayment := ["CLR-1"] }

/-! ## Settling a clearance -/

/-- A clearance's statuses after each event, and its amounts at the end, in
cents. -/
structure SettlementTrace where
  /-- The status after each event. -/
  statuses : List ClearanceStatus
  /-- Everything settled. -/
  settled : Nat
  /-- Everything clawed back. -/
  clawedBack : Nat
  /-- What is still unsettled. -/
  unsettled : Nat
  /-- What was written off. -/
  writtenOff : Nat
  /-- The settled amount less clawbacks, plus unsettled and written off. -/
  accountedFor : Int
  deriving DecidableEq, Repr

/-- The statuses a clearance passes through, one after each event. -/
def settleStatuses (r : SettlementReading) (c : SettlementRecord) : List SettlementEvent → List ClearanceStatus
  | [] => []
  | e :: es =>
    let c' := (settleStep r c e).getD c
    c'.status :: settleStatuses r c' es

/-- Trace a clearance of an agreed amount through events. -/
def SettlementTrace.of (r : SettlementReading) (agreed : Nat) (es : List SettlementEvent) :
    SettlementTrace :=
  let c := settleRun r (.new agreed) es
  { statuses := settleStatuses r (.new agreed) es, settled := c.settled, clawedBack := c.clawedBack,
    unsettled := c.unsettled, writtenOff := c.writtenOff,
    accountedFor := (c.settled : Int) - c.clawedBack + c.unsettled + c.writtenOff }

/-- The reading where a clawed-back amount counts as unsettled again and Final
Settlement cannot be clawed back. -/
def reopening : SettlementReading := { clawBackReopens := true, clawBackFinal := false }

/-- The reading where a clawed-back amount does not count as unsettled again. -/
def notReopening : SettlementReading := { clawBackReopens := false, clawBackFinal := false }

/-- *Given* an accepted clearance of 300.00 EUR.

*When* the next clearing pays all of it.

*Then* the clearance is Fully Settled, with 300.00 EUR settled and nothing
unsettled. -/
@[case, checks "ONE-804.2"]
def settledInOneClearing : SettlementTrace := .of reopening 30000 [.settle 30000]

#guard settledInOneClearing ==
  { statuses := [.fullySettled], settled := 30000, clawedBack := 0, unsettled := 0, writtenOff := 0,
    accountedFor := 30000 }

/-- *Given* an accepted clearance of 300.00 EUR.

*When* a clearing pays 250.00 EUR toward it and a later clearing pays the
remaining 50.00 EUR.  The first clearing is the source's sample, which shows
250.00 EUR settled and 50.00 EUR unsettled.

*Then* the clearance is Partially Settled with 50.00 EUR unsettled, and then
Final Settlement. -/
@[case, checks "ONE-804.2 ONE-804.3"]
def settledInTwoClearings : SettlementTrace := .of reopening 30000 [.settle 25000, .settle 5000]

#guard settledInTwoClearings ==
  { statuses := [.partiallySettled, .finalSettlement], settled := 30000, clawedBack := 0,
    unsettled := 0, writtenOff := 0, accountedFor := 30000 }

/-- *Given* an accepted clearance of 300.00 EUR, of which a clearing paid
250.00 EUR.

*When* the Clearance Manager cannot collect the rest and writes it off.

*Then* the clearance is Written Off, with the 50.00 EUR that was unsettled
written off. -/
@[case, checks "ONE-804.4"]
def remainderWrittenOff : SettlementTrace := .of reopening 30000 [.settle 25000, .writeOff]

#guard remainderWrittenOff ==
  { statuses := [.partiallySettled, .writtenOff], settled := 25000, clawedBack := 0, unsettled := 0,
    writtenOff := 5000, accountedFor := 30000 }

/-- *Given* an accepted clearance of 300.00 EUR.

*When* the ORA cancels it, and a clearing then tries to pay it.

*Then* the clearance is Cancelled and stays Cancelled, with nothing settled. -/
@[case, checks "ONE-804.1"]
def cancelledBeforeClearing : SettlementTrace := .of reopening 30000 [.cancel, .settle 30000]

#guard cancelledBeforeClearing ==
  { statuses := [.cancelled, .cancelled], settled := 0, clawedBack := 0, unsettled := 30000,
    writtenOff := 0, accountedFor := 30000 }

/-- A clearance traced under the two readings of a clawback. -/
structure ClawbackTraces where
  /-- Where a clawed-back amount counts as unsettled again. -/
  reopens : SettlementTrace
  /-- Where it does not. -/
  doesNotReopen : SettlementTrace
  deriving DecidableEq, Repr

/-- *Given* a clearance of 300.00 EUR settled in full in its first clearing.

*When* the Clearance Manager claws back 100.00 EUR from the payee, collects the
funds, and a later clearing pays 100.00 EUR.

*Then* where a clawed-back amount counts as unsettled again, the clearance goes
to Clawed Back and then Final Settlement, and all 300.00 EUR is accounted for.
Where it does not, the later clearing is refused: the clearance stays Clawed
Back with 300.00 EUR settled, 100.00 EUR clawed back and nothing unsettled, so
100.00 EUR of the agreed amount is accounted for nowhere. -/
@[case, checks "ONE-804.5 ONE-804.6"]
def clawedBackThenCollected : ClawbackTraces :=
  let es := [.settle 30000, .clawBack 10000, .settle 10000]
  { reopens := .of reopening 30000 es, doesNotReopen := .of notReopening 30000 es }

#guard clawedBackThenCollected ==
  { reopens := { statuses := [.fullySettled, .clawedBack, .finalSettlement], settled := 40000,
                 clawedBack := 10000, unsettled := 0, writtenOff := 0, accountedFor := 30000 },
    doesNotReopen := { statuses := [.fullySettled, .clawedBack, .clawedBack], settled := 30000,
                       clawedBack := 10000, unsettled := 0, writtenOff := 0, accountedFor := 20000 } }

/-! ## Net positions -/

/-- A clearance between two parties on the remittance date of 2026-11-16. -/
def owes (id payer payee : String) (amount : Nat) (method : ClearanceMethod) : Clearance :=
  { id, orderId := "ORD-" ++ id, paymentId := "PAY-" ++ id, payer, payee, amount, method,
    remittanceDate := "2026-11-16", signed := true }

/-- The parties' net positions and settlement roles on one remittance date. -/
structure Netting where
  /-- Each party's net position, in cents. -/
  positions : List (Party × Int)
  /-- Each party's settlement role. -/
  roles : List (Party × SettlementRole)
  /-- The sum of the positions. -/
  sum : Int
  deriving DecidableEq, Repr

/-- Net the clearances for 2026-11-16 under a reading, for some parties. -/
def Netting.of (r : EasyPayReading) (cs : List Clearance) (ps : List Party) : Netting :=
  { positions := ps.map fun p => (p, netPosition r cs "2026-11-16" p),
    roles := ps.map fun p => (p, settlementRole r cs "2026-11-16" p),
    sum := (ps.map (netPosition r cs "2026-11-16")).sum }

/-- *Given* three settlement plan clearances due on 2026-11-16: seller S owes
airline A 300.00 EUR and airline B 100.00 EUR, and A owes S a commission of
20.00 EUR.

*When* the Clearance Manager nets them.

*Then* S is a remittance payer for 380.00 EUR, A a settlement payee for
280.00 EUR and B a settlement payee for 100.00 EUR.  The positions sum to
zero. -/
@[case, checks "ONE-805.1 ONE-805.2 ONE-805.3"]
def settlementPlanNetting : Netting :=
  .of .leftOut
    [owes "1" "S" "A" 30000 .settlementPlan, owes "2" "S" "B" 10000 .settlementPlan,
     owes "3" "A" "S" 2000 .settlementPlan]
    [.org "S", .org "A", .org "B"]

#guard settlementPlanNetting ==
  { positions := [(.org "S", -38000), (.org "A", 28000), (.org "B", 10000)],
    roles := [(.org "S", .remittancePayer 38000), (.org "A", .settlementPayee 28000),
              (.org "B", .settlementPayee 10000)],
    sum := 0 }

/-- The netting of the same clearances under the two readings of EasyPay. -/
structure EasyPayNetting where
  /-- EasyPay left out of the payer's position and kept in the payee's. -/
  leftOut : Netting
  /-- The EasyPay provider in the payer's place. -/
  providerPays : Netting
  deriving DecidableEq, Repr

/-- *Given* a seller S that owes airline A 100.00 EUR through a settlement plan
and 50.00 EUR through EasyPay, both due on 2026-11-16.

*When* the Clearance Manager nets them.

*Then* S is a remittance payer for 100.00 EUR and A a settlement payee for
150.00 EUR under both readings.  Where EasyPay is only left out of the payer's
position, the positions sum to 50.00 EUR.  Where the EasyPay provider takes
the payer's place, it is a remittance payer for 50.00 EUR and the positions
sum to zero. -/
@[case, checks "ONE-805.4 ONE-805.5 ONE-805.6"]
def easyPayNetting : EasyPayNetting :=
  let cs := [owes "1" "S" "A" 10000 .settlementPlan, owes "2" "S" "A" 5000 .easyPay]
  let ps := [Party.org "S", .org "A", .easyPayProvider]
  { leftOut := .of .leftOut cs ps, providerPays := .of .providerPays cs ps }

#guard easyPayNetting ==
  { leftOut :=
      { positions := [(.org "S", -10000), (.org "A", 15000), (.easyPayProvider, 0)],
        roles := [(.org "S", .remittancePayer 10000), (.org "A", .settlementPayee 15000),
                  (.easyPayProvider, .even)],
        sum := 5000 },
    providerPays :=
      { positions := [(.org "S", -10000), (.org "A", 15000), (.easyPayProvider, -5000)],
        roles := [(.org "S", .remittancePayer 10000), (.org "A", .settlementPayee 15000),
                  (.easyPayProvider, .remittancePayer 5000)],
        sum := 0 } }

/-! ## Clearing totals -/

/-- *Given* a clearing to a settlement payee listing two clearances: one
Partially Settled with 250.00 EUR settled in this clearing, and one Fully
Settled for 200.00 EUR.  These are the figures of the source's sample
clearing.

*When* the clearing total is worked out.

*Then* it is 450.00 EUR. -/
@[case, checks "ONE-806.1"]
def sampleClearingTotal : Int :=
  clearingTotal .settlementPayee
    [⟨"CLR-1", .partiallySettled, .settlementPlan, 25000, 0⟩,
     ⟨"CLR-2", .fullySettled, .settlementPlan, 20000, 0⟩]

#guard sampleClearingTotal == 45000

/-- *Given* a clearing to a remittance payer listing a settlement plan
clearance of 100.00 EUR and an EasyPay clearance of 50.00 EUR, both Fully
Settled.

*When* the clearing total is worked out.

*Then* it is 100.00 EUR: the EasyPay clearance is listed and left out, since the
EasyPay provider pays it. -/
@[case, checks "ONE-806.2"]
def payerClearingWithEasyPay : Int :=
  clearingTotal .remittancePayer
    [⟨"CLR-1", .fullySettled, .settlementPlan, 10000, 0⟩, ⟨"CLR-2", .fullySettled, .easyPay, 5000, 0⟩]

#guard payerClearingWithEasyPay == 10000

/-- *Given* a clearing to a settlement payee that is due 200.00 EUR on one
clearance and has 300.00 EUR clawed back on another.

*When* the clearing total is worked out.

*Then* it is minus 100.00 EUR, which a bank transfer to the payee cannot
carry. -/
@[case, checks "ONE-806.3"]
def clawbackExceedsDue : Int :=
  clearingTotal .settlementPayee
    [⟨"CLR-1", .fullySettled, .settlementPlan, 20000, 0⟩, ⟨"CLR-2", .clawedBack, .settlementPlan, 0, 30000⟩]

#guard clawbackExceedsDue == -10000

/-! ## Short remittances -/

/-- How a short payment is split under each source page. -/
structure ShortRemittance where
  /-- Under Remittance of Funds, shares rounded down: the amount settled on
  each clearance, in cents. -/
  proportional : List Nat
  /-- Under Transfer of Funds: the amount settled on each clearance. -/
  oldestFirst : List Nat
  deriving DecidableEq, Repr

/-- Split a payment under both pages, rounding proportional shares down. -/
def ShortRemittance.of (paid : Nat) (os : List Obligation) : ShortRemittance :=
  { proportional := allocate .proportional .down paid os, oldestFirst := allocate .oldestFirst .down paid os }

/-- *Given* a remittance payer that owes airline A 100.00 EUR on an older
clearance and airline B 100.00 EUR on a newer one, and pays 100.00 EUR, with
no credit line.

*When* the Clearance Manager splits the payment.

*Then* under the Remittance of Funds page A and B receive 50.00 EUR each.
Under the Transfer of Funds page A receives 100.00 EUR and B nothing.  The two
pages give different results. -/
@[case, checks "ONE-807.3 ONE-807.4 ONE-807.6"]
def twoAirlines : ShortRemittance :=
  .of 10000 [⟨"CLR-A", "A", 10000⟩, ⟨"CLR-B", "B", 10000⟩]

#guard twoAirlines == { proportional := [5000, 5000], oldestFirst := [10000, 0] }

/-- *Given* a remittance payer that owes airline A 60.00 EUR on its oldest
clearance, airline B 80.00 EUR on the next, and airline A 60.00 EUR on the
newest, and pays 100.00 EUR, with no credit line.

*When* the Clearance Manager splits the payment.

*Then* under both pages A's older clearance is settled in full, B receives
40.00 EUR and A's newer clearance nothing.  Under Remittance of Funds, A's
share of 60.00 EUR goes to its older clearance first.  No clearance gets more
than it is owed. -/
@[case, checks "ONE-807.1 ONE-807.2"]
def olderClearancesFirst : ShortRemittance :=
  .of 10000 [⟨"CLR-A1", "A", 6000⟩, ⟨"CLR-B", "B", 8000⟩, ⟨"CLR-A2", "A", 6000⟩]

#guard olderClearancesFirst == { proportional := [6000, 4000, 0], oldestFirst := [6000, 4000, 0] }

/-- A short payment split under each page and rounding, with the total
allocated. -/
structure AllocatedTotals where
  /-- Remittance of Funds, shares rounded down: each amount, then the total. -/
  proportionalDown : List Nat × Nat
  /-- Remittance of Funds, shares rounded up: each amount, then the total. -/
  proportionalUp : List Nat × Nat
  /-- Transfer of Funds: each amount, then the total. -/
  oldestFirst : List Nat × Nat
  deriving DecidableEq, Repr

/-- *Given* a remittance payer that owes three airlines 100.00 EUR each and
pays 100.00 EUR, with no credit line.

*When* the Clearance Manager splits the payment.

*Then* under the Remittance of Funds page each share is 33.333 EUR.  Rounded
down, the airlines receive 33.33 EUR each and 0.01 EUR is not allocated.
Rounded up, they receive 33.34 EUR each, 0.02 EUR more than was paid.  Under
the Transfer of Funds page the first airline receives all 100.00 EUR. -/
@[case, checks "ONE-807.5"]
def threePayees : AllocatedTotals :=
  let os := [⟨"CLR-A", "A", 10000⟩, ⟨"CLR-B", "B", 10000⟩, ⟨"CLR-C", "C", 10000⟩]
  let pair (l : List Nat) := (l, l.sum)
  { proportionalDown := pair (allocate .proportional .down 10000 os),
    proportionalUp := pair (allocate .proportional .up 10000 os),
    oldestFirst := pair (allocate .oldestFirst .down 10000 os) }

#guard threePayees ==
  { proportionalDown := ([3333, 3333, 3333], 9999), proportionalUp := ([3334, 3334, 3334], 10002),
    oldestFirst := ([10000, 0, 0], 10000) }

/-! ## Billing by service providers -/

/-- The reading where only DELIVERED counts as delivered or consumed, or also
NOT CLAIMED, a no-show. -/
def consumption (noShowCounts : Bool) : ConsumptionReading where
  consumed s := s == .delivered || (noShowCounts && s == .notClaimed)
  delivered := by simp
  notYet s h := by rcases h with rfl | rfl | rfl | rfl | rfl | rfl <;> simp

/-- A partner's seat on a codeshare flight, with a settlement value of
120.00 EUR. -/
def partnerSeat (id : String) (delivery : DeliveryStatus) : ProvidedService :=
  { service := { id, passenger := ⟨"PAX-1"⟩, segment := "SEG-PARTNER", status := .confirmed, delivery },
    provider := "PARTNER-P", settlementValue := 12000 }

/-- Whether one bill is accepted under the two readings of consumption. -/
structure BillCase where
  /-- What is billed. -/
  case : String
  /-- Accepted where only DELIVERED counts. -/
  deliveredOnly : Bool
  /-- Accepted where NOT CLAIMED counts too. -/
  noShowCounts : Bool
  deriving DecidableEq, Repr

/-- Decide one bill for 120.00 EUR from partner P, which has no bilateral
agreement unless the case says so. -/
def BillCase.of (case : String) (agreement : Bool) (s : ProvidedService) (billed : List Bill) :
    BillCase :=
  let b : Bill := ⟨"PARTNER-P", s.service.id, 12000⟩
  { case, deliveredOnly := acceptBill (consumption false) (fun _ => agreement) [s] billed b,
    noShowCounts := acceptBill (consumption true) (fun _ => agreement) [s] billed b }

/-- *Given* partner P's seat, with a settlement value of 120.00 EUR.

*When* P bills the ORA 120.00 EUR for it: after the passenger flew; after a
no-show; before the flight; before the flight under a bilateral agreement; and
again after the passenger flew and P already billed for it.

*Then* the bill after the flight is accepted under both readings, and the
bill before the flight only with the agreement.  The no-show bill is accepted
only where NOT CLAIMED counts as consumed.  The second bill is refused: it
would exceed the settlement value. -/
@[case, checks "ONE-808.1 ONE-808.3 ONE-808.4"]
def partnerSeatBills : List BillCase :=
  [.of "flown" false (partnerSeat "SVC-1" .delivered) [],
   .of "no-show" false (partnerSeat "SVC-1" .notClaimed) [],
   .of "before the flight" false (partnerSeat "SVC-1" .readyToProceed) [],
   .of "before the flight, with an agreement" true (partnerSeat "SVC-1" .readyToProceed) [],
   .of "flown, billed twice" false (partnerSeat "SVC-1" .delivered) [⟨"PARTNER-P", "SVC-1", 12000⟩]]

#guard partnerSeatBills ==
  [⟨"flown", true, true⟩, ⟨"no-show", false, true⟩, ⟨"before the flight", false, false⟩,
   ⟨"before the flight, with an agreement", true, true⟩, ⟨"flown, billed twice", false, false⟩]

/-- *Given* partner P's seat after the passenger flew.

*When* airline Q, which does not deliver the seat, bills the ORA for it.

*Then* the bill is refused under both readings. -/
@[case, checks "ONE-808.2"]
def otherProviderBill : Bool :=
  acceptBill (consumption true) (fun _ => true) [partnerSeat "SVC-1" .delivered] []
    ⟨"AIRLINE-Q", "SVC-1", 12000⟩

#guard otherProviderBill == false

/-! ## Revenue and the order's balance -/

/-- A reading of the sources: DELIVERED earns revenue, every other final status
gets the given treatment, and a penalty is or is not recognized at
cancellation. -/
def revenueReading (others : Treatment) (penaltyEarned : Bool) : RevenueReading where
  treat s := if s = .delivered then .earn else others
  delivered := by simp
  penaltyEarned := penaltyEarned

/-- The books of a one-flight order after a sequence of events, where the
airline checks the amounts of a cancellation unless told otherwise. -/
def flightBooks (r : RevenueReading) (es : List BookEvent) (k : CancelCheck := .checked) :
    OrderTotals :=
  (OrderBooks.run r k [.new "SVC-1"] (es.map ("SVC-1", ·))).totals r

/-- An order's totals after each step. -/
structure BookSteps where
  /-- After the payment. -/
  afterPayment : OrderTotals
  /-- After the last event. -/
  atEnd : OrderTotals
  deriving DecidableEq, Repr

/-- *Given* an order with one flight paid at 100.00 EUR.

*When* the passenger flies and the flight is reported DELIVERED.

*Then* after the payment the 100.00 EUR is a liability.  Once the flight is
delivered it is revenue.  At each step payments equal refunds, plus
liability, plus revenue, plus forfeited amounts. -/
@[case, checks "ONE-809.1 ONE-809.2 ONE-809.4"]
def deliveredFlightBooks : BookSteps :=
  let r := revenueReading .keep true
  { afterPayment := flightBooks r [.pay 10000], atEnd := flightBooks r [.pay 10000, .finish .delivered] }

#guard deliveredFlightBooks ==
  { afterPayment := { paid := 10000, refunded := 0, liability := 10000, revenue := 0, forfeited := 0 },
    atEnd := { paid := 10000, refunded := 0, liability := 0, revenue := 10000, forfeited := 0 } }

/-- An order's totals under the two readings of a penalty. -/
structure PenaltyBooks where
  /-- Where a penalty is recognized as revenue at cancellation. -/
  penaltyEarned : OrderTotals
  /-- Where it is not. -/
  penaltyNotEarned : OrderTotals
  deriving DecidableEq, Repr

/-- *Given* an order with one flight paid at 100.00 EUR.

*When* the customer cancels with a penalty of 25.00 EUR, receives 75.00 EUR,
and the flight is removed.

*Then* where the penalty is recognized at cancellation, it is 25.00 EUR of
revenue.  Where it is not, the 25.00 EUR stays a liability on a flight that
can no longer change, since no delivery will ever recognize it.  The books
balance either way, and nothing is refunded beyond what was paid. -/
@[case, checks "ONE-809.3 ONE-809.4 ONE-809.5"]
def cancelWithPenalty : PenaltyBooks :=
  let es := [.pay 10000, .cancel 7500 2500 0]
  { penaltyEarned := flightBooks (revenueReading .earn true) es,
    penaltyNotEarned := flightBooks (revenueReading .earn false) es }

#guard cancelWithPenalty ==
  { penaltyEarned := { paid := 10000, refunded := 7500, liability := 0, revenue := 2500, forfeited := 0 },
    penaltyNotEarned := { paid := 10000, refunded := 7500, liability := 2500, revenue := 0, forfeited := 0 } }

/-- *Given* an order with one flight paid at 100.00 EUR, of which 10.00 EUR is a
non-refundable tax.

*When* the customer cancels and receives 90.00 EUR.

*Then* the books record 90.00 EUR refunded and 10.00 EUR forfeited, and they
balance: 100.00 EUR paid equals 90.00 EUR refunded plus 10.00 EUR
forfeited. -/
@[case, checks "ONE-809.4 ONE-809.5"]
def nonRefundableTax : OrderTotals :=
  flightBooks (revenueReading .earn true) [.pay 10000, .cancel 9000 0 1000]

#guard nonRefundableTax == { paid := 10000, refunded := 9000, liability := 0, revenue := 0, forfeited := 1000 }

/-- A no-show's books under the three treatments of NOT CLAIMED. -/
structure NoShowBooks where
  /-- Where the amount paid for a no-show earns revenue. -/
  earn : OrderTotals
  /-- Where it is refunded. -/
  refund : OrderTotals
  /-- Where it stays a liability. -/
  keep : OrderTotals
  deriving DecidableEq, Repr

/-- *Given* an order with one flight paid at 100.00 EUR.

*When* the passenger does not show and the flight is reported NOT CLAIMED.

*Then* depending on the reading, the 100.00 EUR is revenue, is refunded, or
stays a liability on a flight that can no longer change.  The books balance
under all three. -/
@[case, checks "ONE-809.3 ONE-809.4"]
def noShowTreatments : NoShowBooks :=
  let es := [.pay 10000, .finish .notClaimed]
  { earn := flightBooks (revenueReading .earn true) es,
    refund := flightBooks (revenueReading .refund true) es,
    keep := flightBooks (revenueReading .keep true) es }

#guard noShowTreatments ==
  { earn := { paid := 10000, refunded := 0, liability := 0, revenue := 10000, forfeited := 0 },
    refund := { paid := 10000, refunded := 10000, liability := 0, revenue := 0, forfeited := 0 },
    keep := { paid := 10000, refunded := 0, liability := 10000, revenue := 0, forfeited := 0 } }

/-- An order's totals under the two readings of the cancellation check. -/
structure CheckedOrAsSent where
  /-- Where the airline checks that the amounts add up to what was paid. -/
  checked : OrderTotals
  /-- Where accounting records the amounts as the airline sends them. -/
  asSent : OrderTotals
  deriving DecidableEq, Repr

/-- Run a one-flight order's events under both readings of the check. -/
def CheckedOrAsSent.of (es : List BookEvent) : CheckedOrAsSent :=
  { checked := flightBooks (revenueReading .earn true) es .checked,
    asSent := flightBooks (revenueReading .earn true) es .asSent }

/-- *Given* an order with one flight paid at 100.00 EUR.

*When* a cancellation is reported with a refund of 100.00 EUR and a penalty of
25.00 EUR, which add up to more than was paid.

*Then* where the airline checks the amounts, the report is refused and the
flight is still a 100.00 EUR liability.  Where accounting records it as sent,
the books show 100.00 EUR paid against 100.00 EUR refunded and 25.00 EUR of
revenue: they do not balance. -/
@[case, checks "ONE-809.4 ONE-809.6"]
def cancelNotAddingUp : CheckedOrAsSent := .of [.pay 10000, .cancel 10000 2500 0]

#guard cancelNotAddingUp ==
  { checked := { paid := 10000, refunded := 0, liability := 10000, revenue := 0, forfeited := 0 },
    asSent := { paid := 10000, refunded := 10000, liability := 0, revenue := 2500, forfeited := 0 } }

/-- *Given* an order with one flight paid at 100.00 EUR.

*When* the airline cancels it and reports a goodwill refund of 120.00 EUR.

*Then* where the airline checks the amounts, the report is refused.  Where
accounting records it as sent, 120.00 EUR is refunded against 100.00 EUR paid:
the refunds exceed the payments and the books do not balance. -/
@[case, checks "ONE-809.4 ONE-809.5 ONE-809.6"]
def goodwillRefund : CheckedOrAsSent := .of [.pay 10000, .cancel 12000 0 0]

#guard goodwillRefund ==
  { checked := { paid := 10000, refunded := 0, liability := 10000, revenue := 0, forfeited := 0 },
    asSent := { paid := 10000, refunded := 12000, liability := 0, revenue := 0, forfeited := 0 } }

end Rules.OneOrder.Accounting
