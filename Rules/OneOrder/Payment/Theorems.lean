import Rules.Core.Attributes
import Rules.OneOrder.Payment.Status
import Rules.OneOrder.Payment.Accept
import Rules.OneOrder.Payment.Outcome
import Rules.OneOrder.Payment.TimeLimit

/-!
# Guarantees about payments

Properties the ONE Order payment rules are claimed to have.  A guarantee that
depends on a reading of the guide holds for every reading; one left open is a
question for the business.
-/

namespace Rules.OneOrder.Payment

open Rules.Core

/-- A payment is FAILED exactly when the transaction of at least one of its
payment methods failed. -/
@[checks "ONE-301.1"]
theorem status_failed_iff (p : Transaction) :
    p.status = .failed ↔ ∃ m ∈ p.parts, m.status = .failed := by
  unfold Transaction.status
  split_ifs with h1 h2 <;> simp_all

/-- A payment is SUCCESSFUL exactly when the transactions of all its payment
methods succeeded. -/
@[checks "ONE-301.2"]
theorem status_successful_iff (p : Transaction) :
    p.status = .successful ↔ ∀ m ∈ p.parts, m.status = .successful := by
  unfold Transaction.status
  split_ifs with h1 h2 <;> simp_all
  obtain ⟨m, hm, hf⟩ := h1
  exact ⟨m, hm, by simp [hf]⟩

/-- A payment is PENDING exactly when no method's transaction failed and at
least one is still pending. -/
@[checks "ONE-301.3"]
theorem status_pending_iff (p : Transaction) :
    p.status = .pending ↔
      (∀ m ∈ p.parts, m.status ≠ .failed) ∧ ∃ m ∈ p.parts, m.status = .pending := by
  unfold Transaction.status
  split_ifs with h1 h2 <;> simp_all
  obtain ⟨m, hm, hs⟩ := h2
  refine ⟨m, hm, ?_⟩
  have hf := h1 m hm
  cases hm' : m.status <;> simp_all

/-- An order item is counted paid exactly when a SUCCESSFUL payment covers it:
PENDING and FAILED payments never count. -/
@[checks "ONE-302.1 ONE-302.2"]
theorem isPaid_iff (ps : List Transaction) (ref : String) :
    isPaid ps ref = true ↔ ∃ p ∈ ps, p.status = .successful ∧ ref ∈ p.covers := by
  simp [isPaid, Transaction.pays]

/-- A payment with a failed method pays for none of the order items it covers,
and its outcome leaves their services and payment time limits as they were.
A seller who wants one item paid even if the method for another is declined
must send two payments. -/
@[checks "ONE-302.3"]
theorem failed_method_pays_nothing (p : Transaction) (items : List PayableItem)
    (h : ∃ m ∈ p.parts, m.status = .failed) :
    (∀ ref, p.pays ref = false) ∧ applyOutcome p items = items := by
  have hf : p.status = .failed := (status_failed_iff p).mpr h
  exact ⟨fun ref => by simp [Transaction.pays, hf], by simp [applyOutcome, hf]⟩

/-- When the airline reports that a method's pending transaction succeeded or
failed, the outcome is recorded, under every reading of the guide. -/
@[checks "ONE-303.1"]
theorem recordOutcome_pending (r : OutcomeReading) (p : Transaction) (ref : String)
    (s : PaymentStatus) (hs : s ≠ .pending) (m : MethodPart) (hm : m ∈ p.parts)
    (hid : m.id = ref) (hp : m.status = .pending) :
    { m with status := s } ∈ (recordOutcome r p ref s).parts := by
  have hallow : r.allows .pending s = true := by
    cases s
    · exact absurd rfl hs
    · exact r.pendingToSuccessful
    · exact r.pendingToFailed
  simp only [recordOutcome, List.mem_map]
  exact ⟨m, hm, by simp [hid, MethodPart.record, hp, hallow]⟩

/-- Reporting the outcome of one method's transaction leaves the transactions
of the payment's other methods as they were. -/
@[checks "ONE-303.2"]
theorem recordOutcome_other_methods (r : OutcomeReading) (p : Transaction) (ref : String)
    (s : PaymentStatus) (m : MethodPart) (hm : m ∈ p.parts) (hid : m.id ≠ ref) :
    m ∈ (recordOutcome r p ref s).parts := by
  simp only [recordOutcome, List.mem_map]
  exact ⟨m, hm, by simp [hid]⟩

/-- Under a reading where no transaction leaves SUCCESSFUL or FAILED, recording
an outcome never changes the status of a SUCCESSFUL or FAILED payment. -/
theorem recordOutcome_final_of_reading (r : OutcomeReading)
    (hr : ∀ a b, a ≠ .pending → r.allows a b = true → b = a)
    (p : Transaction) (ref : String) (s : PaymentStatus)
    (h : p.status = .successful ∨ p.status = .failed) :
    (recordOutcome r p ref s).status = p.status := by
  have keep : ∀ m : MethodPart, m.status ≠ .pending →
      (if m.id = ref then m.record r s else m).status = m.status := by
    intro m hm
    split_ifs
    · unfold MethodPart.record
      split_ifs with ha
      · exact hr _ _ hm ha
      · rfl
    · rfl
  rcases h with h | h
  · rw [h, status_successful_iff]
    rw [status_successful_iff] at h
    intro m' hm'
    simp only [recordOutcome, List.mem_map] at hm'
    obtain ⟨m, hm, rfl⟩ := hm'
    rw [keep m (by simp [h m hm]), h m hm]
  · rw [h, status_failed_iff]
    obtain ⟨m, hm, hf⟩ := (status_failed_iff p).mp h
    refine ⟨_, List.mem_map.mpr ⟨m, hm, rfl⟩, ?_⟩
    rw [keep m (by simp [hf]), hf]

/-- A SUCCESSFUL or FAILED payment keeps its status whatever outcome the airline
later reports for one of its methods.

Open question for the business.  The guide says a PENDING payment moves to
SUCCESSFUL or FAILED and does not say whether either is final.  Under a reading
where a card chargeback turns a successful transaction into a failed one, a
SUCCESSFUL payment becomes FAILED; the example {lit}`chargeback` shows it.
Under a reading where a redirected payment completed after the airline marked
it failed is recorded, a FAILED payment becomes SUCCESSFUL; the example
{lit}`lateRedirectCapture` shows it.  Can a SUCCESSFUL payment later fail, can
a FAILED payment later succeed, and what then happens to the order items it
covers? -/
@[open_question, checks "ONE-303.3"]
theorem recordOutcome_settled_final (r : OutcomeReading) (p : Transaction) (ref : String)
    (s : PaymentStatus) (h : p.status = .successful ∨ p.status = .failed) :
    (recordOutcome r p ref s).status = p.status := by
  sorry

/-- An accepted payment charges each payment method its requested amount plus
its surcharge: the two amounts added as money, in one currency, for every
method in turn. -/
@[checks "ONE-304.1"]
theorem acceptPayment_charges (o : PayableOrder) (p : Transaction) (now : Instant)
    (cs : List Money) (h : acceptPayment o p now = .ok cs) :
    cs.map some = p.parts.map fun m => m.requested.add m.surcharge := by
  unfold acceptPayment at h
  split_ifs at h with h1 h2 h3 h4 h5
  cases h
  simp only [Bool.or_eq_true, List.any_eq_true, not_or, not_exists, not_and] at h2
  rw [List.map_map]
  apply List.map_congr_left
  intro m hm
  have hc : m.requested.currency = p.currency ∧ m.surcharge.currency = p.currency := by
    simpa using h2.2 m hm
  simp [Money.add, MethodPart.charged, hc.1, hc.2]

/-- An accepted payment's requested amounts add up to the price of the order
items it covers. -/
@[checks "ONE-304.2"]
theorem acceptPayment_requested_eq_price (o : PayableOrder) (p : Transaction) (now : Instant)
    (cs : List Money) (h : acceptPayment o p now = .ok cs) :
    p.requestedTotal = priceTotal (o.coveredBy p) := by
  unfold acceptPayment at h
  split_ifs at h with h1 h2 h3 h4 h5
  simpa using h5

/-- An accepted payment charges in total the price of the order items it
covers plus the surcharges of its payment methods. -/
@[checks "ONE-304.3"]
theorem acceptPayment_total (o : PayableOrder) (p : Transaction) (now : Instant)
    (cs : List Money) (h : acceptPayment o p now = .ok cs) :
    (cs.map (·.amount)).sum = priceTotal (o.coveredBy p) + p.surchargeTotal := by
  have hreq := acceptPayment_requested_eq_price o p now cs h
  unfold acceptPayment at h
  split_ifs at h
  cases h
  rw [← hreq]
  simp only [Transaction.requestedTotal, Transaction.surchargeTotal, List.map_map,
    Function.comp_def, MethodPart.charged]
  exact List.sum_map_add

/-- A payment made at or after the payment time limit of an order item it
covers is rejected. -/
@[checks "ONE-304.4"]
theorem acceptPayment_rejects_after_time_limit (o : PayableOrder) (p : Transaction)
    (now : Instant) (pi : PayableItem) (hpi : pi ∈ o.coveredBy p) (t : Instant)
    (ht : pi.timeLimit = some t) (hle : now ≥ t) :
    acceptPayment o p now = .error .timeLimitPassed := by
  have : (o.coveredBy p).any (fun pi => pi.timeLimit.any (· ≤ now)) = true :=
    List.any_eq_true.mpr ⟨pi, hpi, by simp [ht, hle]⟩
  simp [acceptPayment, this]

/-- In an accepted payment, a commitment method carries an amount and a
surcharge of zero, and every order item the payment covers has nothing to
pay. -/
@[checks "ONE-304.5 ONE-304.6"]
theorem acceptPayment_commitment_zero (o : PayableOrder) (p : Transaction) (now : Instant)
    (cs : List Money) (h : acceptPayment o p now = .ok cs) (m : MethodPart) (hm : m ∈ p.parts)
    (hc : m.method = .commitment) :
    m.requested.amount = 0 ∧ m.surcharge.amount = 0 ∧
      ∀ pi ∈ o.coveredBy p, pi.item.price.amount = 0 := by
  unfold acceptPayment at h
  split_ifs at h with h1 h2 h3 h4 h5
  simp only [List.any_eq_true, not_exists, not_and, decide_eq_true_eq] at h3
  have hz := h3 m hm hc
  simp only [not_or, not_not] at hz
  refine ⟨hz.1, hz.2, ?_⟩
  have hany : p.parts.any (·.method = .commitment) = true :=
    List.any_eq_true.mpr ⟨m, hm, by simp [hc]⟩
  simp only [hany, Bool.true_and, decide_eq_true_eq, not_not] at h4
  intro pi hpi
  exact List.sum_eq_zero_iff.mp h4 _ (List.mem_map.mpr ⟨pi, hpi, rfl⟩)

/-- When a payment is SUCCESSFUL, each CONFIRMED service of an order item it
covers is READY TO PROCEED afterwards. -/
@[checks "ONE-305.1"]
theorem applyOutcome_ready (p : Transaction) (items : List PayableItem)
    (h : p.status = .successful) (pi : PayableItem) (hpi : pi ∈ items)
    (hc : pi.item.id ∈ p.covers) (s : Service) (hs : s ∈ pi.item.services)
    (hconf : s.delivery = .confirmed) :
    ∃ pi' ∈ applyOutcome p items, pi'.item.id = pi.item.id ∧
      { s with delivery := .readyToProceed } ∈ pi'.item.services := by
  refine ⟨pi.markPaid, ?_, rfl, ?_⟩
  · simp only [applyOutcome, h, ite_true, List.mem_map]
    exact ⟨pi, hpi, by simp [hc]⟩
  · simp only [PayableItem.markPaid, List.mem_map]
    exact ⟨s, hs, by simp [hconf]⟩

/-- When a payment is SUCCESSFUL, no order item it covers has a payment time
limit afterwards. -/
@[checks "ONE-305.2"]
theorem applyOutcome_no_time_limit (p : Transaction) (items : List PayableItem)
    (h : p.status = .successful) :
    ∀ pi ∈ applyOutcome p items, pi.item.id ∈ p.covers → pi.timeLimit = none := by
  intro pi' hpi' hc
  simp only [applyOutcome, h, ite_true, List.mem_map] at hpi'
  obtain ⟨pi, -, rfl⟩ := hpi'
  by_cases hpc : pi.item.id ∈ p.covers
  · simp [hpc, PayableItem.markPaid]
  · simp [hpc] at hc

/-- A payment that is not SUCCESSFUL, whether FAILED or PENDING, leaves every
order item as it was. -/
@[checks "ONE-305.3 ONE-305.4"]
theorem applyOutcome_unsuccessful (p : Transaction) (items : List PayableItem)
    (h : p.status ≠ .successful) :
    applyOutcome p items = items := by
  simp [applyOutcome, h]

/-- A payment's outcome leaves the order items it does not cover as they were. -/
@[checks "ONE-305.5"]
theorem applyOutcome_uncovered (p : Transaction) (items : List PayableItem) :
    (applyOutcome p items).filter (fun pi => pi.item.id ∉ p.covers) =
      items.filter (fun pi => pi.item.id ∉ p.covers) := by
  unfold applyOutcome
  split_ifs
  · induction items with
    | nil => rfl
    | cons a l ih =>
      by_cases ha : a.item.id ∈ p.covers
      · simp [ha, PayableItem.markPaid] at ih ⊢
        exact ih
      · simp [ha] at ih ⊢
        exact ih
  · rfl

/-- An order item whose payment time limit has passed, with no SUCCESSFUL
payment covering it, is removed: its services take the statuses of the
removal. -/
@[checks "ONE-306.1"]
theorem expireUnpaid_removes (r : Removal) (now : Instant) (o : PayableOrder)
    (pi : PayableItem) (hpi : pi ∈ o.items) (t : Instant) (ht : pi.timeLimit = some t)
    (hle : now ≥ t) (hunpaid : isPaid o.payments pi.item.id = false) :
    pi.remove r ∈ (expireUnpaid r now o).items := by
  have hl : o.lapses now pi = true := by simp [PayableOrder.lapses, ht, hle, hunpaid]
  simp only [expireUnpaid, List.mem_map]
  exact ⟨pi, hpi, by simp [hl]⟩

/-- When an order item is removed at its payment time limit, every payment
covering it that was PENDING is FAILED afterwards. -/
@[checks "ONE-306.2"]
theorem expireUnpaid_fails_pending (r : Removal) (now : Instant) (o : PayableOrder)
    (pi : PayableItem) (hpi : pi ∈ o.items) (t : Instant) (ht : pi.timeLimit = some t)
    (hle : now ≥ t) (hunpaid : isPaid o.payments pi.item.id = false)
    (p : Transaction) (hp : p ∈ o.payments) (hpend : p.status = .pending)
    (hc : pi.item.id ∈ p.covers) :
    ∃ p' ∈ (expireUnpaid r now o).payments, p'.id = p.id ∧ p'.status = .failed := by
  have hl : o.lapses now pi = true := by simp [PayableOrder.lapses, ht, hle, hunpaid]
  have hany : o.items.any (fun pi => o.lapses now pi && decide (pi.item.id ∈ p.covers)) = true :=
    List.any_eq_true.mpr ⟨pi, hpi, by simp [hl, hc]⟩
  refine ⟨p.failPending, ?_, rfl, ?_⟩
  · simp only [expireUnpaid, List.mem_map]
    exact ⟨p, hp, by simp [hpend, hany]⟩
  · obtain ⟨-, m, hm, hmp⟩ := (status_pending_iff p).mp hpend
    rw [status_failed_iff]
    exact ⟨_, List.mem_map.mpr ⟨m, hm, rfl⟩, by simp [hmp]⟩

/-- An order item that a SUCCESSFUL payment covers is never removed at a
payment time limit. -/
@[checks "ONE-306.3"]
theorem expireUnpaid_keeps_paid (r : Removal) (now : Instant) (o : PayableOrder)
    (pi : PayableItem) (hpi : pi ∈ o.items) (hpaid : isPaid o.payments pi.item.id = true) :
    pi ∈ (expireUnpaid r now o).items := by
  have hl : o.lapses now pi = false := by simp [PayableOrder.lapses, hpaid]
  simp only [expireUnpaid, List.mem_map]
  exact ⟨pi, hpi, by simp [hl]⟩

/-- An order item whose payment time limit has not passed, or that has none,
is left as it was. -/
@[checks "ONE-306.4"]
theorem expireUnpaid_keeps_before_limit (r : Removal) (now : Instant) (o : PayableOrder)
    (pi : PayableItem) (hpi : pi ∈ o.items) (hbefore : ∀ t, pi.timeLimit = some t → now < t) :
    pi ∈ (expireUnpaid r now o).items := by
  have hl : o.lapses now pi = false := by
    cases ht : pi.timeLimit with
    | none => simp [PayableOrder.lapses, ht]
    | some t =>
      have := hbefore t ht
      simp [PayableOrder.lapses, ht, not_le.mpr this]
  simp only [expireUnpaid, List.mem_map]
  exact ⟨pi, hpi, by simp [hl]⟩

/-- An unpaid order item does not stay in the order indefinitely: from some
instant on, the time limit rule removes it.

Open question for the business.  The rule removes an item only when its
payment time limit passes, and the guide lets an airline create an order item
without one.  The ARMI guidance expects a limit on every unpaid item, while the
EASD guide says a missing limit only means the airline gave no advice.  An item
without a limit is never removed and holds its services with nothing paid; the
example {lit}`noTimeLimit` shows it a year after the order was created.  May
an unpaid order item exist without a payment time limit, and if so, may it stay
unpaid indefinitely? -/
@[open_question, checks "ONE-306.5"]
theorem unpaid_item_removed_eventually (r : Removal) (o : PayableOrder) (pi : PayableItem)
    (hpi : pi ∈ o.items) (hunpaid : isPaid o.payments pi.item.id = false) :
    ∃ t : Instant, ∀ now ≥ t, pi.remove r ∈ (expireUnpaid r now o).items := by
  sorry

/-- When the removal gives a removed item's services the delivery status
REMOVED, none of them holds value, under every reading of the guide. -/
theorem removed_item_holds_no_value_of_removed (v : ValueReading) (r : Removal)
    (hr : r.delivery = .removed) (pi : PayableItem) :
    (pi.remove r).item.isActive v = false := by
  simp [PayableItem.remove, OrderItem.isActive, Service.holdsValue, hr, v.removed]

/-- An order item removed at its payment time limit holds no value: none of its
services holds value afterwards.

Open question for the business.  The guide says such an item is removed and
names no resulting statuses.  If its services become REMOVED, none holds value
under every reading of the guide.  If they become EXPIRED, whether they hold
value is itself unsettled: under the cautious reading an expired service holds
value, so the removed item stays active and keeps its order opened.  The
example {lit}`removalStatuses` shows both.  Which service status and delivery
status does an item take when its payment time limit passes unpaid? -/
@[open_question, checks "ONE-306.6"]
theorem removed_item_holds_no_value (v : ValueReading) (r : Removal) (now : Instant)
    (o : PayableOrder) (pi : PayableItem) (hpi : pi ∈ o.items) (hl : o.lapses now pi = true) :
    (pi.remove r).item.isActive v = false := by
  sorry

end Rules.OneOrder.Payment
