import Rules.Core.Attributes
import Rules.OneOrder.Change.Theorems
import Rules.OneOrder.AirlineChange.FollowUp
import Rules.OneOrder.AirlineChange.Decline
import Rules.OneOrder.AirlineChange.FlightCancel
import Rules.OneOrder.AirlineChange.Reaccommodate
import Rules.OneOrder.Delivery.Theorems

/-!
# Guarantees of the airline change rules

Properties the rules for airline-initiated changes are claimed to have.  A
guarantee holds for every reading of the sources the rule takes; one left open
is a question for the business.
-/

namespace Rules.OneOrder.AirlineChange

open Rules.Core
open Rules.OneOrder.Change
open Rules.OneOrder.Delivery (isLive MoveReading)

/-! ## Time limits and consequences of inaction -/

/-- The earliest entry of a list is none only for an empty list. -/
theorem earliest_eq_none : ∀ {l : List (Instant × Inaction)}, earliest l = none → l = []
  | [], _ => rfl
  | x :: xs, h => by
    simp only [earliest] at h
    split at h
    · cases h
    · split_ifs at h

/-- The earliest entry of a list is in the list. -/
theorem earliest_mem : ∀ {l : List (Instant × Inaction)} {p : Instant × Inaction},
    earliest l = some p → p ∈ l
  | [], _, h => by simp [earliest] at h
  | x :: xs, p, h => by
    simp only [earliest] at h
    split at h
    · cases h; simp
    · rename_i y hy
      split_ifs at h
      · cases h; exact List.mem_cons_of_mem _ (earliest_mem hy)
      · cases h; simp

/-- No entry of a list comes before its earliest entry. -/
theorem earliest_le : ∀ {l : List (Instant × Inaction)} {p : Instant × Inaction},
    earliest l = some p → ∀ q ∈ l, p.1 ≤ q.1
  | [], _, h => by simp [earliest] at h
  | x :: xs, p, h => by
    intro q hq
    simp only [earliest] at h
    split at h
    · rename_i hn
      cases h
      have := earliest_eq_none hn
      subst this
      simp_all
    · rename_i y hy
      have ih := earliest_le hy
      split_ifs at h with hlt
      · cases h
        rcases List.mem_cons.mp hq with rfl | hq
        · exact le_of_lt hlt
        · exact ih q hq
      · cases h
        rcases List.mem_cons.mp hq with rfl | hq
        · exact le_refl _
        · exact le_trans (not_lt.mp hlt) (ih q hq)

/-- A follow-up action lapses exactly when it has a time limit and a
consequence, stated or taken from the reading. -/
theorem FollowUp.lapse_eq_some (r : FollowUpReading) (f : FollowUp) (t : Instant) (c : Inaction) :
    f.lapse r = some (t, c) ↔
      f.timeLimit = some t ∧ f.consequence.or r.defaultConsequence = some c := by
  unfold FollowUp.lapse
  cases f.timeLimit <;> cases f.consequence.or r.defaultConsequence <;> simp

/-- Once a time limit that carries a consequence of inaction has passed, a
consequence applies: that of a follow-up action whose time limit is the
earliest. -/
@[checks "ONE-702.1"]
theorem lapse_applies_earliest (r : FollowUpReading) (n : ChangeNotice) (now : Instant)
    (f : FollowUp) (hf : f ∈ n.followUps) (t : Instant) (c : Inaction)
    (hl : f.lapse r = some (t, c)) (ht : t ≤ now) :
    ∃ g ∈ n.followUps, ∃ t' c', g.lapse r = some (t', c') ∧ consequenceAt r n now = some c' ∧
      ∀ h ∈ n.followUps, ∀ p ∈ h.lapse r, t' ≤ p.1 := by
  have hmem : (t, c) ∈ n.followUps.filterMap (·.lapse r) := List.mem_filterMap.mpr ⟨f, hf, hl⟩
  obtain ⟨⟨t', c'⟩, hp⟩ : ∃ p, n.lapse r = some p := by
    cases h : n.lapse r with
    | none => exact absurd (earliest_eq_none h) (List.ne_nil_of_mem hmem)
    | some p => exact ⟨p, rfl⟩
  have hple := earliest_le hp
  obtain ⟨g, hg, hgl⟩ := List.mem_filterMap.mp (earliest_mem hp)
  refine ⟨g, hg, t', c', hgl, ?_, ?_⟩
  · have : t' ≤ now := le_trans (hple _ hmem) ht
    simp [consequenceAt, hp, this]
  · intro h hh q hq
    exact hple q (List.mem_filterMap.mpr ⟨h, hh, by simpa using hq⟩)

/-- A notice none of whose follow-up actions has a time limit never has a
consequence of inaction applied, under every reading. -/
@[checks "ONE-702.2"]
theorem no_limit_no_consequence (r : FollowUpReading) (n : ChangeNotice) (now : Instant)
    (h : ∀ f ∈ n.followUps, f.timeLimit = none) :
    consequenceAt r n now = none := by
  have : n.followUps.filterMap (·.lapse r) = [] := by
    rw [List.filterMap_eq_nil_iff]
    intro f hf
    simp [FollowUp.lapse, h f hf]
  simp [consequenceAt, ChangeNotice.lapse, this, earliest]

/-- Before every time limit of a notice, no consequence of inaction applies. -/
@[checks "ONE-702.3"]
theorem before_limits_no_consequence (r : FollowUpReading) (n : ChangeNotice) (now : Instant)
    (h : ∀ f ∈ n.followUps, ∀ t ∈ f.timeLimit, now < t) :
    consequenceAt r n now = none := by
  unfold consequenceAt
  cases hl : n.lapse r with
  | none => rfl
  | some p =>
    obtain ⟨t, c⟩ := p
    obtain ⟨g, hg, hgl⟩ := List.mem_filterMap.mp (earliest_mem hl)
    have hlim := ((FollowUp.lapse_eq_some r g t c).mp hgl).1
    have := h g hg t (by simp [hlim])
    simp [not_le.mpr this]

/-- A notice that offers follow-up actions is resolved before the affected
flight departs, even if the seller never answers.

Open question for the business.  The sources make both the time limit and the
consequence optional, and do not tie the time limit to the departure.  A
notice that offers Cancel with neither, like the guide's Cancel example, never
lapses; a time limit set after the departure lapses too late.  The example
{lit}`noticesAtDeparture` shows both still unresolved when the flight departs.
What applies when a follow-up action has no time limit or no consequence, and
must the time limit fall before the affected flight departs? -/
@[open_question, checks "ONE-702.4"]
theorem resolved_before_departure (r : FollowUpReading) (n : ChangeNotice) (h : n.followUps ≠ []) :
    ∃ t, t < n.departure ∧ (consequenceAt r n t).isSome := by
  sorry

/-! ## Seller follow-up actions -/

/-- A notice with no follow-up action needs only acknowledgement. -/
@[checks "ONE-701.1"]
theorem resolve_acknowledge_only (r : FollowUpReading) (n : ChangeNotice) (acts : List SellerAct)
    (now : Instant) (h : n.followUps = []) :
    resolve r n acts now = .acknowledgeOnly := by
  simp [resolve, h]

/-- A notice that offers an action has a follow-up action. -/
theorem offers_ne_nil (n : ChangeNotice) (a : FollowUpAction) (h : n.offers a = true) :
    n.followUps.isEmpty = false := by
  unfold ChangeNotice.offers at h
  cases hf : n.followUps with
  | nil => simp [hf] at h
  | cons _ _ => rfl

/-- Once a seller's act answers a notice, the notice is resolved with one of
the seller's acts. -/
theorem resolve_answered_of_answeredBy (r : FollowUpReading) (n : ChangeNotice)
    (acts : List SellerAct) (now : Instant) (a : SellerAct) (ha : a ∈ acts)
    (hans : n.answeredBy r now a = true) :
    ∃ b ∈ acts, resolve r n acts now = .answered b.action := by
  have hne : n.followUps.isEmpty = false := by
    simp only [ChangeNotice.answeredBy, Bool.and_eq_true] at hans
    exact offers_ne_nil n a.action hans.1.1.1
  cases hfind : acts.find? (n.answeredBy r now) with
  | none => exact absurd hans (List.find?_eq_none.mp hfind a ha)
  | some b => exact ⟨b, List.mem_of_find?_eq_some hfind, by simp [resolve, hne, hfind]⟩

/-- When the seller takes an offered action other than contacting the airline,
before any consequence of inaction applies, the notice is resolved with one of
the seller's acts, under every reading. -/
@[checks "ONE-701.2"]
theorem resolve_answers (r : FollowUpReading) (n : ChangeNotice) (acts : List SellerAct)
    (now : Instant) (a : SellerAct) (ha : a ∈ acts) (hoff : n.offers a.action = true)
    (hkind : a.action ≠ .contactAirline) (hnow : a.time ≤ now)
    (hbefore : consequenceAt r n a.time = none) :
    ∃ b ∈ acts, resolve r n acts now = .answered b.action := by
  refine resolve_answered_of_answeredBy r n acts now a ha ?_
  simp [ChangeNotice.answeredBy, hoff, FollowUpReading.records, hkind, hnow, hbefore]

/-- A notice is resolved with an answer only when the seller took that action,
the notice offers it, and the seller took it before any consequence of
inaction applied. -/
@[checks "ONE-701.3"]
theorem resolve_answered_sound (r : FollowUpReading) (n : ChangeNotice) (acts : List SellerAct)
    (now : Instant) (x : FollowUpAction) (h : resolve r n acts now = .answered x) :
    ∃ a ∈ acts, a.action = x ∧ n.offers x = true ∧ a.time ≤ now ∧
      consequenceAt r n a.time = none := by
  unfold resolve at h
  split_ifs at h
  split at h
  · rename_i a hfind
    cases h
    have hp := List.find?_some hfind
    simp only [ChangeNotice.answeredBy, Bool.and_eq_true, decide_eq_true_eq,
      Option.isNone_iff_eq_none] at hp
    exact ⟨a, List.mem_of_find?_eq_some hfind, rfl, hp.1.1.1, hp.1.2, hp.2⟩
  · split at h <;> cases h

/-- While no act of the seller answers a notice that offers follow-up actions,
the notice is pending until a consequence of inaction applies, and then it is
resolved with that consequence. -/
@[checks "ONE-701.4"]
theorem resolve_unanswered (r : FollowUpReading) (n : ChangeNotice) (acts : List SellerAct)
    (now : Instant) (hne : n.followUps ≠ []) (h : ∀ a ∈ acts, n.answeredBy r now a = false) :
    (consequenceAt r n now = none → resolve r n acts now = .pending) ∧
      ∀ c, consequenceAt r n now = some c → resolve r n acts now = .lapsed c := by
  have hfind : acts.find? (n.answeredBy r now) = none :=
    List.find?_eq_none.mpr fun a ha => by simp [h a ha]
  have hemp : n.followUps.isEmpty = false := by
    cases hf : n.followUps with
    | nil => exact absurd hf hne
    | cons _ _ => rfl
  refine ⟨fun hc => ?_, fun c hc => ?_⟩
  · simp [resolve, hemp, hfind, hc]
  · simp [resolve, hemp, hfind, hc]

/-- When the seller contacts the airline about a notice that offers
ContactAirline, before any consequence of inaction applies, no consequence of
inaction is applied.

Open question for the business.  Contacting the airline happens outside the
order, and the sources do not say whether the order records it or whether it
clears the other pending actions.  Under a reading where it is not recorded,
a seller who phones the airline before the time limit still sees
Auto-acceptance applied when the limit passes.  The example
{lit}`contactThenAutoAccept` shows it.  Does contacting the airline count as
an answer, and does it stop the time limit? -/
@[open_question, checks "ONE-701.5"]
theorem contact_airline_answers (r : FollowUpReading) (n : ChangeNotice) (acts : List SellerAct)
    (now : Instant) (a : SellerAct) (ha : a ∈ acts) (hact : a.action = .contactAirline)
    (hoff : n.offers .contactAirline = true) (hnow : a.time ≤ now)
    (hbefore : consequenceAt r n a.time = none) :
    ∀ c, resolve r n acts now ≠ .lapsed c := by
  sorry

/-- Under a reading where the order records contacting the airline, a seller
who contacts the airline before any consequence of inaction applies is never
overtaken by one. -/
theorem contact_airline_answers_of_recorded (r : FollowUpReading) (hrec : r.contactRecorded = true)
    (n : ChangeNotice) (acts : List SellerAct) (now : Instant) (a : SellerAct) (ha : a ∈ acts)
    (hact : a.action = .contactAirline) (hoff : n.offers .contactAirline = true)
    (hnow : a.time ≤ now) (hbefore : consequenceAt r n a.time = none) :
    ∀ c, resolve r n acts now ≠ .lapsed c := by
  intro c
  obtain ⟨b, -, hx⟩ := resolve_answered_of_answeredBy r n acts now a ha
    (by simp [ChangeNotice.answeredBy, hact, hoff, FollowUpReading.records, hrec, hnow, hbefore])
  simp [hx]

/-! ## Declining an airline change -/

/-- A price differential states the old price, new price and penalty of the
change it prices. -/
theorem priceDifferential_prices (e : ExcessPenalty) (q : ChangeQuote) (d : PriceDifferential)
    (h : priceDifferential e q = .ok d) :
    d.oldPrice = q.oldPrice ∧ d.newPrice = q.newPrice ∧ d.penalty = q.penalty := by
  unfold priceDifferential at h
  split_ifs at h
  cases h
  exact ⟨rfl, rfl, rfl⟩

/-- Declining through Cancel is priced as a cancellation of the affected items,
with a new price of zero. -/
@[checks "ONE-703.1"]
theorem decline_cancel_prices (e : ExcessPenalty) (w : DeclineFees) (inv : InvoluntaryReading)
    (n : ChangeNotice) (affected : Money) (t : DeclineTerms) (d : PriceDifferential)
    (h : declineOffer e w inv n affected t .cancel = .ok d) :
    d.oldPrice = affected ∧ d.newPrice.amount = 0 := by
  obtain ⟨h1, h2, -⟩ := priceDifferential_prices _ _ _ h
  simp [h1, h2, declineQuote]

/-- Declining through Reshop is priced as a change from the affected items to
the new items at their price. -/
@[checks "ONE-703.2"]
theorem decline_reshop_prices (e : ExcessPenalty) (w : DeclineFees) (inv : InvoluntaryReading)
    (n : ChangeNotice) (affected : Money) (t : DeclineTerms) (p : Money) (d : PriceDifferential)
    (h : declineOffer e w inv n affected t (.reshop p) = .ok d) :
    d.oldPrice = affected ∧ d.newPrice = p := by
  obtain ⟨h1, h2, -⟩ := priceDifferential_prices _ _ _ h
  simp [h1, h2, declineQuote]

/-- Under the reading that waives the airline's fees on involuntary changes,
declining an involuntary change through Cancel, or letting it lapse into
Auto-cancellation, carries no cancellation penalty. -/
theorem decline_cancel_no_penalty_of_waived (e : ExcessPenalty) (inv : InvoluntaryReading)
    (n : ChangeNotice) (affected : Money) (t : DeclineTerms) (d : PriceDifferential)
    (hinv : inv.involuntary n.reason = true)
    (h : declineOffer e .waived inv n affected t .cancel = .ok d) :
    d.penalty.amount = 0 := by
  obtain ⟨-, -, h3⟩ := priceDifferential_prices _ _ _ h
  simp [h3, declineQuote, DeclineFees.penalty, hinv]

/-- Under the reading that waives the airline's fees on involuntary changes,
declining an involuntary change through Reshop carries no change fee. -/
theorem decline_reshop_no_fee_of_waived (e : ExcessPenalty) (inv : InvoluntaryReading)
    (n : ChangeNotice) (affected : Money) (t : DeclineTerms) (p : Money) (d : PriceDifferential)
    (hinv : inv.involuntary n.reason = true)
    (h : declineOffer e .waived inv n affected t (.reshop p) = .ok d) :
    d.penalty.amount = 0 := by
  obtain ⟨-, -, h3⟩ := priceDifferential_prices _ _ _ h
  simp [h3, declineQuote, DeclineFees.penalty, hinv]

/-- A customer who declines an involuntary change through Cancel, or whose
seller lets it lapse into Auto-cancellation, pays no cancellation penalty.

Open question for the business.  The sources offer Cancel as an answer to an
airline change and never say whether the airline's fees apply; the
cancellation page leaves penalties to the airline.  Under the reading that
applies the item's fees, the 50 EUR cancellation fee of the itinerary change
worked example is charged for leaving a change the airline made.  The example
{lit}`declineByCancel` shows it.  Do the airline's cancellation fees apply
when the customer declines a change the airline imposed? -/
@[open_question, checks "ONE-703.4"]
theorem decline_cancel_no_penalty (e : ExcessPenalty) (w : DeclineFees) (inv : InvoluntaryReading)
    (n : ChangeNotice) (affected : Money) (t : DeclineTerms) (d : PriceDifferential)
    (hinv : inv.involuntary n.reason = true)
    (h : declineOffer e w inv n affected t .cancel = .ok d) :
    d.penalty.amount = 0 := by
  sorry

/-- A customer who declines an involuntary change through Reshop pays no change
fee.

Open question for the business.  The sources say a reshop after an airline
change may or may not cost the customer more, and give no rule.  Under the
reading that applies the item's fees, the 40 EUR change fee of the itinerary
change worked example is charged when the customer reshops away from flights
the airline moved.  The example {lit}`declineByReshop` shows it.  Do change
fees and fare differences apply when the customer reshops after an airline
change, and which alternatives must the airline offer? -/
@[open_question, checks "ONE-703.5"]
theorem decline_reshop_no_fee (e : ExcessPenalty) (w : DeclineFees) (inv : InvoluntaryReading)
    (n : ChangeNotice) (affected : Money) (t : DeclineTerms) (p : Money) (d : PriceDifferential)
    (hinv : inv.involuntary n.reason = true)
    (h : declineOffer e w inv n affected t (.reshop p) = .ok d) :
    d.penalty.amount = 0 := by
  sorry

/-! ## A flight the airline cancels -/

/-- Every live service on the cancelled flight that the delivery status table
lets become UNABLE TO DELIVER is replaced, in the same order item, by the same
service marked CANCELLED with delivery status UNABLE TO DELIVER, under every
reading of the sources. -/
@[checks "ONE-704.1"]
theorem cancel_flight_marks (m : MoveReading) (r : FlightRefund) (seg : String) (o : Order)
    (i : OrderItem) (hi : i ∈ o.items) (s : Service) (hs : s ∈ i.services) (hseg : s.segment = seg)
    (hlive : isLive s = true) (hmove : (Delivery.nextDelivery m .unable s).isSome) :
    ∃ i' ∈ (cancelFlight m r seg o).order.items, i'.id = i.id ∧
      { s with status := .cancelled, delivery := .unableToDeliver } ∈ i'.services ∧
      s ∉ i'.services := by
  obtain ⟨d, hd⟩ := Option.isSome_iff_exists.mp hmove
  have hdu := Delivery.nextDelivery_unable m s d hd
  subst hdu
  refine ⟨{ i with services := i.services.map (cancelOnFlight m seg) }, ?_, rfl, ?_, ?_⟩
  · simp only [cancelFlight, List.mem_map]
    exact ⟨i, hi, rfl⟩
  · exact List.mem_map.mpr ⟨s, hs, by simp [cancelOnFlight, hseg, hlive, Delivery.endWith, hd]⟩
  · intro hmem
    obtain ⟨s0, -, h0⟩ := List.mem_map.mp hmem
    unfold cancelOnFlight at h0
    split_ifs at h0 with hc
    · unfold Delivery.endWith at h0
      cases hn : Delivery.nextDelivery m .unable s0 with
      | none =>
        simp only [hn] at h0
        subst h0
        simp [hn] at hmove
      | some d0 =>
        simp only [hn] at h0
        have := congrArg Service.status h0
        simp only [isLive, Bool.and_eq_true, bne_iff_ne, ne_eq] at hlive
        exact hlive.1.1 this.symm
    · subst h0
      exact hc ⟨hseg, hlive⟩

/-- Every service on another flight stays as it was, in the same order item. -/
@[checks "ONE-704.2"]
theorem cancel_flight_keeps_others (m : MoveReading) (r : FlightRefund) (seg : String) (o : Order)
    (i : OrderItem) (hi : i ∈ o.items) (s : Service) (hs : s ∈ i.services) (hseg : s.segment ≠ seg) :
    ∃ i' ∈ (cancelFlight m r seg o).order.items, i'.id = i.id ∧ s ∈ i'.services := by
  refine ⟨{ i with services := i.services.map (cancelOnFlight m seg) }, ?_, rfl, ?_⟩
  · simp only [cancelFlight, List.mem_map]
    exact ⟨i, hi, rfl⟩
  · exact List.mem_map.mpr ⟨s, hs, by simp [cancelOnFlight, hseg]⟩

/-- The order keeps every order item, in the same order, with its reference
and price. -/
@[checks "ONE-704.3"]
theorem cancel_flight_keeps_items (m : MoveReading) (r : FlightRefund) (seg : String) (o : Order) :
    (cancelFlight m r seg o).order.items.map (fun i => (i.id, i.price)) =
      o.items.map (fun i => (i.id, i.price)) := by
  simp [cancelFlight, Function.comp_def]

/-- When the airline cancels a flight and does not re-accommodate the
customer, no live service is left on that flight.

Open question for the business.  The flight's services are ended through the
delivery status table, and the table has no move to UNABLE TO DELIVER from
REQUESTED, IN PROGRESS or SUSPENDED, under any reading.  A service the airline
has not yet confirmed therefore stays live on a flight that will not operate.
The example {lit}`cancelFlightWhileRequested` shows it.  What delivery status
does a requested or suspended service take when its flight is cancelled? -/
@[open_question, checks "ONE-704.6"]
theorem cancel_flight_leaves_no_live (m : MoveReading) (r : FlightRefund) (seg : String) (o : Order) :
    ∀ i ∈ (cancelFlight m r seg o).order.items, ∀ s ∈ i.services, s.segment = seg → isLive s = false := by
  sorry

/-- Every refund the rule gives is no more than the price of the order item it
is for, under every reading. -/
theorem cancel_flight_refund_le_price (mr : MoveReading) (r : FlightRefund) (seg : String) (o : Order)
    (id : String) (m : Money) (h : (id, m) ∈ (cancelFlight mr r seg o).refunds) :
    ∃ i ∈ o.items, i.id = id ∧ m.amount ≤ i.price.amount := by
  simp only [cancelFlight, List.mem_map, List.mem_filter, Prod.mk.injEq] at h
  obtain ⟨i, ⟨hi, -⟩, hid, hm⟩ := h
  exact ⟨i, hi, hid, hm ▸ r.le_price i seg⟩

/-- When the airline cancels a flight of a paid order item and does not
re-accommodate the customer, the customer gets part of the item's price back.

Open question for the business.  The flight cancellation worked example
offers no follow-up action and no refund, and no source says whether a flight
the airline cannot deliver entitles the customer to money back.  Because the
price is set per order item, no source says how much of it belongs to one
flight either.  Under the reading the worked example shows, a paid return trip
at 1,000.00 EUR whose inbound flight is cancelled gets nothing back.  The
example {lit}`cancelInboundFlight` shows it.  Is a refund owed when the
airline cancels a flight without re-accommodation, and how much of an item's
price belongs to that flight? -/
@[open_question, checks "ONE-704.4"]
theorem cancel_flight_refunds (mr : MoveReading) (r : FlightRefund) (seg : String) (o : Order)
    (i : OrderItem)
    (hi : i ∈ o.items) (hprice : 0 < i.price.amount) (s : Service) (hs : s ∈ i.services)
    (hseg : s.segment = seg) (hpaid : s.status = .confirmed ∧ s.delivery = .readyToProceed) :
    ∃ m, (i.id, m) ∈ (cancelFlight mr r seg o).refunds ∧ 0 < m.amount := by
  sorry

/-- After the airline cancels a flight, every order item that holds a
CANCELLED service is itself CANCELLED, provided this held before.

Open question for the business.  The Order concept ties a CANCELLED service
to a cancelled order item, and the cancellation page treats cancelling some
services of an item as a change.  The flight cancellation worked example
cancels one flight's services and leaves the item as it was.  A return trip
whose inbound flight is cancelled keeps an active outbound flight, so the item
stays ACTIVE with CANCELLED services in it, under every reading.  The example
{lit}`cancelInboundFlight` shows it.  Should the airline replace the item, as
a change does, or may an active item hold cancelled services? -/
@[open_question, checks "ONE-704.5"]
theorem cancel_flight_cancelled_items (m : MoveReading) (v : ValueReading) (r : FlightRefund)
    (seg : String) (o : Order)
    (hbefore : ∀ i ∈ o.items, (∃ s ∈ i.services, s.status = .cancelled) →
      itemStatuses v i = [.cancelled]) :
    ∀ i ∈ (cancelFlight m r seg o).order.items, (∃ s ∈ i.services, s.status = .cancelled) →
      itemStatuses v i = [.cancelled] := by
  sorry

/-! ## Re-accommodation before the seller answers -/

/-- Where the change takes effect at notice, the order is the order after the
change rule for a paid change, one version higher. -/
@[checks "ONE-705.1"]
theorem notify_at_notice (m : MoveReading) (vo : VersionedOrder) (c : Reaccommodation)
    (vo' : VersionedOrder) (h : notifyChange m .notice vo c = .ok vo') :
    ∃ old, vo.order.items.find? (·.id = c.item) = some old ∧
      changeItem m vo.order (c.toItemChange old) = .ok vo'.order ∧ vo'.version = vo.version + 1 := by
  unfold notifyChange at h
  split at h
  · cases h
  · rename_i old hold
    cases hc : changeItem m vo.order (c.toItemChange old) with
    | error e => simp [hc, Except.map] at h
    | ok o =>
      simp only [hc, Except.map, Except.ok.injEq] at h
      subst h
      exact ⟨old, hold, hc, rfl⟩

/-- Where the change waits for the seller's Accept, the order and its version
are as they were at notice. -/
@[checks "ONE-705.2"]
theorem notify_at_acceptance (m : MoveReading) (vo : VersionedOrder) (c : Reaccommodation)
    (vo' : VersionedOrder) (h : notifyChange m .acceptance vo c = .ok vo') :
    vo' = vo := by
  unfold notifyChange at h
  split at h
  · cases h
  · cases h; rfl

/-- When the change takes effect, the new order item has the original item's
price and a service for each passenger of the original item on each new
flight. -/
@[checks "ONE-705.3"]
theorem notify_new_item (m : MoveReading) (vo : VersionedOrder) (c : Reaccommodation)
    (vo' : VersionedOrder) (h : notifyChange m .notice vo c = .ok vo') :
    ∃ old ∈ vo.order.items, old.id = c.item ∧ ∃ ni ∈ vo'.order.items, ni.id = c.newItem ∧
      ni.price = old.price ∧ ∀ p ∈ passengersOf old, ∀ seg ∈ c.newSegments,
        ∃ s ∈ ni.services, s.passenger = p ∧ s.segment = seg := by
  obtain ⟨old, hold, hc, -⟩ := notify_at_notice m vo c vo' h
  obtain ⟨old', hold', -, ho'⟩ := changeItem_ok m vo.order vo'.order _ hc
  have hsame : old' = old := Option.some.inj (hold'.symm.trans hold)
  subst hsame
  have hid := List.find?_some hold
  refine ⟨old', List.mem_of_find?_eq_some hold, by simpa using hid, ?_⟩
  refine ⟨newItemOf (c.toItemChange old') old', by rw [ho']; simp, rfl, rfl, ?_⟩
  intro p hp seg hseg
  have hmem : ({ id := c.newItem ++ "-" ++ p.id ++ "-" ++ seg, passenger := p, segment := seg,
                 status := .confirmed, delivery := .confirmed } : Service) ∈ c.newServices old' :=
    List.mem_flatMap.mpr ⟨p, hp, List.mem_map.mpr ⟨seg, hseg, rfl⟩⟩
  exact ⟨_, List.mem_append_right _ hmem, rfl, rfl⟩

/-- While the seller's Accept of an airline change is pending, the original
order item keeps the status it had.

Open question for the business.  In the itinerary change worked example the
change is already in the order while Accept is pending: the original item is
CANCELLED at the next version.  A customer who would rather keep the original
flights cannot get them back, so Accept offers no real choice.  The example
{lit}`itineraryReaccommodated` shows it under the reading that applies the
change at notice.  Is a change awaiting acceptance provisional, and does
declining it restore the original item or only let the customer cancel or
reshop from the changed order? -/
@[open_question, checks "ONE-705.4"]
theorem accept_pending_keeps_original (m : MoveReading) (v : ValueReading) (a : ApplyAt)
    (vo : VersionedOrder)
    (c : Reaccommodation) (vo' : VersionedOrder) (h : notifyChange m a vo c = .ok vo')
    (i : OrderItem) (hi : i ∈ vo.order.items) (hid : i.id = c.item) :
    ∃ i' ∈ vo'.order.items, i'.id = c.item ∧ itemStatuses v i' = itemStatuses v i := by
  sorry

/-- Under the reading where a change waits for the seller's Accept, the
original order item keeps its status when the change is notified. -/
theorem accept_pending_keeps_original_of_acceptance (m : MoveReading) (v : ValueReading)
    (vo : VersionedOrder)
    (c : Reaccommodation) (vo' : VersionedOrder) (h : notifyChange m .acceptance vo c = .ok vo')
    (i : OrderItem) (hi : i ∈ vo.order.items) (hid : i.id = c.item) :
    ∃ i' ∈ vo'.order.items, i'.id = c.item ∧ itemStatuses v i' = itemStatuses v i := by
  rw [notify_at_acceptance m vo c vo' h]
  exact ⟨i, hi, hid, rfl⟩

/-- When the airline replaces paid services at no price difference, every
service of the new order item is READY TO PROCEED.

Open question for the business.  In the itinerary change worked example the
services the airline creates start CONFIRMED, a status the Order concept
reserves for services still awaiting payment, although the customer paid in
full and the exchange is even.  If CONFIRMED is read as unpaid, a payment
time limit could apply to a trip the customer already paid for.  The example
{lit}`itineraryReaccommodated` shows the new services CONFIRMED.  Does the
paid status carry across an airline change? -/
@[open_question, checks "ONE-705.5"]
theorem reaccommodated_paid (m : MoveReading) (a : ApplyAt) (vo : VersionedOrder)
    (c : Reaccommodation)
    (vo' : VersionedOrder) (h : notifyChange m a vo c = .ok vo') (old : OrderItem)
    (hold : vo.order.items.find? (·.id = c.item) = some old)
    (hpaid : ∀ s ∈ old.services, s.delivery = .readyToProceed)
    (hfresh : ∀ i ∈ vo.order.items, i.id ≠ c.newItem) :
    ∀ ni ∈ vo'.order.items, ni.id = c.newItem → ∀ s ∈ ni.services, s.delivery = .readyToProceed := by
  sorry

end Rules.OneOrder.AirlineChange
