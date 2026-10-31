import Airline.Evaluate

/-!
# Verified Airline's fares as theorems

The facts {lit}`lake exe airline-facts` prints evaluate each fare at one journey
and one instant per stage.  Each fact about a change or a cancellation has a
theorem here that states it for every input in that stage: every journey and
every instant at which the journey is in the stage once the fare terms have
started, every item or change request, and every reading of the guide.  The
theorem {lit}`probes_in_stage` shows that the journey and instant the facts
evaluate are in their stage after the terms start, so each fact is its
theorem at that point.  The JSON the executable prints is not proved.

A fact's theorem is named after its place in the facts: the fact at
{lit}`fares.main.cancel.noShow` is {lit}`main_cancel_noShow`.
{lit}`lake exe airline-facts --theorems` lists them for Verified Airline's site,
with their lines in this file, and fails if a fact has none.

A theorem holds once the terms have started, since no rule is in force
before then.  The cancellation theorems cover every item, including one whose
price holds taxes flagged refundable; whether those come back is the model's
open criterion ONE-505.5.
-/

namespace Airline

open Rules.Core Rules.OneOrder.Offers

/-- The change a rule quotes for a request, as {name}`voluntaryChange` builds it:
the request's old and new prices, the fee as the penalty, and nothing
forfeited. -/
def quote (req : ChangeRequest) (fee : Money) : Rules.OneOrder.Change.ChangeQuote :=
  { oldPrice := req.oldPrice, newPrice := req.newPrice, penalty := fee,
    forfeited := ⟨0, req.oldPrice.currency⟩, handling := req.handling, settlement := req.settlement }

/-- The journey and instant at which the facts evaluate each stage after
payment are in that stage, after the fare terms start. -/
theorem probes_in_stage :
    ∀ p ∈ stages, (probe p.2).1.stageAt (probe p.2).2 = p.2 ∧ termsStart ≤ (probe p.2).2 := by
  decide

attribute [local simp] voluntaryChange cancellationRefund ruleInForce candidates Restriction.live
  latestOf Restriction.feeOr RefundTerms.amount quote term basicFare mainFare flexFare

variable (e : ExpiryReading) (ff : FullOrFixed) (j : Journey) (now : Instant)
  (item : CancelledItem) (req : ChangeRequest)

/-! ## Basic -/

/-- On Basic, a change of flight before departure is refused. -/
theorem basic_change_beforeDeparture (hk : req.kind = .flight)
    (hs : j.stageAt req.requestedAt = .beforeDeparture) (ht : termsStart ≤ req.requestedAt) :
    voluntaryChange e basicFare.rules j req = .refused := by
  cases e <;> simp [*]

/-- On Basic, a change of flight after the first flight is refused. -/
theorem basic_change_afterDeparture (hk : req.kind = .flight)
    (hs : j.stageAt req.requestedAt = .afterDeparture) (ht : termsStart ≤ req.requestedAt) :
    voluntaryChange e basicFare.rules j req = .refused := by
  cases e <;> simp [*]

/-- On Basic, a change of flight after a missed flight is refused. -/
theorem basic_change_noShow (hk : req.kind = .flight)
    (hs : j.stageAt req.requestedAt = .noShow) (ht : termsStart ≤ req.requestedAt) :
    voluntaryChange e basicFare.rules j req = .refused := by
  cases e <;> simp [*]

/-- On Basic, a cancellation before departure returns nothing. -/
theorem basic_cancel_beforeDeparture (hs : j.stageAt now = .beforeDeparture)
    (ht : termsStart ≤ now) :
    cancellationRefund e ff basicFare.rules j now item = .refund ⟨0, item.price.currency⟩ false := by
  cases e <;> simp [*]

/-- On Basic, a cancellation after the first flight returns nothing. -/
theorem basic_cancel_afterDeparture (hs : j.stageAt now = .afterDeparture)
    (ht : termsStart ≤ now) :
    cancellationRefund e ff basicFare.rules j now item = .refund ⟨0, item.price.currency⟩ false := by
  cases e <;> simp [*]

/-- On Basic, a cancellation after a missed flight returns nothing. -/
theorem basic_cancel_noShow (hs : j.stageAt now = .noShow) (ht : termsStart ≤ now) :
    cancellationRefund e ff basicFare.rules j now item = .refund ⟨0, item.price.currency⟩ false := by
  cases e <;> simp [*]

/-! ## Main -/

/-- On Main, a change of flight before departure is allowed with a 75 dollar
fee as its penalty, priced from the request's old and new prices. -/
theorem main_change_beforeDeparture (hk : req.kind = .flight)
    (hs : j.stageAt req.requestedAt = .beforeDeparture) (ht : termsStart ≤ req.requestedAt) :
    voluntaryChange e mainFare.rules j req = .allowed (quote req (usd 75)) false := by
  cases e <;> simp [*]

/-- On Main, a change of flight after the first flight is allowed with a 75
dollar fee as its penalty, priced from the request's old and new prices. -/
theorem main_change_afterDeparture (hk : req.kind = .flight)
    (hs : j.stageAt req.requestedAt = .afterDeparture) (ht : termsStart ≤ req.requestedAt) :
    voluntaryChange e mainFare.rules j req = .allowed (quote req (usd 75)) false := by
  cases e <;> simp [*]

/-- On Main, a change of flight after a missed flight is refused. -/
theorem main_change_noShow (hk : req.kind = .flight)
    (hs : j.stageAt req.requestedAt = .noShow) (ht : termsStart ≤ req.requestedAt) :
    voluntaryChange e mainFare.rules j req = .refused := by
  cases e <;> simp [*]

/-- On Main, a cancellation before departure returns 150 dollars to the
original form of payment, whatever the item's price. -/
theorem main_cancel_beforeDeparture (hs : j.stageAt now = .beforeDeparture)
    (ht : termsStart ≤ now) :
    cancellationRefund e ff mainFare.rules j now item = .refund (usd 150) true := by
  cases e <;> simp [*]

/-- On Main, a cancellation after the first flight returns 150 dollars to the
original form of payment, whatever the item's price. -/
theorem main_cancel_afterDeparture (hs : j.stageAt now = .afterDeparture)
    (ht : termsStart ≤ now) :
    cancellationRefund e ff mainFare.rules j now item = .refund (usd 150) true := by
  cases e <;> simp [*]

/-- On Main, a cancellation after a missed flight returns nothing. -/
theorem main_cancel_noShow (hs : j.stageAt now = .noShow) (ht : termsStart ≤ now) :
    cancellationRefund e ff mainFare.rules j now item = .refund ⟨0, item.price.currency⟩ false := by
  cases e <;> simp [*]

/-! ## Flex -/

/-- On Flex, a change of flight before departure is allowed with no fee,
priced from the request's old and new prices. -/
theorem flex_change_beforeDeparture (hk : req.kind = .flight)
    (hs : j.stageAt req.requestedAt = .beforeDeparture) (ht : termsStart ≤ req.requestedAt) :
    voluntaryChange e flexFare.rules j req = .allowed (quote req ⟨0, req.oldPrice.currency⟩) false := by
  cases e <;> simp [*]

/-- On Flex, a change of flight after the first flight is allowed with no fee,
priced from the request's old and new prices. -/
theorem flex_change_afterDeparture (hk : req.kind = .flight)
    (hs : j.stageAt req.requestedAt = .afterDeparture) (ht : termsStart ≤ req.requestedAt) :
    voluntaryChange e flexFare.rules j req = .allowed (quote req ⟨0, req.oldPrice.currency⟩) false := by
  cases e <;> simp [*]

/-- On Flex, a change of flight after a missed flight is allowed with no fee,
priced from the request's old and new prices. -/
theorem flex_change_noShow (hk : req.kind = .flight)
    (hs : j.stageAt req.requestedAt = .noShow) (ht : termsStart ≤ req.requestedAt) :
    voluntaryChange e flexFare.rules j req = .allowed (quote req ⟨0, req.oldPrice.currency⟩) false := by
  cases e <;> simp [*]

/-- On Flex, a cancellation before departure returns the item's whole price to
the original form of payment. -/
theorem flex_cancel_beforeDeparture (hs : j.stageAt now = .beforeDeparture)
    (ht : termsStart ≤ now) :
    cancellationRefund e ff flexFare.rules j now item = .refund item.price true := by
  cases e <;> simp [*]

/-- On Flex, a cancellation after the first flight returns the item's whole
price to the original form of payment. -/
theorem flex_cancel_afterDeparture (hs : j.stageAt now = .afterDeparture)
    (ht : termsStart ≤ now) :
    cancellationRefund e ff flexFare.rules j now item = .refund item.price true := by
  cases e <;> simp [*]

/-- On Flex, a cancellation after a missed flight returns 100 dollars to the
original form of payment, whatever the item's price. -/
theorem flex_cancel_noShow (hs : j.stageAt now = .noShow) (ht : termsStart ≤ now) :
    cancellationRefund e ff flexFare.rules j now item = .refund (usd 100) true := by
  cases e <;> simp [*]

end Airline
