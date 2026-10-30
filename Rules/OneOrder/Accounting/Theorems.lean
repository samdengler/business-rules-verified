import Rules.Core.Attributes
import Rules.OneOrder.Delivery.Moves
import Rules.OneOrder.Accounting.Commission
import Rules.OneOrder.Accounting.Clearance
import Rules.OneOrder.Accounting.Clearing
import Rules.OneOrder.Accounting.Books

/-!
# Guarantees about commission, accounting and settlement

Properties the commission, clearance, settlement and accounting rules are
claimed to have.  A guarantee holds for every reading of the sources the rule
takes; one left open is a question for the business.
-/

namespace Rules.OneOrder.Accounting

open Rules.Core
open Rules.OneOrder.Delivery (isFinal)

/-! ## Sums -/

/-- A sum of differences over a list is the difference of the sums. -/
theorem sum_map_sub' {α : Type} (ps : List α) (f g : α → Int) :
    (ps.map fun p => f p - g p).sum = (ps.map f).sum - (ps.map g).sum := by
  induction ps with
  | nil => simp
  | cons p ps ih => simp only [List.map_cons, List.sum_cons, ih]; ring

/-! ## Commission on an order item -/

/-- A fixed commission comes to its amount, under every rounding. -/
@[checks "ONE-801.1"]
theorem fixed_commission_owed (r : Rounding) (m : Money) : (CommissionTerms.fixed m).value r = m :=
  rfl

/-- A quotient rounded under any reading is less than one unit away from the
exact quotient. -/
theorem divide_within_one (r : Rounding) (n d : Nat) (hd : 0 < d) :
    r.divide n d * d < n + d ∧ n < r.divide n d * d + d := by
  cases r with
  | down =>
    simp only [Rounding.divide]
    have h1 := Nat.div_add_mod n d
    have h2 := Nat.mod_lt n hd
    have : n / d * d = d * (n / d) := Nat.mul_comm _ _
    omega
  | halfUp =>
    simp only [Rounding.divide]
    have h1 := Nat.div_add_mod (2 * n + d) (2 * d)
    have h2 := Nat.mod_lt (2 * n + d) (show 0 < 2 * d by omega)
    have : 2 * d * ((2 * n + d) / (2 * d)) = 2 * ((2 * n + d) / (2 * d) * d) := by ring
    omega
  | up =>
    simp only [Rounding.divide]
    have h1 := Nat.div_add_mod (n + d - 1) d
    have h2 := Nat.mod_lt (n + d - 1) hd
    have : (n + d - 1) / d * d = d * ((n + d - 1) / d) := Nat.mul_comm _ _
    omega

/-- A percentage commission comes to its share of the base, in the base's
currency, less than one minor unit away from the exact share, under every
rounding. -/
@[checks "ONE-801.2"]
theorem percentage_commission_owed (r : Rounding) (bp : Nat) (base : Money) :
    ((CommissionTerms.percentage bp base).value r).currency = base.currency ∧
      ((CommissionTerms.percentage bp base).value r).amount * 10000 < bp * base.amount + 10000 ∧
      bp * base.amount < ((CommissionTerms.percentage bp base).value r).amount * 10000 + 10000 :=
  ⟨rfl, divide_within_one r _ _ (by norm_num)⟩

/-- An order item's commissions, all in its currency, come to their total,
under every rounding. -/
@[checks "ONE-801.3"]
theorem commission_total (r : Rounding) (c : Currency) (cs : List Commission)
    (h : ∀ x ∈ cs, (x.terms.value r).currency = c) :
    commissionOwed r c cs = some ⟨(cs.map fun x => (x.terms.value r).amount).sum, c⟩ := by
  have hall : cs.all (fun x => (x.terms.value r).currency == c) = true := by simpa using h
  simp [commissionOwed, hall]

/-- An order item with a commission in another currency gets no total, under
every rounding. -/
@[checks "ONE-801.4"]
theorem commission_mixed_currency (r : Rounding) (c : Currency) (cs : List Commission)
    (h : ∃ x ∈ cs, (x.terms.value r).currency ≠ c) : commissionOwed r c cs = none := by
  obtain ⟨x, hx, hne⟩ := h
  have : cs.all (fun x => (x.terms.value r).currency == c) = false := by
    simp only [List.all_eq_false, beq_iff_eq]
    exact ⟨x, hx, hne⟩
  simp [commissionOwed, this]

/-- A percentage commission of no more than 100 percent never comes to more
than its base, under every rounding. -/
@[checks "ONE-801.5"]
theorem percentage_within_base (r : Rounding) (bp : Nat) (base : Money) (h : bp ≤ 10000) :
    ((CommissionTerms.percentage bp base).value r).amount ≤ base.amount := by
  have h1 := (percentage_commission_owed r bp base).2.1
  have h2 : bp * base.amount ≤ 10000 * base.amount := Nat.mul_le_mul_right _ h
  omega

/-! ## Clearances for a payment -/

/-- A payment the seller collected, with the commission netted, gives one
clearance: the seller pays the ORA the payment amount less the commission. -/
@[checks "ONE-802.1"]
theorem seller_collected_netted (p : PaymentCommitment) (hc : p.collector = .seller)
    (hh : p.handling = .netted) :
    clearancesFor p = [⟨.seller, .ora, (p.amount : Int) - p.commission⟩] := by
  simp [clearancesFor, hc, hh]

/-- A payment the seller collected, with the commission cleared separately,
gives two clearances: the seller pays the ORA the payment amount, and the ORA
pays the seller the commission. -/
@[checks "ONE-802.2"]
theorem seller_collected_separate (p : PaymentCommitment) (hc : p.collector = .seller)
    (hh : p.handling = .separate) :
    clearancesFor p = [⟨.seller, .ora, p.amount⟩, ⟨.ora, .seller, p.commission⟩] := by
  simp [clearancesFor, hc, hh]

/-- A payment the airline collected gives one clearance: the ORA pays the
seller the commission. -/
@[checks "ONE-802.3"]
theorem airline_collected (p : PaymentCommitment) (hc : p.collector = .airline) :
    clearancesFor p = [⟨.ora, .seller, p.commission⟩] := by
  cases hh : p.handling <;> simp [clearancesFor, hc, hh]

/-- However the customer's money was collected and the commission cleared, the
ORA ends with the payment amount less the commission and the seller with the
commission: the commission is cleared exactly once. -/
@[checks "ONE-802.4"]
theorem commission_cleared_once (p : PaymentCommitment) :
    p.endsWith .ora = (p.amount : Int) - p.commission ∧ p.endsWith .seller = p.commission := by
  obtain ⟨_, _, _, a, c, col, h⟩ := p
  cases col <;> cases h <;>
    simp [PaymentCommitment.endsWith, PaymentCommitment.collected, clearancesFor,
      ClearanceLeg.netFor] <;> omega

/-- A refund through the seller gives one clearance: the ORA pays the seller
the refund less the commission recalled on it, under every reading. -/
@[checks "ONE-802.5"]
theorem refund_cleared (rr : RecallReading) (r : SellerRefund) :
    refundClearance rr r = ⟨.ora, .seller, (r.refund : Int) - rr.recalled r⟩ :=
  rfl

/-- Under a reading that recalls no commission, or the share of it that
matches the share refunded, the clearance for a refund never has the seller
paying the ORA. -/
theorem refund_clearance_nonneg_without_full_recall (rr : RecallReading) (r : SellerRefund)
    (hrr : rr ≠ .full) (hcomm : r.commission ≤ r.payment) :
    0 ≤ (refundClearance rr r).amount := by
  cases rr with
  | full => exact absurd rfl hrr
  | noRecall => simp [refundClearance, RecallReading.recalled]
  | proportional =>
    have : r.commission * r.refund / r.payment ≤ r.refund :=
      Nat.div_le_of_le_mul (Nat.mul_le_mul_right _ hcomm)
    simp only [refundClearance, RecallReading.recalled]
    omega

/-- The clearance for a refund through the seller never has the seller paying
the ORA: its amount is never negative.

Open question for the business.  Under the reading that recalls the
commission first paid in full on any refund, a partial refund smaller than
that commission gives a negative amount.  The example {lit}`refundClearances`
shows it: a 5.00 refund of a 75.00 payment that carried 7.50 of commission
leaves the seller paying the ORA 2.50.  Recalling no commission, or the share
that matches the share refunded, never does
({name}`refund_clearance_nonneg_without_full_recall`).  How much commission
is recalled on a partial refund? -/
@[open_question, checks "ONE-802.6"]
theorem refund_not_paid_by_seller (rr : RecallReading) (r : SellerRefund)
    (hrefund : r.refund ≤ r.payment) (hcomm : r.commission ≤ r.payment) :
    0 ≤ (refundClearance rr r).amount := by
  sorry

/-! ## Accepting a clearance -/

/-- A clearance whose clearance ID is already accepted is rejected, under every
reading. -/
@[checks "ONE-803.1"]
theorem repeated_id_rejected (r : RepeatReading) (acc : List Clearance) (c : Clearance)
    (h : ∃ a ∈ acc, a.id = c.id) : submit r acc c = .error .repeatedId := by
  have : acc.any (·.id == c.id) = true := by simpa using h
  simp [submit, this]

/-- A clearance not signed by both parties whose order ID and payment ID are
already accepted is rejected, under every reading. -/
@[checks "ONE-803.2"]
theorem repeated_unsigned_rejected (r : RepeatReading) (acc : List Clearance) (c : Clearance)
    (hs : c.signed = false) (h : ∃ a ∈ acc, a.commitment = c.commitment) :
    ∃ e, submit r acc c = .error e := by
  have : acc.any (·.commitment == c.commitment) = true := by simpa using h
  unfold submit
  split_ifs with h1 h2
  · exact ⟨_, rfl⟩
  · exact ⟨_, rfl⟩
  · simp_all

/-- An accepted clearance is added after those accepted before, which stay as
they were, under every reading. -/
@[checks "ONE-803.3"]
theorem accepted_recorded (r : RepeatReading) (acc acc' : List Clearance) (c : Clearance)
    (h : submit r acc c = .ok acc') : acc' = acc ++ [c] := by
  unfold submit at h
  split_ifs at h
  cases h
  rfl

/-- Every pair of an order ID and a payment ID has at most one accepted
clearance, whatever clearances the ORA sends.

Open question for the business.  The Clearance Manager checks clearance data
signed by both parties only for a repeated clearance ID.  Two signed
clearances for one payment with different clearance IDs are both accepted.
The example {lit}`signedTwice` shows it.  May one payment have two signed
clearances with different clearance IDs? -/
@[open_question, checks "ONE-803.4"]
theorem one_clearance_per_payment (r : RepeatReading) (cs : List Clearance) :
    ((submitAll r [] cs).map (·.commitment)).Nodup := by
  sorry

/-- Accepting a clearance keeps the accepted order and payment pairs distinct
when signed clearances are checked too. -/
theorem submit_keeps_distinct (r : RepeatReading) (hr : r.checkSigned = true)
    (acc acc' : List Clearance) (c : Clearance) (hnd : (acc.map (·.commitment)).Nodup)
    (h : submit r acc c = .ok acc') : (acc'.map (·.commitment)).Nodup := by
  unfold submit at h
  split_ifs at h with h1 h2
  cases h
  have hnot : c.commitment ∉ acc.map (·.commitment) := by
    simp only [hr, Bool.or_true, Bool.true_and, List.any_eq_true, beq_iff_eq, not_exists,
      not_and] at h2
    simp only [List.mem_map, not_exists, not_and]
    exact h2
  rw [List.map_append, List.nodup_append_comm]
  exact List.nodup_cons.mpr ⟨hnot, hnd⟩

/-- Under every reading that checks signed clearances for a repeated order and
payment too, every pair of an order ID and a payment ID has at most one
accepted clearance, whatever clearances the ORA sends. -/
@[checks "ONE-803.5"]
theorem one_clearance_per_payment_checked (r : RepeatReading) (hr : r.checkSigned = true)
    (cs : List Clearance) : ((submitAll r [] cs).map (·.commitment)).Nodup := by
  suffices ∀ acc, (acc.map (·.commitment)).Nodup → ((submitAll r acc cs).map (·.commitment)).Nodup from
    this [] List.nodup_nil
  induction cs with
  | nil => intro acc h; simpa [submitAll] using h
  | cons c cs ih =>
    intro acc h
    simp only [submitAll]
    split
    · next acc' hs => exact ih _ (submit_keeps_distinct r hr acc acc' c h hs)
    · exact ih _ h

/-! ## Settling a clearance -/

/-- The ORA's cancellation marks an accepted clearance Cancelled, and every
later event for it is refused, under every reading. -/
@[checks "ONE-804.1"]
theorem cancel_marks_cancelled (r : SettlementReading) (c : SettlementRecord)
    (hs : c.status = .accepted) :
    settleStep r c .cancel = some { c with status := .cancelled } ∧
      ∀ e, settleStep r { c with status := .cancelled } e = none := by
  refine ⟨by simp [settleStep, hs], fun e => ?_⟩
  cases e <;> simp [settleStep, ClearanceStatus.settleable, ClearanceStatus.clawable,
    ClearanceStatus.writable]

/-- A clearing that pays all that is unsettled marks the clearance Fully
Settled if it was Accepted and Final Settlement otherwise, and leaves nothing
unsettled, under every reading. -/
@[checks "ONE-804.2"]
theorem settle_all (r : SettlementReading) (c : SettlementRecord) (x : Nat)
    (hs : c.status.settleable r = true) (hx : c.unsettled ≤ x) :
    ∃ c', settleStep r c (.settle x) = some c' ∧
      c'.status = (if c.status = .accepted then .fullySettled else .finalSettlement) ∧
      c'.settled = c.settled + c.unsettled ∧ c'.unsettled = 0 := by
  simp [settleStep, hs, settledStatus, Nat.min_eq_right hx]

/-- A clearing that pays part of what is unsettled marks the clearance
Partially Settled and settles what it pays.  No clearing settles more than the
amount still unsettled.  Both hold under every reading. -/
@[checks "ONE-804.3"]
theorem settle_part (r : SettlementReading) (c c' : SettlementRecord) (x : Nat)
    (h : settleStep r c (.settle x) = some c') :
    c'.settled ≤ c.settled + c.unsettled ∧
      (0 < x → x < c.unsettled → c'.status = .partiallySettled ∧ c'.settled = c.settled + x) := by
  simp only [settleStep] at h
  split_ifs at h
  cases h
  refine ⟨by simp, fun h0 hlt => ?_⟩
  have hm : min x c.unsettled = x := Nat.min_eq_left hlt.le
  have h1 : x ≠ c.unsettled := by omega
  have h2 : x ≠ 0 := by omega
  simp [hm, settledStatus, h1, h2]

/-- Writing off a clearance removes exactly the amount still unsettled and
changes nothing settled, under every reading. -/
@[checks "ONE-804.4"]
theorem write_off_removes_unsettled (r : SettlementReading) (c c' : SettlementRecord)
    (h : settleStep r c .writeOff = some c') :
    c'.status = .writtenOff ∧ c'.writtenOff = c.writtenOff + c.unsettled ∧ c'.unsettled = 0 ∧
      c'.settled = c.settled ∧ c'.clawedBack = c.clawedBack := by
  simp only [settleStep] at h
  split_ifs at h
  cases h
  simp

/-- Every part of a clearance's agreed amount stays settled and kept, still
unsettled, or written off, whatever happens to it.

Open question for the business.  Under a reading where a clawed-back amount
does not count as unsettled again, a clawback takes money back from the payee
without adding it to what is owed, so that part of the agreed amount is
neither settled, unsettled nor written off.  The example
{lit}`clawedBackThenCollected` shows it: a 300.00 clearance settled in full and
then clawed back by 100.00 keeps 200.00 settled, with nothing unsettled.
Does a clawed-back amount count as unsettled again, and can a later clearing
settle it? -/
@[open_question, checks "ONE-804.5"]
theorem clearance_amounts_accounted (r : SettlementReading) (agreed : Nat)
    (es : List SettlementEvent) : (settleRun r (.new agreed) es).Accounted := by
  sorry

/-- Every event keeps a clearance's amounts accounted for under a reading
where a clawed-back amount counts as unsettled again. -/
theorem settleStep_accounted (r : SettlementReading) (hr : r.clawBackReopens = true)
    (c : SettlementRecord) (e : SettlementEvent) (h : c.Accounted) :
    ((settleStep r c e).getD c).Accounted := by
  obtain ⟨h1, h2⟩ := h
  cases e with
  | cancel => simp only [settleStep]; split_ifs <;> exact ⟨h1, h2⟩
  | settle x =>
    simp only [settleStep]; split_ifs
    · simp only [Option.getD_some, SettlementRecord.Accounted]; omega
    · exact ⟨h1, h2⟩
  | clawBack x =>
    simp only [settleStep]; split_ifs
    · simp only [Option.getD_some, SettlementRecord.Accounted]; omega
    · exact ⟨h1, h2⟩
  | writeOff =>
    simp only [settleStep]; split_ifs
    · simp only [Option.getD_some, SettlementRecord.Accounted]; omega
    · exact ⟨h1, h2⟩

/-- Under every reading where a clawed-back amount counts as unsettled again,
every part of a clearance's agreed amount stays settled and kept, still
unsettled, or written off, whatever happens to it. -/
@[checks "ONE-804.6"]
theorem clearance_amounts_accounted_reopen (r : SettlementReading) (hr : r.clawBackReopens = true)
    (agreed : Nat) (es : List SettlementEvent) : (settleRun r (.new agreed) es).Accounted := by
  suffices ∀ c, c.Accounted → (settleRun r c es).Accounted from
    this _ ⟨le_refl _, by simp [SettlementRecord.new]⟩
  induction es with
  | nil => intro c h; exact h
  | cons e es ih => intro c h; exact ih _ (settleStep_accounted r hr c e h)

/-! ## Net positions -/

/-- A sum over a list of pairwise distinct parties that is zero except at one
member of the list is the value there. -/
theorem sum_single {α : Type} [DecidableEq α] (ps : List α) (hnd : ps.Nodup) (x : α) (a : Int) :
    (ps.map fun p => if x = p then a else 0).sum = if x ∈ ps then a else 0 := by
  induction ps with
  | nil => simp
  | cons q qs ih =>
    obtain ⟨hq, hqs⟩ := List.nodup_cons.mp hnd
    rw [List.map_cons, List.sum_cons, ih hqs]
    by_cases hx : x = q
    · subst hx; simp [hq]
    · simp [hx]

/-- A party's net position is the amounts of the clearances on the remittance
date that it is paid, less the amounts of those it is netted as payer of,
under every reading. -/
@[checks "ONE-805.1"]
theorem net_position_formula (r : EasyPayReading) (cs : List Clearance) (date : String) (p : Party) :
    netPosition r cs date p =
      ((cs.filter (·.remittanceDate == date)).map fun c =>
          if Party.org c.payee = p then (c.amount : Int) else 0).sum -
        ((cs.filter (·.remittanceDate == date)).map fun c =>
          if netPayer r c = some p then (c.amount : Int) else 0).sum := by
  exact sum_map_sub' _ _ _

/-- A party with a positive net position is a settlement payee for that
amount, under every reading. -/
@[checks "ONE-805.2"]
theorem positive_position_payee (r : EasyPayReading) (cs : List Clearance) (date : String)
    (p : Party) (h : 0 < netPosition r cs date p) :
    settlementRole r cs date p = .settlementPayee (netPosition r cs date p).toNat := by
  simp [settlementRole, h]

/-- A party with a negative net position is a remittance payer for that
amount, under every reading. -/
@[checks "ONE-805.3"]
theorem negative_position_payer (r : EasyPayReading) (cs : List Clearance) (date : String)
    (p : Party) (h : netPosition r cs date p < 0) :
    settlementRole r cs date p = .remittancePayer (-netPosition r cs date p).toNat := by
  simp [settlementRole, h, not_lt.mpr h.le]

/-- An EasyPay clearance is never netted against its payer, under every
reading: it adds to the payer's position only what it adds to the payer as
its payee, which is nothing unless the payer is also the payee. -/
@[checks "ONE-805.4"]
theorem easyPay_left_out_of_payer (r : EasyPayReading) (c : Clearance) (hm : c.method = .easyPay) :
    c.netFor r (.org c.payer) = if c.payee = c.payer then (c.amount : Int) else 0 := by
  cases r <;> simp [Clearance.netFor, netPayer, hm]

/-- The net positions of all parties on a remittance date sum to zero.

Open question for the business.  Under the reading that leaves an EasyPay
clearance out of its payer's position and keeps it in the payee's, the
positions add up to the EasyPay amounts.  The example {lit}`easyPayNetting`
shows it: a seller owing an airline 100.00 by settlement plan and 50.00 by
EasyPay is a remittance payer for 100.00, while the airline is a settlement
payee for 150.00.  Does the EasyPay provider count as a party in the
netting? -/
@[open_question, checks "ONE-805.5"]
theorem net_positions_sum_zero (r : EasyPayReading) (cs : List Clearance) (date : String)
    (ps : List Party) (hnd : ps.Nodup)
    (hcover : ∀ c ∈ cs, Party.org c.payee ∈ ps ∧ ∀ q, netPayer r c = some q → q ∈ ps) :
    (ps.map (netPosition r cs date)).sum = 0 := by
  sorry

/-- Under the reading where the EasyPay provider takes the payer's place, one
clearance adds nothing to the sum of the positions of parties that include its
payee and the party netted as its payer. -/
theorem netFor_sum_zero (c : Clearance) (ps : List Party) (hnd : ps.Nodup)
    (hc : Party.org c.payee ∈ ps ∧ ∀ q, netPayer .providerPays c = some q → q ∈ ps) :
    (ps.map fun p => c.netFor .providerPays p).sum = 0 := by
  obtain ⟨q, hq⟩ : ∃ q, netPayer .providerPays c = some q := by
    cases hm : c.method <;> simp [netPayer, hm]
  have hqm := hc.2 q hq
  have : (ps.map fun p => c.netFor .providerPays p) = ps.map fun p =>
      (if Party.org c.payee = p then (c.amount : Int) else 0) - (if q = p then (c.amount : Int) else 0) := by
    apply List.map_congr_left
    intro p _
    simp [Clearance.netFor, hq]
  rw [this, sum_map_sub', sum_single ps hnd, sum_single ps hnd]
  simp [hc.1, hqm]

/-- Under the reading where the EasyPay provider takes the payer's place, the
net positions of all parties on a remittance date sum to zero. -/
@[checks "ONE-805.6"]
theorem net_positions_sum_zero_provider (cs : List Clearance) (date : String) (ps : List Party)
    (hnd : ps.Nodup)
    (hcover : ∀ c ∈ cs, Party.org c.payee ∈ ps ∧ ∀ q, netPayer .providerPays c = some q → q ∈ ps) :
    (ps.map (netPosition .providerPays cs date)).sum = 0 := by
  induction cs with
  | nil =>
    have h0 : netPosition .providerPays [] date = fun _ => 0 := by funext p; simp [netPosition]
    simp [h0]
  | cons c cs ih =>
    have hsplit : ∀ p, netPosition .providerPays (c :: cs) date p =
        (if c.remittanceDate == date then c.netFor .providerPays p else 0) +
          netPosition .providerPays cs date p := by
      intro p
      unfold netPosition
      by_cases hd : c.remittanceDate == date <;> simp [hd]
    have hmap : (ps.map (netPosition .providerPays (c :: cs) date)) = ps.map fun p =>
        (if c.remittanceDate == date then c.netFor .providerPays p else 0) +
          netPosition .providerPays cs date p := by
      apply List.map_congr_left
      intro p _
      exact hsplit p
    rw [hmap, List.sum_map_add, ih (fun d hd => hcover d (by simp [hd])), add_zero]
    by_cases hd : c.remittanceDate == date
    · simp only [hd, ite_true]
      exact netFor_sum_zero c ps hnd (hcover c (by simp))
    · simp [hd]

/-! ## Clearing totals -/

/-- The total of a clearing to a settlement payee is the amounts settled for
clearances marked Fully Settled, Partially Settled or Final Settlement, less
the amounts clawed back. -/
@[checks "ONE-806.1"]
theorem payee_clearing_total (lines : List ClearingLine) :
    clearingTotal .settlementPayee lines =
      (lines.map fun l => if l.status.countsSettled then (l.settled : Int) else 0).sum -
        (lines.map fun l => (l.clawedBack : Int)).sum := by
  have hall : lines.filter (·.counts .settlementPayee) = lines :=
    List.filter_eq_self.mpr (by simp [ClearingLine.counts])
  unfold clearingTotal
  rw [hall]
  exact sum_map_sub' _ _ _

/-- An EasyPay clearance listed in a clearing to a remittance payer adds
nothing to its total. -/
@[checks "ONE-806.2"]
theorem payer_clearing_leaves_out_easyPay (l : ClearingLine) (lines : List ClearingLine)
    (hm : l.method = .easyPay) :
    clearingTotal .remittancePayer (l :: lines) = clearingTotal .remittancePayer lines := by
  simp [clearingTotal, ClearingLine.counts, hm]

/-- The total of a clearing to a settlement payee is never negative.

Open question for the business.  A payee whose clawbacks in a clearing exceed
what it is due in that clearing gets a negative total, which a bank transfer to
the payee cannot carry.  The example {lit}`clawbackExceedsDue` shows it: a
payee due 200.00 with 300.00 clawed back has a total of minus 100.00.  Does the
payee then become a remittance payer, or is the clawback carried forward to a
later clearing? -/
@[open_question, checks "ONE-806.3"]
theorem payee_clearing_nonneg (lines : List ClearingLine) :
    0 ≤ clearingTotal .settlementPayee lines := by
  sorry

/-! ## Short remittances -/

/-- Settling obligations in turn from budgets gives each at most what it
owes. -/
theorem fill_le_owed {K : Type} [DecidableEq K] (key : Obligation → K) (b : K → Nat)
    (os : List Obligation) : List.Forall₂ (fun a o => a ≤ o.owed) (fill key b os) os := by
  induction os generalizing b with
  | nil => exact .nil
  | cons o os ih => exact .cons (min_le_right _ _) (ih _)

/-- With nothing left in a key's budget, every obligation under that key gets
nothing. -/
theorem fill_zero_budget {K : Type} [DecidableEq K] (key : Obligation → K) (b : K → Nat)
    (os : List Obligation) (k : K) (hb : b k = 0) :
    ∀ p ∈ os.zip (fill key b os), key p.1 = k → p.2 = 0 := by
  induction os generalizing b with
  | nil => simp
  | cons o os ih =>
    intro p hp hk
    simp only [fill, List.zip_cons_cons, List.mem_cons] at hp
    rcases hp with rfl | hp
    · simp only at hk
      simp [hk, hb]
    · refine ih _ ?_ p hp hk
      by_cases hko : key o = k
      · subst hko
        simp [hb]
      · rw [Function.update_of_ne (Ne.symm hko)]
        exact hb

/-- Settling obligations in turn from budgets kept per key settles them oldest
first under that key. -/
theorem fill_oldestFirst {K : Type} [DecidableEq K] (key : Obligation → K) (b : K → Nat)
    (os : List Obligation) : OldestFirst key (os.zip (fill key b os)) := by
  induction os generalizing b with
  | nil => trivial
  | cons o os ih =>
    simp only [fill, List.zip_cons_cons, OldestFirst]
    refine ⟨fun hlt p hp hk => ?_, ih _⟩
    refine fill_zero_budget key _ os (key o) ?_ p hp hk
    rw [Function.update_self]
    omega

/-- Settling oldest first under a key implies settling oldest first under any
finer key. -/
theorem OldestFirst.weaken {K K' : Type} (k1 : Obligation → K) (k2 : Obligation → K')
    (h : ∀ x y, k2 x = k2 y → k1 x = k1 y) (l : List (Obligation × Nat)) (hl : OldestFirst k1 l) :
    OldestFirst k2 l := by
  induction l with
  | nil => trivial
  | cons p rest ih =>
    obtain ⟨o, a⟩ := p
    exact ⟨fun hlt q hq hk => hl.1 hlt q hq (h _ _ hk), ih hl.2⟩

/-- What obligations under one key are settled in all is that key's budget, up
to what they owe together. -/
theorem fill_sum_key {K : Type} [DecidableEq K] (key : Obligation → K) (b : K → Nat)
    (os : List Obligation) (k : K) :
    (((os.zip (fill key b os)).filter fun p => key p.1 = k).map (·.2)).sum =
      min (b k) ((os.filter fun o => key o = k).map (·.owed)).sum := by
  induction os generalizing b with
  | nil => simp
  | cons o os ih =>
    simp only [fill, List.zip_cons_cons, List.filter_cons]
    by_cases hk : key o = k
    · subst hk
      simp only [decide_true, ite_true, List.map_cons, List.sum_cons, ih, Function.update_self]
      omega
    · simp only [hk, decide_false, Bool.false_eq_true, ite_false, ih]
      rw [Function.update_of_ne (Ne.symm hk)]

/-- Settling obligations in turn from one budget settles in all the budget, up
to what they owe together. -/
theorem fill_sum_const (b : Unit → Nat) (os : List Obligation) :
    (fill (fun _ => ()) b os).sum = min (b ()) (totalOwed os) := by
  induction os generalizing b with
  | nil => simp [fill, totalOwed]
  | cons o os ih =>
    simp only [fill, List.sum_cons, ih, Function.update_self, totalOwed, List.map_cons] at ih ⊢
    omega

/-- No clearance is settled for more than the payer owes on it, under every
reading and every rounding. -/
@[checks "ONE-807.1"]
theorem allocation_within_owed (a : AllocationReading) (rd : Rounding) (paid : Nat)
    (os : List Obligation) : List.Forall₂ (fun x o => x ≤ o.owed) (allocate a rd paid os) os := by
  cases a <;> exact fill_le_owed _ _ _

/-- The clearances to each settlement payee are settled oldest first, under
every reading and every rounding. -/
@[checks "ONE-807.2"]
theorem allocation_oldest_first_per_payee (a : AllocationReading) (rd : Rounding) (paid : Nat)
    (os : List Obligation) : OldestFirst (·.payee) (os.zip (allocate a rd paid os)) := by
  cases a with
  | proportional => exact fill_oldestFirst _ _ _
  | oldestFirst =>
    exact OldestFirst.weaken (fun _ => ()) (·.payee) (fun _ _ _ => rfl) _ (fill_oldestFirst _ _ _)

/-- Under the Remittance of Funds page, each settlement payee's clearances are
settled for its proportional share of the payment, capped at what it is owed,
under every rounding. -/
@[checks "ONE-807.3"]
theorem proportional_share_settled (rd : Rounding) (paid : Nat) (os : List Obligation)
    (payee : String) :
    (((os.zip (allocate .proportional rd paid os)).filter fun p => p.1.payee = payee).map (·.2)).sum =
      min (share rd paid os payee) (owedTo os payee) :=
  fill_sum_key (·.payee) _ os payee

/-- Under the Transfer of Funds page, the payer's clearances are settled in the
order they were recorded, whatever the payee, under every rounding. -/
@[checks "ONE-807.4"]
theorem transfer_oldest_first (rd : Rounding) (paid : Nat) (os : List Obligation) :
    OldestFirst (fun _ => ()) (os.zip (allocate .oldestFirst rd paid os)) :=
  fill_oldestFirst _ _ _

/-- Under the Transfer of Funds page a short payment is allocated in full. -/
theorem transfer_allocates_all (rd : Rounding) (paid : Nat) (os : List Obligation)
    (hshort : paid ≤ totalOwed os) : (allocate .oldestFirst rd paid os).sum = paid := by
  simp only [allocate]
  rw [fill_sum_const]
  omega

/-- A short payment is allocated in full and no more: the amounts settled add
up to what was paid.

Open question for the business.  Under the Remittance of Funds page each
settlement payee's share has to be rounded to a minor unit, and the rounded
shares need not add up to the payment.  The example {lit}`threePayees` shows
it: 100.00 split between three payees owed 100.00 each settles 99.99 when
shares are rounded down and 100.02 when they are rounded up.  Under the
Transfer of Funds page the whole payment is allocated
({name}`transfer_allocates_all`).  How is a proportional share rounded, and
who receives the remainder? -/
@[open_question, checks "ONE-807.5"]
theorem allocation_whole_payment (a : AllocationReading) (rd : Rounding) (paid : Nat)
    (os : List Obligation) (hshort : paid ≤ totalOwed os) :
    (allocate a rd paid os).sum = paid := by
  sorry

/-- A short payment settles each clearance for the same amount under either
source page.

Open question for the business.  The Remittance of Funds page splits a short
payment across the settlement payees in proportion to what each is owed; the
Transfer of Funds page applies it to the payer's obligations in the order
they were recorded, whatever the payee.  The example {lit}`twoAirlines` shows
them differ: a payer owing airline A 100.00 (older) and airline B 100.00
(newer) pays 100.00, and A and B receive 50.00 each under the first page and
100.00 and nothing under the second.  Which allocation does the Clearance
Manager use? -/
@[open_question, checks "ONE-807.6"]
theorem one_allocation (rd : Rounding) (paid : Nat) (os : List Obligation)
    (hshort : paid < totalOwed os) :
    allocate .proportional rd paid os = allocate .oldestFirst rd paid os := by
  sorry

/-! ## Billing by service providers -/

/-- A bill for a service that is not delivered or consumed is refused unless
the provider has a bilateral agreement, under every reading. -/
@[checks "ONE-808.1"]
theorem bill_refused_unless_consumed (c : ConsumptionReading) (agreement : String → Bool)
    (services : List ProvidedService) (billed : List Bill) (b : Bill) (s : ProvidedService)
    (hs : services.find? (·.service.id == b.serviceId) = some s)
    (hc : c.consumed s.service.delivery = false) (ha : agreement b.provider = false) :
    acceptBill c agreement services billed b = false := by
  simp [acceptBill, hs, hc, ha]

/-- A bill from a provider that does not deliver the service is refused, under
every reading. -/
@[checks "ONE-808.2"]
theorem bill_refused_other_provider (c : ConsumptionReading) (agreement : String → Bool)
    (services : List ProvidedService) (billed : List Bill) (b : Bill) (s : ProvidedService)
    (hs : services.find? (·.service.id == b.serviceId) = some s) (hp : s.provider ≠ b.provider) :
    acceptBill c agreement services billed b = false := by
  simp [acceptBill, hs, hp]

/-- What is billed for a service after one more bill. -/
theorem billedFor_append (billed : List Bill) (b : Bill) (id : String) :
    billedFor (billed ++ [b]) id = billedFor billed id + if b.serviceId = id then b.amount else 0 := by
  by_cases h : b.serviceId = id <;> simp [billedFor, List.filter_append, h]

/-- Whatever bills providers send, the total billed for a service stays within
its settlement value, and at zero while it is not delivered or consumed unless
its provider has a bilateral agreement, under every reading. -/
@[checks "ONE-808.3"]
theorem billed_within_value (c : ConsumptionReading) (agreement : String → Bool)
    (services : List ProvidedService) (bs : List Bill) (s : ProvidedService)
    (hs : services.find? (·.service.id == s.service.id) = some s) :
    billedFor (billAll c agreement services [] bs) s.service.id ≤
      if c.consumed s.service.delivery || agreement s.provider then s.settlementValue else 0 := by
  suffices ∀ billed, billedFor billed s.service.id ≤
      (if c.consumed s.service.delivery || agreement s.provider then s.settlementValue else 0) →
      billedFor (billAll c agreement services billed bs) s.service.id ≤
        if c.consumed s.service.delivery || agreement s.provider then s.settlementValue else 0 from
    this [] (by simp [billedFor])
  induction bs with
  | nil => intro billed h; exact h
  | cons b bs ih =>
    intro billed h
    simp only [billAll]
    apply ih
    by_cases hacc : acceptBill c agreement services billed b = true
    · simp only [hacc, ↓reduceIte, billedFor_append]
      by_cases hid : b.serviceId = s.service.id
      · have hfind : services.find? (·.service.id == b.serviceId) = some s := by rw [hid]; exact hs
        simp only [acceptBill, hfind, Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq] at hacc
        obtain ⟨⟨hp, hcon⟩, hle⟩ := hacc
        have hok : (c.consumed s.service.delivery || agreement s.provider) = true := by
          rw [hp]; exact hcon
        rw [hid] at hle
        simp only [hid, ↓reduceIte, hok]
        omega
      · simp only [hid, ↓reduceIte, Nat.add_zero]
        exact h
    · simp only [hacc, Bool.false_eq_true, ↓reduceIte]
      exact h

/-- A bill for a delivered service within what is left of its settlement value
is accepted, under every reading. -/
@[checks "ONE-808.4"]
theorem delivered_bill_accepted (c : ConsumptionReading) (agreement : String → Bool)
    (services : List ProvidedService) (billed : List Bill) (b : Bill) (s : ProvidedService)
    (hs : services.find? (·.service.id == b.serviceId) = some s)
    (hd : s.service.delivery = .delivered) (hp : s.provider = b.provider)
    (hle : billedFor billed b.serviceId + b.amount ≤ s.settlementValue) :
    acceptBill c agreement services billed b = true := by
  simp [acceptBill, hs, hd, hp, c.delivered, hle]

/-! ## Revenue and the order's balance -/

/-- Until a service reaches a final delivery status, the whole amount paid for
it is held as a liability and none of it is revenue, under every reading. -/
@[checks "ONE-809.1"]
theorem liability_until_final (r : RevenueReading) (b : ServiceBooks)
    (h : isFinal b.delivery = false) : b.liability r = b.paid ∧ b.revenue r = 0 := by
  simp [ServiceBooks.liability, ServiceBooks.revenue, h]

/-- The amount paid for a delivered service is revenue, under every
reading. -/
@[checks "ONE-809.2"]
theorem delivered_earns (r : RevenueReading) (b : ServiceBooks) (h : b.delivery = .delivered) :
    b.revenue r = b.paid := by
  simp [ServiceBooks.revenue, h, isFinal, r.delivered]

/-- When a service reaches a final delivery status, none of the amount paid
for it is held as a liability.

Open question for the business.  The sources do not say which final statuses
earn revenue.  Under a reading that keeps the amount paid for a no-show as a
liability, or that does not recognize a penalty when a cancellation is
reported, money stays a liability on a service that will never change again.
The examples {lit}`noShowTreatments` and {lit}`cancelWithPenalty` show it.
For DELIVERED, NOT CLAIMED, EXPIRED and FAILED TO DELIVER, does the amount
paid earn revenue, go back as a refund or stay a liability, and when is a
penalty reported at cancellation recognized? -/
@[open_question, checks "ONE-809.3"]
theorem final_status_no_liability (r : RevenueReading) (b b' : ServiceBooks) (e : BookEvent)
    (h : bookStep r b e = some b') (hf : isFinal b'.delivery = true) : b'.liability r = 0 := by
  sorry

/-- Every event keeps a service's books balanced, under every reading. -/
theorem bookStep_balanced (r : RevenueReading) (b : ServiceBooks) (e : BookEvent)
    (h : b.Balanced r) : ((bookStep r b e).getD b).Balanced r := by
  cases hstep : bookStep r b e with
  | none => exact h
  | some b' =>
    simp only [Option.getD_some]
    unfold ServiceBooks.Balanced at h ⊢
    cases e with
    | pay x =>
      simp only [bookStep] at hstep
      split_ifs at hstep with hf
      cases hstep
      have hf' : isFinal b.delivery = false := by simpa using hf
      simp [ServiceBooks.liability, ServiceBooks.revenue, hf'] at h ⊢
      omega
    | finish st =>
      simp only [bookStep] at hstep
      split_ifs at hstep with hf ht
      all_goals
        cases hstep
        simp at hf
        obtain ⟨⟨hb, hs⟩, hne⟩ := hf
        have h0 : b.refunded = 0 ∧ b.forfeited = 0 := by
          simp [ServiceBooks.liability, ServiceBooks.revenue, hb] at h
          omega
        simp only [ServiceBooks.liability, ServiceBooks.revenue, hs, hne, Bool.not_true,
          Bool.false_eq_true, ↓reduceIte]
        cases htr : r.treat st <;> simp only [htr, reduceCtorEq, ↓reduceIte, not_true_eq_false] at ht ⊢ <;> omega
    | cancel rf pen forf =>
      simp only [bookStep] at hstep
      split_ifs at hstep with hf
      cases hstep
      simp at hf
      obtain ⟨-, hsum⟩ := hf
      simp only [ServiceBooks.liability, ServiceBooks.revenue]
      cases r.penaltyEarned <;> simp [isFinal] <;> omega

/-- Totals over services whose books balance balance too. -/
theorem totals_balanced (r : RevenueReading) (o : OrderBooks) (h : ∀ b ∈ o, b.Balanced r) :
    (o.totals r).Balanced := by
  induction o with
  | nil => simp [OrderBooks.totals, OrderTotals.Balanced]
  | cons b bs ih =>
    have hb := h b (by simp)
    have ih' := ih fun x hx => h x (by simp [hx])
    simp only [OrderBooks.totals, OrderTotals.Balanced, List.map_cons, List.sum_cons] at ih' ⊢
    unfold ServiceBooks.Balanced at hb
    omega

/-- Running events over an order's books keeps every service's books
balanced. -/
theorem run_balanced (r : RevenueReading) (o : OrderBooks) (es : List (String × BookEvent))
    (h : ∀ b ∈ o, b.Balanced r) : ∀ b ∈ o.run r es, b.Balanced r := by
  induction es generalizing o with
  | nil => exact h
  | cons e es ih =>
    obtain ⟨id, ev⟩ := e
    apply ih
    intro b hb
    simp only [OrderBooks.apply, List.mem_map] at hb
    obtain ⟨b0, hb0, rfl⟩ := hb
    split_ifs
    · exact bookStep_balanced r b0 ev (h b0 hb0)
    · exact h b0 hb0

/-- Whatever accounting is told about an order's services, its payments equal
its refunds, plus the amount held as liability, plus the revenue recognized,
plus the forfeited amounts, under every reading. -/
@[checks "ONE-809.4"]
theorem order_books_balance (r : RevenueReading) (ids : List String)
    (es : List (String × BookEvent)) :
    ((OrderBooks.run r (ids.map ServiceBooks.new) es).totals r).Balanced := by
  apply totals_balanced
  apply run_balanced
  intro b hb
  simp only [List.mem_map] at hb
  obtain ⟨id, -, rfl⟩ := hb
  simp [ServiceBooks.Balanced, ServiceBooks.new, ServiceBooks.liability, ServiceBooks.revenue,
    isFinal]

/-- Whatever accounting is told about an order's services, it never refunds
more than was paid, under every reading. -/
@[checks "ONE-809.5"]
theorem refunds_within_payments (r : RevenueReading) (ids : List String)
    (es : List (String × BookEvent)) :
    ((OrderBooks.run r (ids.map ServiceBooks.new) es).totals r).refunded ≤
      ((OrderBooks.run r (ids.map ServiceBooks.new) es).totals r).paid := by
  have := order_books_balance r ids es
  unfold OrderTotals.Balanced at this
  omega

/-- A cancellation whose refund, penalty and forfeited amount do not add up to
the amount paid for the service is refused, under every reading. -/
@[checks "ONE-809.6"]
theorem cancel_must_add_up (r : RevenueReading) (b : ServiceBooks) (rf pen forf : Nat)
    (h : rf + pen + forf ≠ b.paid) : bookStep r b (.cancel rf pen forf) = none := by
  simp [bookStep, h]

end Rules.OneOrder.Accounting
