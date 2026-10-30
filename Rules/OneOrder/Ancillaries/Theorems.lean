import Rules.Core.Attributes
import Rules.OneOrder.Ancillaries.Add
import Rules.OneOrder.Ancillaries.Cancel
import Rules.OneOrder.Ancillaries.Replace
import Rules.OneOrder.Ancillaries.Seats
import Rules.OneOrder.Ancillaries.AlaCarte
import Rules.OneOrder.Ancillaries.Bundle
import Rules.OneOrder.Delivery.Theorems

/-!
# Guarantees for ancillaries

Properties the ancillary rules are claimed to have.  A guarantee counts as
proven only when it holds under every reading of the sources; one left open is
a question for the business, and an example shows the rule breaking it.
-/

namespace Rules.OneOrder.Ancillaries

open Rules.Core
open Rules.OneOrder.Delivery (isLive MoveReading nextDelivery)

/-! ## Dependent services and their parent -/

/-- Under the reference reading, a service is a dependent of a flight service
exactly when it is an ancillary of the order that names that flight service as
its parent. -/
@[checks "ONE-601.1"]
theorem dependents_by_reference (d : ServiceDetails) (o : Order) (f s : Service) :
    s ∈ dependents .reference d o f ↔
      s ∈ services o ∧ d.isFlight f = true ∧ d.isFlight s = false ∧ d.parent s.id = some f.id := by
  simp [dependents, dependsOn, linked, and_assoc]

/-- Under the passenger and segment reading, a service is a dependent of a
flight service exactly when it is an ancillary of the order for the same
passenger on the same segment. -/
@[checks "ONE-601.2"]
theorem dependents_by_passenger_segment (d : ServiceDetails) (o : Order) (f s : Service) :
    s ∈ dependents .passengerSegment d o f ↔
      s ∈ services o ∧ d.isFlight f = true ∧ d.isFlight s = false ∧
        s.passenger = f.passenger ∧ s.segment = f.segment := by
  simp [dependents, dependsOn, linked, and_assoc]

/-- No flight service is ever counted as a dependent, under either reading. -/
@[checks "ONE-601.3"]
theorem dependent_not_flight (r : LinkReading) (d : ServiceDetails) (o : Order) (f s : Service)
    (h : s ∈ dependents r d o f) : d.isFlight s = false := by
  simp only [dependents, List.mem_filter, dependsOn, Bool.and_eq_true, Bool.not_eq_true'] at h
  exact h.2.1.2

/-- An ancillary for the same passenger and segment as a flight service of the
order is counted as dependent on it, under either reading.

Open question for the business.  Under the reference reading only an
ancillary that names its flight counts.  In the seat worked example the seat
services name no flight service, so a seat for the passenger on the flight is
not a dependent of it, and a change to the flight reports no impact on the
seat.  The example {lit}`seatWithoutReference` shows it.  Which link defines
the dependency: a reference to the parent, or the shared passenger and
segment?  And may an ancillary depend on another ancillary, such as a lounge
pass on a premium seat? -/
@[open_question, checks "ONE-601.4"]
theorem dependents_cover (r : LinkReading) (d : ServiceDetails) (o : Order) (f s : Service)
    (hs : s ∈ services o) (hf : d.isFlight f = true) (ha : d.isFlight s = false)
    (hp : s.passenger = f.passenger) (hseg : s.segment = f.segment) :
    s ∈ dependents r d o f := by
  sorry

/-- Under the passenger and segment reading, every ancillary of the order for
the same passenger and segment as a flight service is counted as dependent on
it. -/
theorem dependents_cover_of_passenger_segment (d : ServiceDetails) (o : Order) (f s : Service)
    (hs : s ∈ services o) (hf : d.isFlight f = true) (ha : d.isFlight s = false)
    (hp : s.passenger = f.passenger) (hseg : s.segment = f.segment) :
    s ∈ dependents .passengerSegment d o f :=
  (dependents_by_passenger_segment d o f s).mpr ⟨hs, hf, ha, hp, hseg⟩

/-! ## Adding ancillaries -/

/-- A request that adds a flight-related ancillary with no live flight service
for its passenger and segment, in the order or in the request, is refused,
under every reading of which kinds are flight related. -/
@[checks "ONE-602.1"]
theorem add_refuses_without_flight (related : ServiceKind → Bool) (d : ServiceDetails) (o : Order)
    (items : List OrderItem) (s : Service) (hs : s ∈ items.flatMap (·.services))
    (hrel : isFlightRelated related d s = true)
    (hno : hasFlightFor d (services o ++ items.flatMap (·.services)) s = false) :
    ∃ e, addServices related d o items = .error e := by
  unfold addServices
  cases hm : missingFlight related d o items with
  | some s' => exact ⟨_, rfl⟩
  | none =>
    simp only [missingFlight, List.find?_eq_none] at hm
    exact absurd (by simp [hrel, hno]) (hm s hs)

/-- An accepted request adds its order items after the existing ones, which
stay as they were, and keeps the order's reference and creation instant. -/
@[checks "ONE-602.2"]
theorem add_appends (related : ServiceKind → Bool) (d : ServiceDetails) (o o' : Order)
    (items : List OrderItem) (h : addServices related d o items = .ok o') :
    o'.items = o.items ++ items ∧ o'.id = o.id ∧ o'.createdAt = o.createdAt := by
  unfold addServices at h
  split at h
  · cases h
  · cases h; exact ⟨rfl, rfl, rfl⟩

/-- A request with no flight-related ancillary is accepted, under every
reading. -/
@[checks "ONE-602.3"]
theorem add_accepts_unrelated (related : ServiceKind → Bool) (d : ServiceDetails) (o : Order)
    (items : List OrderItem) (h : ∀ s ∈ items.flatMap (·.services), isFlightRelated related d s = false) :
    addServices related d o items = .ok { o with items := o.items ++ items } := by
  have hm : missingFlight related d o items = none := by
    simp only [missingFlight, List.find?_eq_none]
    intro s hs
    simp [h s hs]
  simp [addServices, hm]

/-- When every live flight-related ancillary of an order has a live flight
service for its passenger and segment, a paid change to an order item keeps it
so.

Open question for the business.  The guide states the rule when an ancillary
is bought.  A change that moves a passenger's flight to another segment
cancels the old flight service and leaves the bag bought for it confirmed, on
a segment the passenger no longer flies.  The example
{lit}`bagLeftByFlightChange` shows it.  Does the rule hold for the life of the
order, and if so, what happens to the bag? -/
@[open_question, checks "ONE-602.4"]
theorem change_keeps_flights (m : MoveReading) (related : ServiceKind → Bool) (d : ServiceDetails)
    (o o' : Order) (c : Change.ItemChange) (h0 : uncovered related d o = [])
    (h : Change.changeItem m o c = .ok o') :
    uncovered related d o' = [] := by
  sorry

/-! ## Cancelling a flight with its ancillaries -/

/-- An accepted cancellation leaves the order as the rule's last step makes
it: every item through {name}`itemAfterCancel`. -/
theorem cancelItems_ok (m : MoveReading) (h : DependentHandling) (r : LinkReading)
    (d : ServiceDetails) (allows : String → Bool) (o o' : Order) (named : List String)
    (hok : cancelItems m h r d allows o named = .ok o') :
    o'.items = o.items.map (itemAfterCancel m h r d (namedFlights d o named) named) := by
  unfold cancelItems at hok
  split at hok
  · cases hok
  · split at hok
    · cases hok
    · split at hok
      · cases hok
      · cases hok; rfl

/-- Every named item is in the order afterwards with each live service that
the delivery status table lets be removed CANCELLED with delivery status
REMOVED, under every reading. -/
@[checks "ONE-603.1"]
theorem cancel_items_named (m : MoveReading) (h : DependentHandling) (r : LinkReading)
    (d : ServiceDetails) (allows : String → Bool) (o o' : Order) (named : List String)
    (hok : cancelItems m h r d allows o named = .ok o') (i : OrderItem) (hi : i ∈ o.items)
    (hn : i.id ∈ named) :
    ∃ i' ∈ o'.items, i'.id = i.id ∧
      ∀ s ∈ i.services, isLive s = true → (nextDelivery m .remove s).isSome →
        { s with status := .cancelled, delivery := .removed } ∈ i'.services := by
  rw [cancelItems_ok m h r d allows o o' named hok]
  refine ⟨itemAfterCancel m h r d (namedFlights d o named) named i, List.mem_map_of_mem hi,
    by simp [itemAfterCancel, hn], ?_⟩
  intro s hs hlive hrem
  obtain ⟨dl, hd⟩ := Option.isSome_iff_exists.mp hrem
  have hdr := Delivery.nextDelivery_remove m s dl hd
  subst hdr
  simp only [itemAfterCancel, hn, List.contains_iff_mem, ↓reduceIte, List.mem_map]
  exact ⟨s, hs, by simp [endService, hlive, Delivery.endWith, hd]⟩

/-- A request that names an item whose conditions do not allow cancellation
is refused, under every reading. -/
@[checks "ONE-603.2"]
theorem cancel_items_refuses_not_cancellable (m : MoveReading) (h : DependentHandling)
    (r : LinkReading)
    (d : ServiceDetails) (allows : String → Bool) (o : Order) (named : List String) (id : String)
    (hn : id ∈ named) (hno : allows id = false) (o' : Order) :
    cancelItems m h r d allows o named ≠ .ok o' := by
  unfold cancelItems
  split
  · simp
  · split
    · simp
    · rename_i hfind
      simp only [List.find?_eq_none] at hfind
      exact absurd (by simp [hno]) (hfind id hn)

/-- Every service outside the named items that is not a live dependent of a
cancelled flight is in the order afterwards, in the same item, under every
reading. -/
@[checks "ONE-603.3"]
theorem cancel_items_keeps_others (m : MoveReading) (h : DependentHandling) (r : LinkReading)
    (d : ServiceDetails) (allows : String → Bool) (o o' : Order) (named : List String)
    (hok : cancelItems m h r d allows o named = .ok o') (i : OrderItem) (hi : i ∈ o.items)
    (hn : i.id ∉ named) (s : Service) (hs : s ∈ i.services)
    (hdep : isLiveDependent r d (namedFlights d o named) s = false) :
    ∃ i' ∈ o'.items, i'.id = i.id ∧ s ∈ i'.services := by
  rw [cancelItems_ok m h r d allows o o' named hok]
  refine ⟨itemAfterCancel m h r d (namedFlights d o named) named i, List.mem_map_of_mem hi, ?_, ?_⟩
  · unfold itemAfterCancel; split_ifs <;> rfl
  · unfold itemAfterCancel
    split_ifs with h1 h2
    · simp_all
    · exact List.mem_map.mpr ⟨s, hs, by simp [hdep]⟩
    · exact hs

/-- A cancelled service is no longer live, when the delivery status table lets
it be removed. -/
theorem isLive_endService (m : MoveReading) (s : Service)
    (hrem : isLive s = true → (nextDelivery m .remove s).isSome) : isLive (endService m s) = false := by
  unfold endService
  split_ifs with h
  · exact Delivery.endWith_cancelled_not_live m .remove s (hrem h)
  · simpa using h

/-- An accepted cancellation names only items whose conditions allow
cancellation, and, under the reading that refuses until dependents are named,
leaves no live dependent outside the named items. -/
theorem cancelItems_ok_conditions (m : MoveReading) (h : DependentHandling) (r : LinkReading)
    (d : ServiceDetails) (allows : String → Bool) (o o' : Order) (named : List String)
    (hok : cancelItems m h r d allows o named = .ok o') :
    (∀ id ∈ named, allows id = true) ∧
      (h = .refuseUnlessNamed → unnamedDependents r d o named = []) := by
  unfold cancelItems at hok
  split at hok
  · cases hok
  · split at hok
    · cases hok
    · rename_i hfind
      simp only [List.find?_eq_none, Bool.not_eq_true', Bool.not_eq_false] at hfind
      refine ⟨fun id hid => by simpa using hfind id hid, fun hh => ?_⟩
      subst hh
      split at hok
      · cases hok
      · rename_i hne
        cases hu : unnamedDependents r d o named with
        | nil => rfl
        | cons s rest => exact absurd hu (hne s rest rfl)

/-- Under the readings that cancel dependents with their flight or refuse until
they are named, no live service depends on a flight the seller cancels, when
the delivery status table lets every live service of the order be removed. -/
theorem cancel_items_no_live_dependents_of_not_leave (m : MoveReading) (h : DependentHandling)
    (hh : h ≠ .leaveInPlace) (r : LinkReading) (d : ServiceDetails) (allows : String → Bool)
    (o o' : Order) (named : List String) (hok : cancelItems m h r d allows o named = .ok o')
    (hrem : ∀ i ∈ o.items, ∀ s ∈ i.services, isLive s = true → (nextDelivery m .remove s).isSome)
    (f : Service) (hf : f ∈ namedFlights d o named) (s : Service) (hs : s ∈ services o')
    (hdep : dependsOn r d f s = true) : isLive s = false := by
  have hitems := cancelItems_ok m h r d allows o o' named hok
  have hcond := cancelItems_ok_conditions m h r d allows o o' named hok
  simp only [services, hitems, List.flatMap_map, List.mem_flatMap] at hs
  obtain ⟨j, hj, hsj⟩ := hs
  unfold itemAfterCancel at hsj
  split_ifs at hsj with hn hcw
  · obtain ⟨s0, hs0, rfl⟩ := List.mem_map.mp hsj
    exact isLive_endService m s0 (hrem j hj s0 hs0)
  · obtain ⟨s0, hs0, rfl⟩ := List.mem_map.mp hsj
    split_ifs with hld
    · exact isLive_endService m s0 (hrem j hj s0 hs0)
    · simp only [hld, Bool.false_eq_true, ↓reduceIte] at hdep
      simp only [isLiveDependent] at hld
      cases hl : isLive s0
      · rfl
      · exact (hld (by rw [hl, Bool.true_and, List.any_eq_true]; exact ⟨f, hf, hdep⟩)).elim
  · cases h with
    | cancelWithFlight => exact absurd rfl hcw
    | leaveInPlace => exact absurd rfl hh
    | refuseUnlessNamed =>
      have hempty := hcond.2 rfl
      cases hl : isLive s
      · rfl
      · have : s ∈ unnamedDependents r d o named := by
          simp only [unnamedDependents, List.mem_filter, List.mem_flatMap]
          refine ⟨⟨j, ⟨hj, by simpa using hn⟩, hsj⟩, ?_⟩
          simp only [isLiveDependent, hl, Bool.true_and, List.any_eq_true]
          exact ⟨f, hf, hdep⟩
        simp [hempty] at this

/-- Under the readings that refuse until dependents are named or leave them in
place, a live service of an item whose conditions do not allow cancellation
stays as it was. -/
theorem cancel_items_respects_conditions_of_not_cancel_with (m : MoveReading)
    (h : DependentHandling)
    (hh : h ≠ .cancelWithFlight) (r : LinkReading) (d : ServiceDetails) (allows : String → Bool)
    (o o' : Order) (named : List String) (hok : cancelItems m h r d allows o named = .ok o')
    (i : OrderItem) (hi : i ∈ o.items) (hno : allows i.id = false) (s : Service)
    (hs : s ∈ i.services) : ∃ i' ∈ o'.items, i'.id = i.id ∧ s ∈ i'.services := by
  have hn : i.id ∉ named := fun hin => by
    simp [(cancelItems_ok_conditions m h r d allows o o' named hok).1 i.id hin] at hno
  rw [cancelItems_ok m h r d allows o o' named hok]
  refine ⟨i, List.mem_map.mpr ⟨i, hi, ?_⟩, rfl, hs⟩
  simp [itemAfterCancel, hn, hh]

/-- Under the readings that cancel dependents with their flight or leave them
in place, an order item whose conditions allow cancellation is cancelled by a
request that names it alone. -/
theorem cancel_items_allowed_of_not_refuse (m : MoveReading) (h : DependentHandling)
    (hh : h ≠ .refuseUnlessNamed)
    (r : LinkReading) (d : ServiceDetails) (allows : String → Bool) (o : Order) (i : OrderItem)
    (hi : i ∈ o.items) (ha : allows i.id = true) :
    ∃ o', cancelItems m h r d allows o [i.id] = .ok o' := by
  have h1 : [i.id].find? (fun id => !o.items.any (·.id == id)) = none := by
    simp only [List.find?_eq_none, List.mem_singleton]
    rintro x rfl
    simpa using ⟨i, hi, rfl⟩
  have h2 : [i.id].find? (fun id => !allows id) = none := by simp [ha]
  unfold cancelItems
  rw [h1, h2]
  cases h with
  | refuseUnlessNamed => exact absurd rfl hh
  | cancelWithFlight => exact ⟨_, rfl⟩
  | leaveInPlace => exact ⟨_, rfl⟩

/-- After a seller cancels a flight, no live service depends on it.

Open question for the business.  Under the reading where the dependents stay
as they are, a cancelled flight leaves its bag confirmed on a segment the
passenger no longer flies.  The example {lit}`cancelFlightWithBag` shows it.
The other two readings keep the guarantee when every live service of the order
can be removed ({name}`cancel_items_no_live_dependents_of_not_leave`).  A bag
still REQUESTED from the airline cannot be: the delivery status table has no
move from REQUESTED to REMOVED, so it stays live under every reading.
Should cancelling a flight cancel its bag and seat, refuse until the seller
names them, or leave them in place, and what happens to one the airline has
not yet confirmed? -/
@[open_question, checks "ONE-603.4"]
theorem cancel_items_no_live_dependents (m : MoveReading) (h : DependentHandling) (r : LinkReading)
    (d : ServiceDetails) (allows : String → Bool) (o o' : Order) (named : List String)
    (hok : cancelItems m h r d allows o named = .ok o') (f : Service) (hf : f ∈ namedFlights d o named)
    (s : Service) (hs : s ∈ services o') (hdep : dependsOn r d f s = true) :
    isLive s = false := by
  sorry

/-- A live service of an item whose conditions do not allow cancellation is in
the order afterwards as it was.

Open question for the business.  Under the reading where dependents are
cancelled with their flight, cancelling a flight cancels the extra bag bought
for it, although the bag's conditions do not allow cancellation, as in the add
bag worked example.  The example {lit}`cancelFlightWithBag` shows it.  The
other two readings keep the guarantee
({name}`cancel_items_respects_conditions_of_not_cancel_with`).  Whose
conditions govern a dependent cancelled with its flight, and its refund: the
dependent's own or the flight's? -/
@[open_question, checks "ONE-603.5"]
theorem cancel_items_respects_conditions (m : MoveReading) (h : DependentHandling) (r : LinkReading)
    (d : ServiceDetails) (allows : String → Bool) (o o' : Order) (named : List String)
    (hok : cancelItems m h r d allows o named = .ok o') (i : OrderItem) (hi : i ∈ o.items)
    (hno : allows i.id = false) (s : Service) (hs : s ∈ i.services) :
    ∃ i' ∈ o'.items, i'.id = i.id ∧ s ∈ i'.services := by
  sorry

/-- An order item whose conditions allow cancellation can be cancelled by some
request that names it.

Open question for the business.  Under the reading where a cancellation is
refused until the seller names the dependents too, a flight whose extra bag
may not be cancelled can never be cancelled: naming the flight alone is
refused for the bag, and naming the bag too is refused by the bag's
conditions.  The example {lit}`refuseUntilNamedBlocks` shows it.  The other
two readings keep the guarantee ({name}`cancel_items_allowed_of_not_refuse`).
Should a dependent's conditions be able to stop its flight from being
cancelled? -/
@[open_question, checks "ONE-603.6"]
theorem cancel_items_allowed (m : MoveReading) (h : DependentHandling) (r : LinkReading)
    (d : ServiceDetails) (allows : String → Bool) (o : Order) (i : OrderItem) (hi : i ∈ o.items)
    (ha : allows i.id = true) :
    ∃ named, i.id ∈ named ∧ ∃ o', cancelItems m h r d allows o named = .ok o' := by
  sorry

/-! ## Dependents when a flight is replaced -/

/-- The service an impact is for is the dependent service it was made from. -/
theorem impactOf_service (e : ServiceKind → DependentEffect) (d : ServiceDetails) (newSeg : String)
    (s : Service) : (impactOf e d newSeg s).service = s.id := by
  unfold impactOf; split <;> rfl

/-- The effect of an impact is the reading's effect for the service's kind. -/
theorem impactOf_effect (e : ServiceKind → DependentEffect) (d : ServiceDetails) (newSeg : String)
    (s : Service) : (impactOf e d newSeg s).effect = e (d.kind s.id) := by
  unfold impactOf; split <;> simp_all

/-- The rule states one effect for each live dependent of the replaced flight,
in order, and for no other service. -/
@[checks "ONE-604.1"]
theorem replace_states_each_dependent (e : ServiceKind → DependentEffect) (r : LinkReading)
    (d : ServiceDetails) (o : Order) (f : Service) (newSeg : String) :
    (replaceFlight e r d o f newSeg).map (·.service) = ((dependents r d o f).filter isLive).map (·.id) := by
  simp [replaceFlight, Function.comp_def, impactOf_service]

/-- Each stated effect is the reading's effect for the kind of a live
dependent of the replaced flight. -/
@[checks "ONE-604.2"]
theorem replace_effect_by_kind (e : ServiceKind → DependentEffect) (r : LinkReading)
    (d : ServiceDetails) (o : Order) (f : Service) (newSeg : String) (x : Impact)
    (hx : x ∈ replaceFlight e r d o f newSeg) :
    ∃ s ∈ dependents r d o f, isLive s = true ∧ x.service = s.id ∧ x.effect = e (d.kind s.id) := by
  simp only [replaceFlight, List.mem_map, List.mem_filter] at hx
  obtain ⟨s, ⟨hs, hlive⟩, rfl⟩ := hx
  exact ⟨s, hs, hlive, impactOf_service e d newSeg s, impactOf_effect e d newSeg s⟩

/-- A dependent whose effect is to move is put on the new segment, for the same
passenger, under the same reference, confirmed. -/
@[checks "ONE-604.3"]
theorem replace_moves (e : ServiceKind → DependentEffect) (r : LinkReading) (d : ServiceDetails)
    (o : Order) (f : Service) (newSeg : String) (x : Impact)
    (hx : x ∈ replaceFlight e r d o f newSeg) (hmove : x.effect = .move) :
    ∃ s ∈ dependents r d o f,
      x.moved = some { s with segment := newSeg, status := .confirmed } ∧ x.service = s.id := by
  simp only [replaceFlight, List.mem_map, List.mem_filter] at hx
  obtain ⟨s, ⟨hs, -⟩, rfl⟩ := hx
  refine ⟨s, hs, ?_, impactOf_service e d newSeg s⟩
  have := impactOf_effect e d newSeg s
  rw [hmove] at this
  unfold impactOf
  split
  · rfl
  · simp_all

/-- No seat moved by a flight replacement lands on a seat another passenger
holds on the new flight.

Open question for the business.  Under a reading where seats move with their
flight, a seat keeps its number on the new flight, and nothing checks the new
flight's seat map.  A passenger's paid seat 12C moves to a flight on which
another passenger already holds 12C.  The example {lit}`seatMovedOntoTakenSeat`
shows it.  What happens to a seat when its flight is replaced: does it move,
and to which seat, or is it refunded, stored or reshopped? -/
@[open_question, checks "ONE-604.4"]
theorem replace_no_seat_clash (e : ServiceKind → DependentEffect) (r : LinkReading)
    (d : ServiceDetails) (o : Order) (f : Service) (newSeg : String) (held : List SeatAssignment)
    (a : SeatAssignment) (ha : a ∈ movedSeats d (replaceFlight e r d o f newSeg))
    (b : SeatAssignment) (hb : b ∈ held) (hseg : b.segment = a.segment) (hseat : b.seat = a.seat) :
    b.passenger = a.passenger := by
  sorry

/-! ## Choosing seats -/

/-- A request that chooses a seat the seat map of its segment does not mark
available is refused. -/
@[checks "ONE-605.1"]
theorem choose_seats_refuses_unavailable (maps : List SeatMap) (d : ServiceDetails) (o : Order)
    (cs : List SeatChoice) (c : SeatChoice) (hc : c ∈ cs)
    (hmap : ∀ m ∈ maps, m.segment = c.segment → c.seat ∉ m.available) :
    ∃ e, chooseSeats maps d o cs = .error e := by
  have hcheck : checkSeat maps c ≠ none := by
    unfold checkSeat
    split
    · simp
    · rename_i m hm
      have hmem := List.mem_of_find?_eq_some hm
      have hseg : m.segment = c.segment := by simpa using List.find?_some hm
      simp [hmap m hmem hseg]
  unfold chooseSeats
  split
  · exact ⟨_, rfl⟩
  · rename_i hnone
    simp only [List.findSome?_eq_none_iff] at hnone
    exact absurd (hnone c hc) hcheck

/-- An accepted seat request keeps the existing order items and adds one item
for each seat chosen, at the seat's price, holding one service for that
passenger on that segment. -/
@[checks "ONE-605.2"]
theorem choose_seats_items (maps : List SeatMap) (d d' : ServiceDetails) (o o' : Order)
    (cs : List SeatChoice) (h : chooseSeats maps d o cs = .ok (o', d')) :
    o'.items = o.items ++ cs.map (seatItem o.id) ∧
      ∀ c ∈ cs, (seatItem o.id c).price = c.price ∧
        (seatItem o.id c).services.map (fun s => (s.passenger, s.segment)) = [(c.passenger, c.segment)] := by
  unfold chooseSeats at h
  split at h
  · cases h
  · cases h
    exact ⟨rfl, fun c _ => ⟨rfl, rfl⟩⟩

/-- When no seat is held by two passengers on a segment, and the seat maps mark
no held seat available, an accepted seat request keeps it so.

Open question for the business.  The guide checks a seat choice against the
seat map and states no rule that a seat goes to one passenger.  One request
that chooses 12B on the same flight for two passengers passes, since the seat
map marks 12B available for each choice.  The example {lit}`sameSeatTwice`
shows it.  Is a seat checked against the other choices of the same request,
against every order on the flight, or only against the seat map?  And is the
unit the passenger segment or the leg the aircraft flies? -/
@[open_question, checks "ONE-605.3"]
theorem choose_seats_one_passenger_per_seat (maps : List SeatMap) (d d' : ServiceDetails)
    (o o' : Order) (cs : List SeatChoice)
    (h0 : ∀ a ∈ seatsHeld d o, ∀ b ∈ seatsHeld d o, a.segment = b.segment → a.seat = b.seat →
      a.passenger = b.passenger)
    (hmap : ∀ a ∈ seatsHeld d o, ∀ m ∈ maps, m.segment = a.segment → a.seat ∉ m.available)
    (h : chooseSeats maps d o cs = .ok (o', d')) :
    ∀ a ∈ seatsHeld d' o', ∀ b ∈ seatsHeld d' o', a.segment = b.segment → a.seat = b.seat →
      a.passenger = b.passenger := by
  sorry

/-- When each passenger holds at most one seat on each segment, and the seat
maps mark no held seat available, an accepted seat request keeps it so.

Open question for the business.  The guide does not say whether choosing a
seat replaces a seat the passenger already holds.  A passenger who holds 12B
and chooses 14A in a second request holds both, each in its own active order
item.  The example {lit}`secondSeatSamePassenger` shows it.  May a passenger
hold an extra seat, for comfort or for a large instrument, and does choosing a
new seat cancel the old one, with what refund? -/
@[open_question, checks "ONE-605.4"]
theorem choose_seats_one_seat_per_passenger (maps : List SeatMap) (d d' : ServiceDetails)
    (o o' : Order) (cs : List SeatChoice)
    (h0 : ∀ a ∈ seatsHeld d o, ∀ b ∈ seatsHeld d o, a.passenger = b.passenger →
      a.segment = b.segment → a.seat = b.seat)
    (hmap : ∀ a ∈ seatsHeld d o, ∀ m ∈ maps, m.segment = a.segment → a.seat ∉ m.available)
    (h : chooseSeats maps d o cs = .ok (o', d')) :
    ∀ a ∈ seatsHeld d' o', ∀ b ∈ seatsHeld d' o', a.passenger = b.passenger →
      a.segment = b.segment → a.seat = b.seat := by
  sorry

/-! ## A-la-carte offer items -/

/-- An accepted a-la-carte choice gives the order items the rule's last step
makes: one for each passenger and segment chosen. -/
theorem chooseAlaCarte_ok (orderId : String) (oi : AlaCarteItem) (c : AlaCarteChoice)
    (items : List OrderItem) (h : chooseAlaCarte orderId oi c = .ok items) :
    items = (c.passengers ×ˢ c.segments).map fun (p, seg) => alaCarteOrderItem orderId oi c.quantity p seg := by
  unfold chooseAlaCarte at h
  split_ifs at h
  split at h
  · cases h
  · split at h
    · cases h
    · cases h; rfl

/-- A choice that names a passenger or a segment the offer item does not list
as eligible is refused. -/
@[checks "ONE-606.1"]
theorem alacarte_refuses_ineligible (orderId : String) (oi : AlaCarteItem) (c : AlaCarteChoice)
    (h : (∃ p ∈ c.passengers, p ∉ oi.passengers) ∨ (∃ seg ∈ c.segments, seg ∉ oi.segments))
    (items : List OrderItem) : chooseAlaCarte orderId oi c ≠ .ok items := by
  unfold chooseAlaCarte
  split_ifs
  · simp
  · split
    · simp
    · split
      · simp
      · rename_i hp _ hseg
        simp only [List.find?_eq_none] at hp hseg
        rcases h with ⟨p, hp', hn⟩ | ⟨seg, hs', hn⟩
        · exact absurd (by simpa using hn) (hp p hp')
        · exact absurd (by simpa using hn) (hseg seg hs')

/-- An accepted choice gives one order item for each pair of a passenger and a
segment chosen, each holding one service for that passenger on that
segment. -/
@[checks "ONE-606.2"]
theorem alacarte_item_per_passenger_segment (orderId : String) (oi : AlaCarteItem)
    (c : AlaCarteChoice) (items : List OrderItem) (h : chooseAlaCarte orderId oi c = .ok items) :
    items.map (·.services.map fun s => (s.passenger, s.segment)) =
      (c.passengers ×ˢ c.segments).map fun ps => [ps] := by
  rw [chooseAlaCarte_ok orderId oi c items h]
  simp [alaCarteOrderItem, Function.comp_def]

/-- Each order item of an accepted choice costs the unit price times the
quantity. -/
@[checks "ONE-606.3"]
theorem alacarte_item_price (orderId : String) (oi : AlaCarteItem) (c : AlaCarteChoice)
    (items : List OrderItem) (h : chooseAlaCarte orderId oi c = .ok items) (i : OrderItem)
    (hi : i ∈ items) : i.price = ⟨oi.unitPrice.amount * c.quantity, oi.unitPrice.currency⟩ := by
  rw [chooseAlaCarte_ok orderId oi c items h] at hi
  simp only [List.mem_map] at hi
  obtain ⟨⟨p, seg⟩, -, rfl⟩ := hi
  rfl

/-- The order items of an accepted choice cost, in total, the unit price times
the quantity times the number of passengers and segments chosen. -/
@[checks "ONE-606.4"]
theorem alacarte_total (orderId : String) (oi : AlaCarteItem) (c : AlaCarteChoice)
    (items : List OrderItem) (h : chooseAlaCarte orderId oi c = .ok items) :
    (items.map (·.price.amount)).sum =
      oi.unitPrice.amount * c.quantity * (c.passengers.length * c.segments.length) := by
  rw [chooseAlaCarte_ok orderId oi c items h]
  simp [alaCarteOrderItem, Function.comp_def, List.length_product, mul_comm]

/-- An a-la-carte offer item becomes exactly one order item, as every offer
item does when an offer is accepted.

Open question for the business.  The add bag worked example orders a 50.00 bag
at quantity 1 for one passenger over two journeys and gets two order items of
50.00, so one offer item becomes two order items and the bag costs 100.00.
The example {lit}`bagOverTwoJourneys` shows it.  Does one offer item become one
order item, as the order structure says, or one per passenger and segment, as
the worked example shows?  And what is the unit of the unit price: a passenger
on a segment, a journey, or the order? -/
@[open_question, checks "ONE-606.5"]
theorem alacarte_one_item (orderId : String) (oi : AlaCarteItem) (c : AlaCarteChoice)
    (items : List OrderItem) (h : chooseAlaCarte orderId oi c = .ok items) :
    items.length = 1 := by
  sorry

/-! ## Removing a service from a bundle -/

/-- An accepted removal leaves the order and the amount as the rule's last
step makes them, for the first item with the reference given. -/
theorem removeFromBundle_ok (mr : MoveReading) (sh : BundleShare) (o o' : Order) (item : String)
    (ids : List String) (m : Money) (h : removeFromBundle mr sh o item ids = .ok (o', m)) :
    ∃ i, o.items.find? (·.id == item) = some i ∧
      o'.items = o.items.map (fun j => if j.id == item then removeServices mr ids j else j) ∧
      m = bundleReturn mr sh i ids := by
  unfold removeFromBundle at h
  split at h
  · cases h
  · rename_i i hi
    split at h
    · cases h
    · cases h
      exact ⟨i, hi, rfl, rfl⟩

/-- After an accepted removal the bundle is in the order with its reference and
price, each named live service that the delivery status table lets be removed
CANCELLED with delivery status REMOVED, and every service that is not named as
it was, under every reading. -/
@[checks "ONE-607.1"]
theorem bundle_removes (mr : MoveReading) (sh : BundleShare) (o o' : Order) (item : String)
    (ids : List String) (m : Money) (h : removeFromBundle mr sh o item ids = .ok (o', m)) :
    ∃ i ∈ o.items, i.id = item ∧ ∃ i' ∈ o'.items, i'.id = i.id ∧ i'.price = i.price ∧
      (∀ s ∈ i.services, ids.contains s.id = true → isLive s = true →
        (nextDelivery mr .remove s).isSome →
        { s with status := .cancelled, delivery := .removed } ∈ i'.services) ∧
      ∀ s ∈ i.services, ids.contains s.id = false → s ∈ i'.services := by
  obtain ⟨i, hi, hitems, -⟩ := removeFromBundle_ok mr sh o o' item ids m h
  have hid : i.id = item := by simpa using List.find?_some hi
  refine ⟨i, List.mem_of_find?_eq_some hi, hid, removeServices mr ids i, ?_, rfl, rfl, ?_, ?_⟩
  · rw [hitems]
    exact List.mem_map.mpr ⟨i, List.mem_of_find?_eq_some hi, by simp [hid]⟩
  · intro s hs hn hlive hrem
    obtain ⟨d, hd⟩ := Option.isSome_iff_exists.mp hrem
    have hdr := Delivery.nextDelivery_remove mr s d hd
    subst hdr
    have hmem : s.id ∈ ids := by simpa using hn
    exact List.mem_map.mpr ⟨s, hs, by simp [hmem, endService, hlive, Delivery.endWith, hd]⟩
  · intro s hs hn
    have hnm : s.id ∉ ids := by simpa using hn
    exact List.mem_map.mpr ⟨s, hs, by simp [hnm]⟩

/-- An accepted removal returns the sum of the shares of the services it
cancels under the reading, in the bundle's currency: the named live services
that the delivery status table lets be removed. -/
@[checks "ONE-607.2"]
theorem bundle_returns_shares (mr : MoveReading) (sh : BundleShare) (o o' : Order) (item : String)
    (ids : List String) (m : Money) (h : removeFromBundle mr sh o item ids = .ok (o', m))
    (i : OrderItem) (hi : o.items.find? (·.id == item) = some i) :
    m = ⟨((i.services.filter fun s =>
          ids.contains s.id && isLive s && (nextDelivery mr .remove s).isSome).map (sh.share i)).sum,
      i.price.currency⟩ := by
  obtain ⟨i', hi', -, hm⟩ := removeFromBundle_ok mr sh o o' item ids m h
  rw [hi] at hi'
  cases hi'
  exact hm

/-- An accepted removal returns no more than the bundle price, under every
reading.

Open question for the business.  The guide prices a bundle only as a whole.
Under a reading that gives each service its stand-alone price, a 1,000.00 EUR
bundle of two flights at 470.00 EUR and two bags at 60.00 EUR returns
1,060.00 EUR when every service is removed.  The example
{lit}`bundleShares` shows it.  How does a bundle price split among its
services: by stated component prices, by stand-alone prices, or not at
all? -/
@[open_question, checks "ONE-607.3"]
theorem bundle_return_le_price (mr : MoveReading) (sh : BundleShare) (o o' : Order) (item : String)
    (ids : List String) (m : Money) (h : removeFromBundle mr sh o item ids = .ok (o', m)) (i : OrderItem)
    (hi : o.items.find? (·.id == item) = some i) :
    m.amount ≤ i.price.amount := by
  sorry

/-- Removing every service of a bundle, all of them live, returns the whole
bundle price, under every reading.

Open question for the business.  Under a reading that gives no share to any
service, removing a passenger's flight and bag from a 1,000.00 EUR bundle
returns nothing, and so does removing every service.  The example
{lit}`bundleShares` shows it.  Does removing part of a bundle return part of
its price, and does removing all of it return all of it? -/
@[open_question, checks "ONE-607.4"]
theorem bundle_return_all (mr : MoveReading) (sh : BundleShare) (o o' : Order) (item : String)
    (ids : List String) (m : Money) (h : removeFromBundle mr sh o item ids = .ok (o', m)) (i : OrderItem)
    (hi : o.items.find? (·.id == item) = some i)
    (hall : ∀ s ∈ i.services, s.id ∈ ids ∧ isLive s = true) :
    m.amount = i.price.amount := by
  sorry

end Rules.OneOrder.Ancillaries
