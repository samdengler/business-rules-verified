import Verify.Rust.OfferOrderRules
import Rules.OfferOrder.Order
import Rules.OfferOrder.Payment

/-!
# The Rust implementation computes what the model computes

`Verify/Rust/OfferOrderRules.lean` is generated: Charon and Aeneas translate
`impl/rust/src/lib.rs` into Lean, one Lean function per Rust function, with
Rust's integers modelled exactly (a `u64` is a `Std.U64`, at most 2^64 - 1)
and every function returning a `Result` that would record a panic.

The theorems below say that, for every input, each translated Rust function
returns without failing and gives the answer the model's function gives.
The Rust types are mapped to the model's types first.  Each mapping is a
one-to-one correspondence, so no two Rust values stand for the same model
value.
-/

open Aeneas Aeneas.Std Result

namespace Verify

/-! ## Delivering, cancelling and refunding a service (OO-002) -/

/-- The model's delivery state for a Rust delivery state. -/
def stateOf : offer_order_rules.DeliveryState → Rules.OfferOrder.DeliveryState
  | .Ready => .ready
  | .Delivered => .delivered
  | .Cancelled => .cancelled
  | .Refunded => .refunded

/-- The model's delivery event for a Rust delivery event. -/
def eventOf : offer_order_rules.DeliveryEvent → Rules.OfferOrder.DeliveryEvent
  | .Deliver => .deliver
  | .Cancel => .cancel
  | .Refund => .refund

theorem stateOf_bijective : Function.Bijective stateOf := by
  constructor
  · intro a b h; cases a <;> cases b <;> first | rfl | cases h
  · intro s; cases s
    exacts [⟨.Ready, rfl⟩, ⟨.Delivered, rfl⟩, ⟨.Cancelled, rfl⟩, ⟨.Refunded, rfl⟩]

theorem eventOf_bijective : Function.Bijective eventOf := by
  constructor
  · intro a b h; cases a <;> cases b <;> first | rfl | cases h
  · intro e; cases e
    exacts [⟨.Deliver, rfl⟩, ⟨.Cancel, rfl⟩, ⟨.Refund, rfl⟩]

/-- For every state and event, the Rust `step` returns without failing, and
its answer is the model's `step` answer. -/
theorem step_matches_model (s : offer_order_rules.DeliveryState) (e : offer_order_rules.DeliveryEvent) :
    ∃ o, offer_order_rules.step s e = ok o ∧
      o.map stateOf = Rules.OfferOrder.step (stateOf s) (eventOf e) := by
  cases s <;> cases e <;> simp [offer_order_rules.step, Rules.OfferOrder.step, stateOf, eventOf]

/-! ## Accepting a refund (OO-003) -/

/-- The model's currency for a Rust currency. -/
def currencyOf : offer_order_rules.Currency → Rules.Core.Currency
  | .Usd => .USD
  | .Eur => .EUR
  | .Gbp => .GBP

/-- The model's money for Rust money: the same amount and currency. -/
def moneyOf (m : offer_order_rules.Money) : Rules.Core.Money :=
  ⟨m.amount.val, currencyOf m.currency⟩

/-- The model's payment for a Rust payment.  Rust references are numbers and
the model's are strings; `label` turns one into the other. -/
def paymentOf (label : U64 → String) (p : offer_order_rules.Payment) : Rules.OfferOrder.Payment :=
  ⟨label p.id, label p.order, moneyOf p.amount⟩

/-- The model's refund for a Rust refund, naming references with `label`. -/
def refundOf (label : U64 → String) (r : offer_order_rules.Refund) : Rules.OfferOrder.Refund :=
  ⟨label r.id, label r.payment, moneyOf r.amount⟩

/-- For every payment and refund, the Rust `accept_refund` returns without
failing and gives the model's answer, whatever names the references are
given, as long as different numbers get different names. -/
theorem accept_refund_matches_model (label : U64 → String) (hlabel : Function.Injective label)
    (p : offer_order_rules.Payment) (r : offer_order_rules.Refund) :
    offer_order_rules.accept_refund p r =
      ok (Rules.OfferOrder.acceptRefund (paymentOf label p) (refundOf label r)) := by
  unfold offer_order_rules.accept_refund Rules.OfferOrder.acceptRefund paymentOf refundOf moneyOf
  by_cases h : r.payment = p.id
  · simp [h]
  · have : label r.payment ≠ label p.id := fun e => h (hlabel e)
    simp [h, this]

end Verify
