import Rules.Core.Attributes
import Rules.OneOrder.Payment.Accept
import Rules.OneOrder.Change.Theorems
import Rules.OneOrder.Offers.TimeLimits
import Rules.OneOrder.Offers.Price
import Rules.OneOrder.Offers.Restrictions

/-!
# Guarantees about offers, prices and conditions

Properties the ONE Order rules for offers, prices and conditions are claimed to
have.  A guarantee that depends on a reading of the guide holds for every
reading; one left open is a question for the business.
-/

namespace Rules.OneOrder.Offers

open Rules.Core

/-! ## Guarantees on an offer -/

/-- An offer item that carries no price guarantee time limit has no guaranteed
price at any instant, under every reading of the guide. -/
@[checks "ONE-501.1"]
theorem no_limit_no_guarantee (b : GuaranteeEnd) (o : TimedOffer) (oi : TimedOfferItem)
    (now : Instant) (h : oi.limits.priceGuarantee = none) :
    (guaranteesAt b o oi now).price = false := by
  simp [guaranteesAt, TimedOffer.holds, h]

/-- A guarantee limit holds at every instant before both the limit and the
offer's expiry, under every reading of the guide. -/
theorem holds_before (b : GuaranteeEnd) (o : TimedOffer) (t now : Instant)
    (h1 : now < t) (h2 : now < o.expiresAt) : o.holds b (some t) now = true := by
  cases b
  · simp [TimedOffer.holds, GuaranteeEnd.within, h1, h2]
  · simp [TimedOffer.holds, GuaranteeEnd.within, le_of_lt h1, le_of_lt h2]

/-- An offer item's price is guaranteed at every instant before both its price
guarantee time limit and the offer's expiry, under every reading of the
guide. -/
@[checks "ONE-501.2"]
theorem price_guaranteed_before (b : GuaranteeEnd) (o : TimedOffer) (oi : TimedOfferItem)
    (now t : Instant) (ht : oi.limits.priceGuarantee = some t) (h1 : now < t)
    (h2 : now < o.expiresAt) : (guaranteesAt b o oi now).price = true := by
  simpa [guaranteesAt, ht] using holds_before b o t now h1 h2

/-- An offer item's inventory is guaranteed at every instant before both its
inventory guarantee time limit and the offer's expiry, under every reading of
the guide. -/
@[checks "ONE-501.3"]
theorem inventory_guaranteed_before (b : GuaranteeEnd) (o : TimedOffer) (oi : TimedOfferItem)
    (now t : Instant) (ht : oi.limits.inventoryGuarantee = some t) (h1 : now < t)
    (h2 : now < o.expiresAt) : (guaranteesAt b o oi now).inventory = true := by
  simpa [guaranteesAt, ht] using holds_before b o t now h1 h2

/-- A guarantee limit that holds at an instant holds no later than the offer's
expiry. -/
theorem holds_le_expiry (b : GuaranteeEnd) (o : TimedOffer) (l : Option Instant) (now : Instant)
    (h : o.holds b l now = true) : now ≤ o.expiresAt := by
  cases l with
  | none => simp [TimedOffer.holds] at h
  | some t =>
    cases b
    · simp only [TimedOffer.holds, Option.any_some, GuaranteeEnd.within, decide_eq_true_eq] at h
      exact le_of_lt (lt_of_lt_of_le h (min_le_right _ _))
    · simp only [TimedOffer.holds, Option.any_some, GuaranteeEnd.within, decide_eq_true_eq] at h
      exact le_trans h (min_le_right _ _)

/-- Every price and inventory guarantee of an offer ends no later than the
offer's expiry, under every reading of the guide, whatever the item's own
limits say. -/
@[checks "ONE-501.4"]
theorem guarantees_end_by_expiry (b : GuaranteeEnd) (o : TimedOffer) (oi : TimedOfferItem)
    (now : Instant)
    (h : (guaranteesAt b o oi now).price = true ∨ (guaranteesAt b o oi now).inventory = true) :
    now ≤ o.expiresAt := by
  rcases h with h | h
  · exact holds_le_expiry b o _ now h
  · exact holds_le_expiry b o _ now h

/-- Under the reading that a guarantee ends at its instant, an offer item's
price is guaranteed only at instants at which the offer can still be
accepted. -/
theorem guaranteed_while_acceptable_of_exclusive (o : TimedOffer) (oi : TimedOfferItem)
    (now : Instant) (orderId : String) (h : (guaranteesAt .exclusive o oi now).price = true) :
    accept o.toOffer now orderId ≠ .error .expired := by
  have hlt : now < o.expiresAt := by
    simp only [guaranteesAt, TimedOffer.holds, Option.any_eq_true, GuaranteeEnd.within,
      decide_eq_true_eq] at h
    obtain ⟨t, -, ht⟩ := h
    exact lt_of_lt_of_le ht (min_le_right _ _)
  have hnot : ¬ now ≥ o.toOffer.expiresAt := not_le.mpr hlt
  unfold accept
  split_ifs <;> simp

/-- An offer item's price is guaranteed only at instants at which the offer can
still be accepted.

Open question for the business.  The guide says a price is guaranteed until its
time limit and does not say whether the limit's own instant is inside.  An
offer is rejected as expired at its expiry instant.  Under the reading that a
guarantee still holds at its instant, an item whose price guarantee ends at
the same instant as the offer has a guaranteed price at an instant when the
offer can no longer be accepted.  The example {lit}`guaranteeAtExpiry` shows
it.  Does a price guarantee still hold at the instant its time limit
names? -/
@[open_question, checks "ONE-501.5"]
theorem guaranteed_while_acceptable (b : GuaranteeEnd) (o : TimedOffer) (oi : TimedOfferItem)
    (now : Instant) (orderId : String) (h : (guaranteesAt b o oi now).price = true) :
    accept o.toOffer now orderId ≠ .error .expired := by
  sorry

/-! ## Time limits of a new order -/

/-- An order created from a timed offer has one order item for each offer item,
each made as {name}`newItem` makes it, and was created at the instant of
acceptance. -/
theorem createOrder_ok (r : CreationReading) (o : TimedOffer) (now : Instant) (orderId : String)
    (n : NewOrder) (h : createOrder r o now orderId = .ok n) :
    n = { id := orderId, items := o.items.map (newItem r orderId now), createdAt := now } := by
  unfold createOrder at h
  split at h
  · cases h
  · split_ifs at h
    cases h
    rfl

/-- An order created from a timed offer, without its time limits, is the order
ONE-001 creates from the offer, so every guarantee of ONE-001 holds for it. -/
theorem createOrder_toOrder (r : CreationReading) (o : TimedOffer) (now : Instant)
    (orderId : String) (n : NewOrder) (h : createOrder r o now orderId = .ok n) :
    accept o.toOffer now orderId = .ok n.toOrder := by
  have hn := createOrder_ok r o now orderId n h
  unfold createOrder at h
  split at h
  · cases h
  · rename_i ord hacc
    rw [hacc]
    unfold accept at hacc
    split_ifs at hacc
    cases hacc
    subst hn
    simp [NewOrder.toOrder, TimedOffer.toOffer, newItem, Function.comp_def]

/-- An order item created from an offer item whose payment time limit is stated
only as a duration must be paid by the creation instant plus that duration. -/
@[checks "ONE-502.1"]
theorem createOrder_duration (r : CreationReading) (o : TimedOffer) (now : Instant)
    (orderId : String) (n : NewOrder) (h : createOrder r o now orderId = .ok n)
    (oi : TimedOfferItem) (hoi : oi ∈ o.items) (d : Nat) (hd : oi.limits.payWithin = some d)
    (hb : oi.limits.payBy = none) :
    ∃ ni ∈ n.items, ni.item.fromOfferItem = oi.item.id ∧
      ni.paymentBy = some (secondsAfter n.createdAt d) := by
  have hn := createOrder_ok r o now orderId n h
  subst hn
  exact ⟨newItem r orderId now oi, List.mem_map_of_mem hoi, rfl,
    by simp [newItem, paymentLimitAt, hd, hb]⟩

/-- An order item created from an offer item whose payment time limit is stated
only as a fixed date and time must be paid by that instant. -/
@[checks "ONE-502.2"]
theorem createOrder_fixed (r : CreationReading) (o : TimedOffer) (now : Instant)
    (orderId : String) (n : NewOrder) (h : createOrder r o now orderId = .ok n)
    (oi : TimedOfferItem) (hoi : oi ∈ o.items) (t : Instant) (hd : oi.limits.payWithin = none)
    (hb : oi.limits.payBy = some t) :
    ∃ ni ∈ n.items, ni.item.fromOfferItem = oi.item.id ∧ ni.paymentBy = some t := by
  have hn := createOrder_ok r o now orderId n h
  subst hn
  exact ⟨newItem r orderId now oi, List.mem_map_of_mem hoi, rfl,
    by simp [newItem, paymentLimitAt, hd, hb]⟩

/-- Each order item keeps the price guarantee time limit of its offer item, in
the order of the offer's items. -/
@[checks "ONE-502.3"]
theorem createOrder_keeps_guarantee (r : CreationReading) (o : TimedOffer) (now : Instant)
    (orderId : String) (n : NewOrder) (h : createOrder r o now orderId = .ok n) :
    n.items.map (·.priceGuarantee) = o.items.map (·.limits.priceGuarantee) := by
  have hn := createOrder_ok r o now orderId n h
  subst hn
  simp [newItem, Function.comp_def]

/-- Under the reading that asks for a new offer, no order is created while the
price guarantee of one of the offer's items has lapsed. -/
theorem createOrder_guaranteed_of_reprice (r : CreationReading) (hr : r.lapsedPrice = .reprice)
    (o : TimedOffer) (now : Instant) (orderId : String) (n : NewOrder)
    (h : createOrder r o now orderId = .ok n) :
    ∀ oi ∈ o.items, o.guaranteeLapsed r.guaranteeEnd oi now = false := by
  unfold createOrder at h
  split at h
  · cases h
  · split_ifs at h with hc
    simp only [hr, true_and, List.any_eq_true, not_exists, not_and] at hc
    intro oi hoi
    simpa using hc oi hoi

/-- No order is created at the offered price while the price guarantee of one
of the offer's items has lapsed.

Open question for the business.  The guide recommends repricing into a new
offer when a price guarantee has lapsed, and does not say what the airline
must do when the customer accepts the offer before it expires.  Under the
reading that creates the order at the offered price, an offer whose
30 minute price guarantee lapsed is accepted at the offered price one minute
before the offer expires.  The example {lit}`lapsedGuaranteeAccepted` shows
it.  Is acceptance in this window refused, sent back for a new offer, or
honoured at the offered price? -/
@[open_question, checks "ONE-502.4"]
theorem createOrder_price_guaranteed (r : CreationReading) (o : TimedOffer) (now : Instant)
    (orderId : String) (n : NewOrder) (h : createOrder r o now orderId = .ok n) :
    ∀ oi ∈ o.items, o.guaranteeLapsed r.guaranteeEnd oi now = false := by
  sorry

/-- No order item starts with a payment time limit before the order's
creation.

Open question for the business.  An offer item may state its payment time limit
as a fixed date and time, and the guide does not say what happens when that
instant has passed by the time the order is created.  The rule copies the
instant, so the order item is overdue the moment it exists.  The example
{lit}`fixedLimitBeforeCreation` shows it.  Is such an acceptance refused, or
does the order item get a new payment time limit? -/
@[open_question, checks "ONE-502.5"]
theorem createOrder_limit_not_before_creation (r : CreationReading) (o : TimedOffer)
    (now : Instant) (orderId : String) (n : NewOrder) (h : createOrder r o now orderId = .ok n) :
    ∀ ni ∈ n.items, ∀ t, ni.paymentBy = some t → n.createdAt ≤ t := by
  sorry

/-- An order item whose offer item's payment time limit is a duration of zero
can be paid at the instant the order is created.

Open question for the business.  The guide says a payment time limit of zero
means payment is due at order creation.  The rule sets the order item's limit
to the creation instant, and the payment rule of ONE-304 rejects a payment
made at or after the limit, so no payment for the item is ever on time.  The
example {lit}`zeroDurationPayment` shows it.  Is a payment made at the
creation instant on time, or must it come with the request that creates the
order? -/
@[open_question, checks "ONE-502.6"]
theorem zero_duration_payable (r : CreationReading) (o : TimedOffer) (now : Instant)
    (orderId : String) (n : NewOrder) (h : createOrder r o now orderId = .ok n)
    (hz : ∀ oi ∈ o.items, oi.limits.payWithin = some 0 ∧ oi.limits.payBy = none)
    (p : Payment.Transaction) :
    Payment.acceptPayment n.payable p n.createdAt ≠ .error .timeLimitPassed := by
  sorry

/-! ## The rule in force -/

/-- An empty list is the only one with no latest rule. -/
theorem latestOf_eq_none : ∀ l : List Restriction, latestOf l = none → l = []
  | [], _ => rfl
  | x :: xs, h => by
    simp only [latestOf] at h
    split at h
    · cases h
    · split_ifs at h

/-- The latest rule of a list is one of its rules. -/
theorem latestOf_mem : ∀ (l : List Restriction) (r : Restriction), latestOf l = some r → r ∈ l
  | [], r, h => by simp [latestOf] at h
  | x :: xs, r, h => by
    simp only [latestOf] at h
    split at h
    · cases h
      exact List.mem_cons_self
    · rename_i r' hr'
      split_ifs at h
      · cases h
        exact List.mem_cons_of_mem _ (latestOf_mem xs _ hr')
      · cases h
        exact List.mem_cons_self

/-- No rule of a list starts later than its latest rule. -/
theorem latestOf_max : ∀ (l : List Restriction) (r : Restriction), latestOf l = some r →
    ∀ r' ∈ l, r'.effective ≤ r.effective
  | [], r, h => by simp [latestOf] at h
  | x :: xs, r, h => by
    intro r' hr'
    simp only [latestOf] at h
    split at h
    · rename_i hnone
      cases h
      have hxs := latestOf_eq_none xs hnone
      subst hxs
      simp only [List.mem_singleton] at hr'
      rw [hr']
    · rename_i m hm
      have ih := latestOf_max xs m hm
      split_ifs at h with hlt
      · cases h
        rcases List.mem_cons.mp hr' with rfl | h'
        · exact le_of_lt hlt
        · exact ih r' h'
      · cases h
        rcases List.mem_cons.mp hr' with rfl | h'
        · exact le_rfl
        · exact le_trans (ih r' h') (not_lt.mp hlt)

/-- The rule in force for an action at an instant is one of the rules for that
action and for the stage the journey is in at that instant. -/
@[checks "ONE-503.1"]
theorem ruleInForce_stage (e : ExpiryReading) (rules : List Restriction) (j : Journey)
    (a : Action) (now : Instant) (r : Restriction) (h : ruleInForce e rules j a now = some r) :
    r ∈ rules ∧ r.action = a ∧ r.stage = j.stageAt now := by
  have hm := latestOf_mem _ r h
  simp only [candidates, List.mem_filter, Bool.and_eq_true, decide_eq_true_eq] at hm
  exact ⟨hm.1, hm.2.1.1, hm.2.1.2⟩

/-- The rule in force at an instant has started by that instant. -/
@[checks "ONE-503.2"]
theorem ruleInForce_started (e : ExpiryReading) (rules : List Restriction) (j : Journey)
    (a : Action) (now : Instant) (r : Restriction) (h : ruleInForce e rules j a now = some r) :
    r.effective ≤ now := by
  have hm := latestOf_mem _ r h
  simp only [candidates, List.mem_filter, Bool.and_eq_true, decide_eq_true_eq,
    Restriction.live] at hm
  exact hm.2.2.1

/-- When at least one rule for an action and the current stage is live (it has
started and, under the reading that expiration dates end rules, has not
expired), a rule is in force.  It is one of those live rules, and none of them
starts later than it. -/
@[checks "ONE-503.3"]
theorem ruleInForce_latest (e : ExpiryReading) (rules : List Restriction) (j : Journey)
    (a : Action) (now : Instant)
    (h : ∃ r' ∈ rules, r'.action = a ∧ r'.stage = j.stageAt now ∧ r'.live e now = true) :
    ∃ r, ruleInForce e rules j a now = some r ∧ r.live e now = true ∧
      ∀ r' ∈ rules, r'.action = a → r'.stage = j.stageAt now → r'.live e now = true →
        r'.effective ≤ r.effective := by
  obtain ⟨r', hr', ha, hs, hl⟩ := h
  have hmem : r' ∈ candidates e rules j a now := by
    simp [candidates, hr', ha, hs, hl]
  cases hlat : ruleInForce e rules j a now with
  | none =>
    have := latestOf_eq_none _ hlat
    rw [this] at hmem
    simp at hmem
  | some r =>
    have hrm := latestOf_mem _ r hlat
    simp only [candidates, List.mem_filter, Bool.and_eq_true] at hrm
    refine ⟨r, rfl, hrm.2.2, fun r'' hr'' ha'' hs'' hl'' => latestOf_max _ r hlat r'' ?_⟩
    simp [candidates, hr'', ha'', hs'', hl'']

/-- Under the reading that expiration dates end rules, the rule in force at an
instant has not reached its expiration date. -/
@[checks "ONE-503.4"]
theorem ruleInForce_not_expired (rules : List Restriction) (j : Journey) (a : Action)
    (now : Instant) (r : Restriction) (h : ruleInForce .ends rules j a now = some r) :
    ∀ t, r.expires = some t → now < t := by
  intro t ht
  have hm := latestOf_mem _ r h
  simp only [candidates, List.mem_filter, Bool.and_eq_true, decide_eq_true_eq,
    Restriction.live, ht, Option.all_some] at hm
  exact hm.2.2.2

/-- While a journey is in a stage for which an action has rules, a rule is in
force for that action.

Open question for the business.  A rule starts at its effective date, and the
guide does not say what applies in a stage before its first rule starts, or,
when expiration dates end rules, in a gap before the next rule starts.  A
journey paid before its first rule for the stage before departure starts has
no rule in force, under both readings; under the reading that expiration dates
end rules, a rule whose effective and expiration dates are equal is never in
force.  The example {lit}`noRuleInForce` shows both.  What applies to a change
or cancellation when no rule of the stage is in force? -/
@[open_question, checks "ONE-503.5"]
theorem ruleInForce_covers_stage (e : ExpiryReading) (rules : List Restriction) (j : Journey)
    (a : Action) (now : Instant)
    (h : ∃ r ∈ rules, r.action = a ∧ r.stage = j.stageAt now) :
    (ruleInForce e rules j a now).isSome := by
  sorry

/-! ## Voluntary changes -/

/-- A change the rule in force forbids is refused. -/
@[checks "ONE-504.1"]
theorem change_refused (e : ExpiryReading) (rules : List Restriction) (j : Journey)
    (req : ChangeRequest) (r : Restriction)
    (h : ruleInForce e rules j (.change req.kind) req.requestedAt = some r)
    (hr : r.allowed = false) :
    voluntaryChange e rules j req = .refused := by
  simp [voluntaryChange, h, hr]

/-- A change the rule in force allows with a fee is quoted with that fee as its
penalty. -/
@[checks "ONE-504.2"]
theorem change_fee_is_penalty (e : ExpiryReading) (rules : List Restriction) (j : Journey)
    (req : ChangeRequest) (r : Restriction)
    (h : ruleInForce e rules j (.change req.kind) req.requestedAt = some r)
    (hr : r.allowed = true) (f : Money) (hf : r.fee = some f) :
    ∃ q ap, voluntaryChange e rules j req = .allowed q ap ∧ q.penalty = f := by
  simp only [voluntaryChange, h, hr, ite_true]
  exact ⟨_, _, rfl, by simp [Restriction.feeOr, hf]⟩

/-- A change the rule in force allows without a fee is quoted with no
penalty. -/
@[checks "ONE-504.3"]
theorem change_no_fee (e : ExpiryReading) (rules : List Restriction) (j : Journey)
    (req : ChangeRequest) (r : Restriction)
    (h : ruleInForce e rules j (.change req.kind) req.requestedAt = some r)
    (hr : r.allowed = true) (hf : r.fee = none) :
    ∃ q ap, voluntaryChange e rules j req = .allowed q ap ∧ q.penalty.amount = 0 := by
  simp only [voluntaryChange, h, hr, ite_true]
  exact ⟨_, _, rfl, by simp [Restriction.feeOr, hf]⟩

/-- A change the rule in force allows, with a fee no larger than the price of
the items changed and no request to keep the value for later use, is priced so
that the customer owes the fee plus the fare difference, net of what the
airline returns.  This holds under both readings of what happens to a penalty
above the refundable value, and whether the fee is netted or charged
separately. -/
@[checks "ONE-504.4"]
theorem change_net_is_fee_plus_difference (e : ExpiryReading) (rules : List Restriction)
    (j : Journey) (req : ChangeRequest) (q : Change.ChangeQuote) (ap : Bool)
    (h : voluntaryChange e rules j req = .allowed q ap)
    (hfee : q.penalty.amount ≤ req.oldPrice.amount) (hs : req.settlement ≠ .respend)
    (x : Change.ExcessPenalty) (d : Change.PriceDifferential)
    (hd : Change.priceDifferential x q = .ok d) :
    (d.dueToAirline.amount : Int) - d.dueByAirline.amount =
      (req.newPrice.amount : Int) - req.oldPrice.amount + q.penalty.amount := by
  obtain ⟨h1, h2, -⟩ := Change.priceDifferential_ok x q d hd
  rw [h1, h2]
  unfold voluntaryChange at h
  split at h
  · cases h
  · split_ifs at h
    cases h
    simp only at hfee
    cases x <;> cases req.handling <;>
      simp only [Change.statedDue, hs, ite_false, Change.dueAmounts,
        Change.ExcessPenalty.charged, Change.ChangeQuote.refundable,
        Change.ChangeQuote.difference] <;>
      omega

/-! ## Voluntary cancellations -/

/-- A cancellation the rule in force forbids returns nothing. -/
@[checks "ONE-505.1"]
theorem cancel_forbidden_nothing (e : ExpiryReading) (ff : FullOrFixed)
    (rules : List Restriction) (j : Journey) (now : Instant) (item : CancelledItem)
    (r : Restriction) (h : ruleInForce e rules j .cancel now = some r) (hr : r.allowed = false) :
    ∃ o, cancellationRefund e ff rules j now item = .refund ⟨0, item.price.currency⟩ o := by
  exact ⟨false, by simp [cancellationRefund, h, hr]⟩

/-- A cancellation the rule in force allows with a full refund and no fixed
amount returns the item's whole price. -/
@[checks "ONE-505.2"]
theorem cancel_full_refund (e : ExpiryReading) (ff : FullOrFixed) (rules : List Restriction)
    (j : Journey) (now : Instant) (item : CancelledItem) (r : Restriction)
    (h : ruleInForce e rules j .cancel now = some r) (hr : r.allowed = true)
    (hf : r.refund = .full) :
    ∃ o, cancellationRefund e ff rules j now item = .refund item.price o := by
  exact ⟨r.toOriginalForm, by simp [cancellationRefund, h, hr, hf, RefundTerms.amount]⟩

/-- A cancellation the rule in force allows with a fixed refund not marked full
returns that amount. -/
@[checks "ONE-505.3"]
theorem cancel_fixed_refund (e : ExpiryReading) (ff : FullOrFixed) (rules : List Restriction)
    (j : Journey) (now : Instant) (item : CancelledItem) (r : Restriction)
    (h : ruleInForce e rules j .cancel now = some r) (hr : r.allowed = true) (m : Money)
    (hf : r.refund = .fixed m) :
    ∃ o, cancellationRefund e ff rules j now item = .refund m o := by
  exact ⟨r.toOriginalForm, by simp [cancellationRefund, h, hr, hf, RefundTerms.amount]⟩

/-- A cancellation the rule in force allows, with the refund sent to the
original form of payment, is refunded to the original form of payment. -/
@[checks "ONE-505.4"]
theorem cancel_to_original_form (e : ExpiryReading) (ff : FullOrFixed)
    (rules : List Restriction) (j : Journey) (now : Instant) (item : CancelledItem)
    (r : Restriction) (h : ruleInForce e rules j .cancel now = some r) (hr : r.allowed = true)
    (ho : r.toOriginalForm = true) :
    ∃ m, cancellationRefund e ff rules j now item = .refund m true := by
  simp only [cancellationRefund, h, hr, ho, ite_true]
  exact ⟨_, rfl⟩

/-- A voluntary cancellation of an unused item returns at least the taxes, fees
and charges in its price that are flagged refundable.

Open question for the business.  The guide gives each tax, fee and charge its
own refund flag and gives each offer item cancel rules, and never says how the
two combine.  The rule returns what the cancel rule gives, so a rule that
forbids cancellation returns nothing, and a fixed refund can be less than the
refundable taxes.  The examples {lit}`nonRefundableFareTaxes` and
{lit}`fullMarkedWithAmount` show both.  Does a cancel rule that returns
nothing also keep the taxes flagged refundable, and does a no show change the
answer? -/
@[open_question, checks "ONE-505.5"]
theorem cancel_returns_refundable_charges (e : ExpiryReading) (ff : FullOrFixed)
    (rules : List Restriction) (j : Journey) (now : Instant) (item : CancelledItem) (m : Money)
    (o : Bool) (h : cancellationRefund e ff rules j now item = .refund m o) :
    item.refundableCharges ≤ m.amount := by
  sorry

/-! ## Price totals -/

/-- A price with an amount in a currency other than that of its amount before
discounts is rejected. -/
@[checks "ONE-506.1"]
theorem price_rejects_mixed_currency (x : ExcludedTax) (p : PriceParts)
    (h : ∃ m ∈ p.amounts, m.currency ≠ p.beforeDiscount.currency) :
    priceTotal x p = .error .mixedCurrency := by
  have hany : p.amounts.any (fun m => decide (m.currency ≠ p.beforeDiscount.currency)) = true := by
    obtain ⟨m, hm, hc⟩ := h
    exact List.any_eq_true.mpr ⟨m, hm, by simpa using hc⟩
  simp only [priceTotal, hany, ite_true]

/-- A price whose discount is larger than its amount before discounts is never
totalled. -/
@[checks "ONE-506.2"]
theorem price_rejects_large_discount (x : ExcludedTax) (p : PriceParts)
    (h : p.beforeDiscount.amount < p.discount.amount) :
    ∀ t, priceTotal x p ≠ .ok t := by
  intro t ht
  unfold priceTotal at ht
  split_ifs at ht

/-- A totalled price's base amount is its amount before discounts less its
discount, and the discount is no larger than that amount. -/
@[checks "ONE-506.3"]
theorem price_base (x : ExcludedTax) (p : PriceParts) (t : PriceTotal)
    (h : priceTotal x p = .ok t) :
    t.base.amount = p.beforeDiscount.amount - p.discount.amount ∧
      p.discount.amount ≤ p.beforeDiscount.amount := by
  unfold priceTotal at h
  split_ifs at h with h1 h2
  cases h
  exact ⟨rfl, not_lt.mp h2⟩

/-- A totalled price's tax summary total is the sum of its entries. -/
@[checks "ONE-506.4"]
theorem price_tax_total (x : ExcludedTax) (p : PriceParts) (t : PriceTotal)
    (h : priceTotal x p = .ok t) :
    t.taxTotal.amount = sumOf (p.taxes.map (·.amount)) := by
  unfold priceTotal at h
  split_ifs at h
  cases h
  rfl

/-- A totalled price's total is its base amount plus its surcharges, its fees,
its tax summary total and the consumption tax not included in it, all in the
price's currency. -/
@[checks "ONE-506.5"]
theorem price_total_from_parts (x : ExcludedTax) (p : PriceParts) (t : PriceTotal)
    (h : priceTotal x p = .ok t) :
    t.total.amount = t.base.amount + sumOf p.surcharges + sumOf (p.fees.map (·.amount)) +
        t.taxTotal.amount + t.excludedTax.amount ∧
      t.total.currency = p.beforeDiscount.currency := by
  unfold priceTotal at h
  split_ifs at h
  cases h
  exact ⟨rfl, rfl⟩

/-- Under the reading that takes the excluded consumption tax from the tax
lines, a totalled price adds the tax of every line marked as not included. -/
theorem price_adds_excluded_lines_of_lines (p : PriceParts) (t : PriceTotal)
    (h : priceTotal .lines p = .ok t) :
    t.excludedTax.amount = p.lineExcluded := by
  unfold priceTotal at h
  split_ifs at h
  cases h
  rfl

/-- A totalled price adds the tax of every consumption tax line marked as not
included in it.

Open question for the business.  The guide's examples state both the tax lines
and a total of excluded tax, and one example marks every HST line as not
included while stating an excluded total of zero.  Under the reading that
trusts the stated total, that tax is left out of the price's total.  The
example {lit}`excludedTaxReadings` shows the two readings differ by the whole
tax.  When a line marked as not included and the stated total of excluded tax
disagree, which one does the price's total follow? -/
@[open_question, checks "ONE-506.6"]
theorem price_adds_excluded_lines (x : ExcludedTax) (p : PriceParts) (t : PriceTotal)
    (h : priceTotal x p = .ok t) :
    t.excludedTax.amount = p.lineExcluded := by
  sorry

end Rules.OneOrder.Offers
