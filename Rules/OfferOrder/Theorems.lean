import Rules.OfferOrder.Accept
import Rules.OfferOrder.Payment

/-!
# Guarantees

Properties the rules are claimed to have.  A theorem that closes is a
guarantee; a theorem left open is a question for the business.
-/

namespace Rules.OfferOrder

open Rules.Core

/-- When an offer is accepted, the order's price is exactly the sum of the
offer's item prices: nothing is added or dropped. -/
theorem accept_price_eq_sum (o : Offer) (now : Instant) (orderId : String) (ord : Order)
    (h : accept o now orderId = .ok ord) :
    ord.price.amount = (o.items.map (·.price.amount)).sum := by
  unfold accept at h
  split_ifs at h
  cases h
  rfl

/-- An offer accepted at or after its expiry instant is always rejected as
expired. -/
theorem accept_rejects_expired (o : Offer) (now : Instant) (orderId : String)
    (h : now ≥ o.expiresAt) :
    accept o now orderId = .error .expired := by
  simp [accept, h]

/-- A delivered service can never be cancelled: the cancel event is refused in
the delivered state, and no event moves a delivered service to cancelled. -/
theorem delivered_not_cancellable :
    step .delivered .cancel = none ∧ ∀ e, step .delivered e ≠ some .cancelled := by
  refine ⟨rfl, ?_⟩
  intro e
  cases e <;> simp [step]

/-- Refunds against an order never exceed what was paid for it, provided each
refund was accepted against one of the order's payments.

Open question for the Offer/Order team.  This does not hold as the rule is
written: `acceptRefund` checks each refund against its payment alone, so two
refunds of 60 against one payment of 100 are each accepted and together
return 120.  The counterexample is the `doubleRefund` case.  Does the rule
mean the limit applies per refund, cumulatively per payment, or cumulatively
per order?  And is a refund above the amount paid ever allowed, for example
as a goodwill credit? -/
theorem refunds_le_payments (ps : List Payment) (rs : List Refund) (orderId : String)
    (hids : (ps.map (·.id)).Nodup)
    (hacc : ∀ r ∈ rs, ∃ p ∈ ps, acceptRefund p r = true) :
    totalRefunded ps rs orderId ≤ totalPaid ps orderId := by
  sorry

end Rules.OfferOrder
