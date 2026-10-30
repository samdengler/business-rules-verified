import Rules.Core.Attributes
import Rules.OneOrder.Change.Balance
import Rules.OneOrder.Change.Cancel
import Rules.OneOrder.Change.Transfer

/-!
# Guarantees of the change and cancellation rules

Properties the change and cancellation rules are claimed to have.  A guarantee
about the amounts due holds under both readings of a penalty above the
refundable value (see {lit}`ExcessPenalty`); one left open is a question for
the business.
-/

namespace Rules.OneOrder.Change

open Rules.Core

/-! ## Price differential -/

/-- A change whose amounts are not all in one currency is rejected unpriced. -/
@[checks "ONE-201.1"]
theorem differential_rejects_mixed_currency (r : ExcessPenalty) (q : ChangeQuote)
    (h : q.newPrice.currency ≠ q.oldPrice.currency ∨ q.penalty.currency ≠ q.oldPrice.currency ∨
      q.forfeited.currency ≠ q.oldPrice.currency) :
    priceDifferential r q = .error .mixedCurrency := by
  unfold priceDifferential
  split_ifs
  rfl

/-- A price differential the rule produces states the due amounts of
{name}`statedDue` and their type code. -/
theorem priceDifferential_ok (r : ExcessPenalty) (q : ChangeQuote) (d : PriceDifferential)
    (h : priceDifferential r q = .ok d) :
    d.dueToAirline.amount = (statedDue r q).toAirline ∧
      d.dueByAirline.amount = (statedDue r q).byAirline ∧
      d.type = typeOf q.settlement (statedDue r q) := by
  unfold priceDifferential at h
  split_ifs at h
  cases h
  exact ⟨rfl, rfl, rfl⟩

/-- A type code names a collection exactly when an amount is due to the
airline. -/
@[checks "ONE-201.2"]
theorem differential_collects_iff (r : ExcessPenalty) (q : ChangeQuote) (d : PriceDifferential)
    (h : priceDifferential r q = .ok d) :
    d.type.collects = true ↔ 0 < d.dueToAirline.amount := by
  obtain ⟨hto, -, hty⟩ := priceDifferential_ok r q d h
  rw [hty, hto]
  unfold typeOf statedDue
  split_ifs <;> simp_all [DifferentialType.collects] <;> omega

/-- A type code names a refund or a value store exactly when an amount is due
by the airline. -/
@[checks "ONE-201.3"]
theorem differential_pays_iff (r : ExcessPenalty) (q : ChangeQuote) (d : PriceDifferential)
    (h : priceDifferential r q = .ok d) :
    d.type.pays = true ↔ 0 < d.dueByAirline.amount := by
  obtain ⟨-, hby, hty⟩ := priceDifferential_ok r q d h
  rw [hty, hby]
  unfold typeOf statedDue
  split_ifs <;> simp_all [DifferentialType.pays] <;> omega

/-- When the seller asks to keep the value of cancelled items for later use,
the differential is typed Reusable and both due amounts are zero. -/
@[checks "ONE-201.4"]
theorem respend_reusable (r : ExcessPenalty) (q : ChangeQuote) (d : PriceDifferential)
    (h : priceDifferential r q = .ok d) (hs : q.settlement = .respend) :
    d.type = .reusable ∧ d.dueToAirline.amount = 0 ∧ d.dueByAirline.amount = 0 := by
  obtain ⟨hto, hby, hty⟩ := priceDifferential_ok r q d h
  simp [hto, hby, hty, typeOf, statedDue, hs]

/-- For every change or cancellation the airline prices, the amount due to the
airline less the amount due by the airline is the new price, less the old
price, plus the penalty, plus the forfeited amount.

Open question for the business.  Two cases break it.  When the seller asks to
keep the value of cancelled items for later use, the guide shows both due
amounts as zero, while the formula gives the whole refundable value as due by
the airline; the example {lit}`respendCancellation` shows it.  Under the reading
that waives a penalty above the refundable value, the airline charges less
than the penalty, so the formula overstates what the customer pays; the
example {lit}`penaltyAboveRefund` shows it.  Should the value held for later use
count as the new price, and is a penalty above the refundable value collected
or waived? -/
@[open_question, checks "ONE-201.5"]
theorem differential_nets (r : ExcessPenalty) (q : ChangeQuote) (d : PriceDifferential)
    (h : priceDifferential r q = .ok d) :
    (d.dueToAirline.amount : Int) - d.dueByAirline.amount =
      (q.newPrice.amount : Int) - q.oldPrice.amount + q.penalty.amount + q.forfeited.amount := by
  sorry

/-! ## Penalties -/

/-- With a netted penalty, the due amounts net to the price difference plus
the penalty charged, and at most one of them is above zero. -/
@[checks "ONE-202.1"]
theorem netted_single_amount (r : ExcessPenalty) (q : ChangeQuote) (h : q.handling = .netted) :
    (dueAmounts r q).net = q.difference + r.charged q ∧
      ((dueAmounts r q).toAirline = 0 ∨ (dueAmounts r q).byAirline = 0) := by
  simp only [dueAmounts, h, DueAmounts.net]
  omega

/-- With a separate penalty, the amount due to the airline is the penalty
charged plus any price difference the customer pays, and the amount due by
the airline is any price difference the airline returns. -/
@[checks "ONE-202.2"]
theorem separate_penalty_added (r : ExcessPenalty) (q : ChangeQuote) (h : q.handling = .separate) :
    (dueAmounts r q).toAirline = r.charged q + q.difference.toNat ∧
      (dueAmounts r q).byAirline = (-q.difference).toNat := by
  simp [dueAmounts, h]

/-- Netting the penalty or charging it separately gives the customer the same
net amount, under both readings of the guide. -/
@[checks "ONE-202.3"]
theorem net_same_either_way (r : ExcessPenalty) (q : ChangeQuote) :
    (dueAmounts r { q with handling := .netted }).net =
      (dueAmounts r { q with handling := .separate }).net := by
  simp only [dueAmounts, DueAmounts.net, ExcessPenalty.charged, ChangeQuote.refundable,
    ChangeQuote.difference]
  cases r <;> simp only <;> omega

/-- Under the reading that collects the whole penalty, the due amounts net to
the new price, less the old price, plus the penalty, plus the forfeited
amount. -/
theorem due_amounts_net_of_collect (q : ChangeQuote) :
    (dueAmounts .collect q).net =
      (q.newPrice.amount : Int) - q.oldPrice.amount + q.penalty.amount + q.forfeited.amount := by
  cases hq : q.handling <;>
    simp only [dueAmounts, hq, DueAmounts.net, ExcessPenalty.charged, ChangeQuote.difference] <;>
    omega

/-- A cancellation never leaves the customer owing the airline money: the
amount due to the airline is no larger than the amount due by the airline,
when the forfeited amount is part of the old price.

Open question for the business.  Under the reading that collects the whole
penalty, a penalty larger than the refundable value leaves the customer
owing the difference.  The example {lit}`penaltyAboveRefund` shows it: a 1,000.00
order with 20.00 forfeited and a 1,000.00 penalty leaves 20.00 due to the
airline on a cancellation.  Under the other reading the guarantee holds, but
the due amounts no longer net to the formula of ONE-201.5.  Is a penalty
capped at the refundable value, or is the excess collected? -/
@[open_question, checks "ONE-202.4"]
theorem cancel_not_owing (r : ExcessPenalty) (q : ChangeQuote) (hnew : q.newPrice.amount = 0)
    (hf : q.forfeited.amount ≤ q.oldPrice.amount) :
    (dueAmounts r q).toAirline ≤ (dueAmounts r q).byAirline := by
  sorry

/-- Under the reading that waives a penalty above the refundable value, a
cancellation never leaves the customer owing the airline money. -/
theorem cancel_not_owing_of_waive (q : ChangeQuote) (hnew : q.newPrice.amount = 0)
    (hf : q.forfeited.amount ≤ q.oldPrice.amount) :
    (dueAmounts .waive q).toAirline ≤ (dueAmounts .waive q).byAirline := by
  cases hq : q.handling <;>
    simp only [dueAmounts, hq, ExcessPenalty.charged, ChangeQuote.refundable,
      ChangeQuote.difference, hnew] <;>
    omega

/-! ## Cancelling an order -/

/-- An order with no payment is cancelled at once: every service is cancelled
and removed, and the order keeps its items. -/
@[checks "ONE-203.1"]
theorem unpaid_cancelled_at_once (r : ExcessPenalty) (o : Order)
    (payments : List Rules.OfferOrder.Payment) (t : CancelTerms)
    (h : Rules.OfferOrder.totalPaid payments o.id = 0) :
    ∃ o', requestCancellation r o payments t = .cancelled o' ∧
      o'.items.map (·.id) = o.items.map (·.id) ∧
      ∀ i ∈ o'.items, ∀ s ∈ i.services, s.status = .cancelled ∧ s.delivery = .removed := by
  refine ⟨cancelDirect o, by simp [requestCancellation, h], ?_, ?_⟩
  · simp [cancelDirect, Function.comp_def]
  · simp [cancelDirect]

/-- An order cancelled at once has every item cancelled and is closed, under
every reading of the guide. -/
@[checks "ONE-203.2"]
theorem cancelled_at_once_closed (v : ValueReading) (r : ExcessPenalty) (o o' : Order)
    (payments : List Rules.OfferOrder.Payment) (t : CancelTerms)
    (h : requestCancellation r o payments t = .cancelled o') :
    (∀ i ∈ o'.items, itemStatuses v i = [.cancelled]) ∧ orderStatuses v o' = [.closed] := by
  have ho' : o' = cancelDirect o := by
    unfold requestCancellation at h
    split_ifs at h
    · cases h; rfl
    · split at h
      · cases h
      · split at h <;> cases h
  subst ho'
  constructor
  · intro i hi
    simp only [cancelDirect, List.mem_map] at hi
    obtain ⟨i₀, -, rfl⟩ := hi
    simp [itemStatuses, OrderItem.isActive, OrderItem.isCancelled, OrderItem.isClosed,
      Service.holdsValue, v.removed]
  · simp [orderStatuses, Order.isOpened, Order.isClosed, cancelDirect, OrderItem.isActive,
      OrderItem.isCancelled, OrderItem.isClosed, Service.holdsValue, v.removed]

/-- An order with any payment is never cancelled at once.  The request leads
to a cancellation offer, or to a rejection when the cancellation cannot be
priced. -/
@[checks "ONE-203.3"]
theorem paid_needs_offer (r : ExcessPenalty) (o : Order) (payments : List Rules.OfferOrder.Payment)
    (t : CancelTerms) (h : 0 < Rules.OfferOrder.totalPaid payments o.id) :
    (∃ d, requestCancellation r o payments t = .offer d) ∨
      ∃ e, requestCancellation r o payments t = .rejected e := by
  unfold requestCancellation
  simp only [show Rules.OfferOrder.totalPaid payments o.id ≠ 0 by omega, ↓reduceIte]
  split
  · exact Or.inr ⟨_, rfl⟩
  · split
    · exact Or.inl ⟨_, rfl⟩
    · exact Or.inr ⟨_, rfl⟩

/-- A cancellation offer never makes the amount due by the airline larger than
the payments received for the order.

Open question for the business.  The offer is priced from the order's price,
as in the worked examples, and the payments received do not enter it.  A
partly paid order is cancelled through an offer that returns its whole price.
The example {lit}`partlyPaidCancellation` shows it: a 1,000.00 order with
300.00 received gets an offer of 1,000.00 due by the airline.  Is the
refundable amount capped at the payments received, and which route applies
when some items are paid and others are not? -/
@[open_question, checks "ONE-203.4"]
theorem offer_within_payments (r : ExcessPenalty) (o : Order)
    (payments : List Rules.OfferOrder.Payment) (t : CancelTerms) (d : PriceDifferential)
    (h : requestCancellation r o payments t = .offer d) :
    d.dueByAirline.amount ≤ Rules.OfferOrder.totalPaid payments o.id := by
  sorry

/-! ## Changing an order item -/

/-- The item a change finds, and the order after it. -/
theorem changeItem_ok (o o' : Order) (c : ItemChange) (h : changeItem o c = .ok o') :
    ∃ old, o.items.find? (·.id = c.item) = some old ∧ o.items.all (·.id ≠ c.newItem) ∧
      o' = { o with items := o.items.map (afterChange c) ++ [newItemOf c old] } := by
  unfold changeItem at h
  split at h
  · cases h
  · rename_i old hold
    split_ifs at h with hdup
    cases h
    refine ⟨old, hold, ?_, rfl⟩
    simpa using hdup

/-- Every service a change keeps has a copy in the new item with the same
reference, passenger, segment and delivery status, confirmed. -/
@[checks "ONE-204.1"]
theorem change_keeps_services (o o' : Order) (c : ItemChange) (h : changeItem o c = .ok o')
    (old : OrderItem) (hold : o.items.find? (·.id = c.item) = some old)
    (s : Service) (hs : s ∈ old.services) (hk : s.id ∈ c.kept) :
    ∃ i ∈ o'.items, i.id = c.newItem ∧ { s with status := .confirmed } ∈ i.services := by
  obtain ⟨old', hold', -, rfl⟩ := changeItem_ok o o' c h
  rw [hold] at hold'
  cases hold'
  refine ⟨newItemOf c old, by simp, rfl, ?_⟩
  simp only [newItemOf, List.mem_append, List.mem_map, List.mem_filter]
  exact Or.inl ⟨s, ⟨hs, by simpa using hk⟩, rfl⟩

/-- Every service a change keeps stays in the changed item marked transferred,
with everything else about it, its delivery status included, as it was. -/
@[checks "ONE-204.2"]
theorem change_marks_transferred (o o' : Order) (c : ItemChange) (h : changeItem o c = .ok o')
    (old : OrderItem) (hold : o.items.find? (·.id = c.item) = some old)
    (s : Service) (hs : s ∈ old.services) (hk : s.id ∈ c.kept) :
    ∃ i ∈ o'.items, i.id = c.item ∧ { s with status := .transferred } ∈ i.services := by
  obtain ⟨old', hold', -, rfl⟩ := changeItem_ok o o' c h
  rw [hold] at hold'
  cases hold'
  have hid : old.id = c.item := by simpa using List.find?_some hold
  refine ⟨afterChange c old, ?_, by simp [afterChange, hid], ?_⟩
  · simp only [List.mem_append, List.mem_map]
    exact Or.inl ⟨old, List.mem_of_find?_eq_some hold, rfl⟩
  · simp only [afterChange, hid, ↓reduceIte, List.mem_map]
    exact ⟨s, hs, by simp [originalAfterChange, hk]⟩

/-- Every service a change does not keep stays in the changed item, cancelled
and removed. -/
@[checks "ONE-204.3"]
theorem change_cancels_others (o o' : Order) (c : ItemChange) (h : changeItem o c = .ok o')
    (old : OrderItem) (hold : o.items.find? (·.id = c.item) = some old)
    (s : Service) (hs : s ∈ old.services) (hk : s.id ∉ c.kept) :
    ∃ i ∈ o'.items, i.id = c.item ∧
      { s with status := .cancelled, delivery := .removed } ∈ i.services := by
  obtain ⟨old', hold', -, rfl⟩ := changeItem_ok o o' c h
  rw [hold] at hold'
  cases hold'
  have hid : old.id = c.item := by simpa using List.find?_some hold
  refine ⟨afterChange c old, ?_, by simp [afterChange, hid], ?_⟩
  · simp only [List.mem_append, List.mem_map]
    exact Or.inl ⟨old, List.mem_of_find?_eq_some hold, rfl⟩
  · simp only [afterChange, hid, ↓reduceIte, List.mem_map]
    exact ⟨s, hs, by simp [originalAfterChange, hk]⟩

/-- A change keeps the order's item references distinct: the changed item
keeps its reference, and the new item's reference is not already used. -/
@[checks "ONE-204.4"]
theorem change_item_refs_unique (o o' : Order) (c : ItemChange) (h : changeItem o c = .ok o')
    (hids : (o.items.map (·.id)).Nodup) :
    (o'.items.map (·.id)).Nodup := by
  obtain ⟨old, -, hnew, rfl⟩ := changeItem_ok o o' c h
  have hmap : (o.items.map (afterChange c)).map (·.id) = o.items.map (·.id) := by
    simp only [List.map_map]
    congr 1
    funext i
    simp only [Function.comp_apply, afterChange]
    split_ifs <;> rfl
  simp only [List.map_append, hmap, List.map_cons, List.map_nil]
  rw [List.nodup_append]
  refine ⟨hids, List.nodup_singleton _, ?_⟩
  intro a ha b hb
  simp only [List.mem_singleton] at hb
  subst hb
  simp only [List.mem_map] at ha
  obtain ⟨i, hi, rfl⟩ := ha
  simp only [List.all_eq_true, decide_eq_true_eq] at hnew
  exact hnew i hi

/-- After a change, the changed item is cancelled, under every reading of the
guide.

Open question for the business.  The worked examples leave the transferred
copies in the changed item READY TO PROCEED and show the item CANCELLED.  The
guide's item status rule judges value by delivery status alone, and a service
READY TO PROCEED holds value under every reading, so the changed item stays
active and the kept service holds value in both items.  The example
{lit}`changeKeepingOutbound` shows it.  Does the TRANSFERRED status take away a
service's value, or should the original copy move to a delivery status that
holds none? -/
@[open_question, checks "ONE-204.5"]
theorem change_original_cancelled (v : ValueReading) (o o' : Order) (c : ItemChange)
    (h : changeItem o c = .ok o') (i : OrderItem) (hi : i ∈ o'.items) (hid : i.id = c.item) :
    itemStatuses v i = [.cancelled] := by
  sorry

/-! ## Order balance -/

/-- Settling an offer adds the amount due to the airline to the payments and
the amount due by the airline to the refunds. -/
@[checks "ONE-205.1"]
theorem settle_adds_payments (l : Ledger) (d : PriceDifferential) :
    (settle l d).paid = l.paid + d.dueToAirline.amount ∧
      (settle l d).refunded = l.refunded + d.dueByAirline.amount :=
  ⟨rfl, rfl⟩

/-- Settling an offer adds its penalty and forfeited amount to those recorded,
and never lowers an amount recorded before. -/
@[checks "ONE-205.2"]
theorem settle_records_penalty (l : Ledger) (d : PriceDifferential) :
    (settle l d).penalties = l.penalties + d.penalty.amount ∧
      (settle l d).forfeited = l.forfeited + d.forfeited.amount ∧
      l.paid ≤ (settle l d).paid ∧ l.refunded ≤ (settle l d).refunded ∧
      l.penalties ≤ (settle l d).penalties ∧ l.forfeited ≤ (settle l d).forfeited := by
  simp [settle]

/-- A balanced order stays balanced when a paid change of one of its items is
made and its price differential settled, under every reading of the guide.

Open question for the business.  After a change that keeps a service, the
original item still holds value (see ONE-204.5), so its price still counts as
live next to the new item's price.  The example {lit}`changeBalance` shows it:
a 1,000.00 trip changed to a 900.00 trip keeping the outbound flight, with a
40.00 penalty and 120.00 forfeited, leaves 1,060.00 paid against 1,900.00 of
live items plus 160.00 recorded.  The same change with nothing kept balances.
A request to keep value for later use, or a waived penalty above the
refundable value, breaks it too, for the reasons given under ONE-201.5.
Should the original item stop counting once the change is paid, and how does
a change accepted but not yet paid enter the balance? -/
@[open_question, checks "ONE-205.3"]
theorem change_keeps_balance (v : ValueReading) (r : ExcessPenalty) (o o' : Order)
    (c : ItemChange) (old : OrderItem) (q : ChangeQuote) (d : PriceDifferential) (l : Ledger)
    (hbal : l.Balanced v o) (hold : o.items.find? (·.id = c.item) = some old)
    (hc : changeItem o c = .ok o') (hprices : q.oldPrice = old.price ∧ q.newPrice = c.newPrice)
    (hd : priceDifferential r q = .ok d) :
    (settle l d).Balanced v o' := by
  sorry

end Rules.OneOrder.Change
