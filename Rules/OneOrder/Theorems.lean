import Rules.Core.Attributes
import Rules.OneOrder.Accept

/-!
# Guarantees

Properties the ONE Order rules are claimed to have.  A guarantee about value
holds for every reading of the guide (see {lit}`ValueReading`); one left open
is a question for the business.
-/

namespace Rules.OneOrder

open Rules.Core

/-- An accepted offer becomes an order with exactly one order item for each
offer item, and each order item records the offer item it came from. -/
@[checks "ONE-001.1"]
theorem accept_item_per_offer_item (o : Offer) (now : Instant) (orderId : String) (ord : Order)
    (h : accept o now orderId = .ok ord) :
    ord.items.map (·.fromOfferItem) = o.items.map (·.id) := by
  unfold accept at h
  split_ifs at h
  cases h
  simp [toOrderItem, Function.comp_def]

/-- Each order item gets one service for each pair of a passenger and a flight
segment of its offer item: the services' passengers and segments are exactly
those pairs, each once. -/
@[checks "ONE-001.2"]
theorem accept_services_per_passenger_segment (o : Offer) (now : Instant) (orderId : String)
    (ord : Order) (h : accept o now orderId = .ok ord) :
    ord.items.map (·.services.map fun s => (s.passenger, s.segment)) =
      o.items.map (fun oi => oi.passengers ×ˢ oi.segments) := by
  unfold accept at h
  split_ifs at h
  cases h
  simp [toOrderItem, servicesFor, Function.comp_def]

/-- When the offer's item references are distinct, the order's item references
are distinct too: each is the order reference, a hyphen and the offer item
reference. -/
@[checks "ONE-001.3"]
theorem accept_item_ids_unique (o : Offer) (now : Instant) (orderId : String) (ord : Order)
    (h : accept o now orderId = .ok ord) (hids : (o.items.map (·.id)).Nodup) :
    (ord.items.map (·.id)).Nodup := by
  unfold accept at h
  split_ifs at h
  cases h
  have : (o.items.map (toOrderItem orderId)).map (·.id) = (o.items.map (·.id)).map ((orderId ++ "-") ++ ·) := by
    simp [toOrderItem, Function.comp_def, String.append_assoc]
  rw [this]
  exact hids.map fun a b hab => (String.append_right_inj _).mp hab

/-- An offer accepted at or after its expiry instant is always rejected as
expired. -/
@[checks "ONE-001.5"]
theorem accept_rejects_expired (o : Offer) (now : Instant) (orderId : String)
    (h : now ≥ o.expiresAt) :
    accept o now orderId = .error .expired := by
  simp [accept, h]

/-- An item is marked active exactly when at least one of its services holds
value. -/
@[checks "ONE-002.1"]
theorem item_active_iff (v : ValueReading) (i : OrderItem) :
    .active ∈ itemStatuses v i ↔ ∃ s ∈ i.services, s.holdsValue v = true := by
  have hmem : .active ∈ itemStatuses v i ↔ i.isActive v = true := by
    unfold itemStatuses; split_ifs <;> simp_all
  rw [hmem]
  simp [OrderItem.isActive]

/-- An item is marked cancelled exactly when every service is cancelled or
transferred and none holds value. -/
@[checks "ONE-002.2"]
theorem item_cancelled_iff (v : ValueReading) (i : OrderItem) :
    .cancelled ∈ itemStatuses v i ↔
      (∀ s ∈ i.services, s.status = .cancelled ∨ s.status = .transferred) ∧
        ∀ s ∈ i.services, s.holdsValue v = false := by
  have hmem : .cancelled ∈ itemStatuses v i ↔ i.isCancelled v = true := by
    unfold itemStatuses; split_ifs <;> simp_all
  rw [hmem]
  simp [OrderItem.isCancelled, OrderItem.isActive]

/-- An item is marked closed exactly when at least one service is delivered and
every service is delivered or removed. -/
@[checks "ONE-002.3"]
theorem item_closed_iff (v : ValueReading) (i : OrderItem) :
    .closed ∈ itemStatuses v i ↔
      (∃ s ∈ i.services, s.delivery = .delivered) ∧
        ∀ s ∈ i.services, s.delivery = .delivered ∨ s.delivery = .removed := by
  have hmem : .closed ∈ itemStatuses v i ↔ i.isClosed = true := by
    unfold itemStatuses; split_ifs <;> simp_all
  rw [hmem]
  simp [OrderItem.isClosed]

/-- An active item is never closed, under every reading of the guide: a closed
item's services are all delivered or removed, and neither holds value. -/
@[checks "ONE-002.4"]
theorem active_not_closed (v : ValueReading) (i : OrderItem) :
    ¬ (i.isActive v = true ∧ i.isClosed = true) := by
  rintro ⟨ha, hc⟩
  simp only [OrderItem.isActive, List.any_eq_true] at ha
  obtain ⟨s, hs, hv⟩ := ha
  simp only [OrderItem.isClosed, Bool.and_eq_true, List.all_eq_true] at hc
  have := hc.2 s hs
  simp only [Bool.or_eq_true, beq_iff_eq] at this
  rcases this with h | h <;> simp [Service.holdsValue, h, v.delivered, v.removed] at hv

/-- An active item is never cancelled: the cancelled status requires that no
service holds value. -/
@[checks "ONE-002.4"]
theorem active_not_cancelled (v : ValueReading) (i : OrderItem) :
    ¬ (i.isActive v = true ∧ i.isCancelled v = true) := by
  rintro ⟨ha, hc⟩
  simp [OrderItem.isCancelled, ha] at hc

/-- Each order item has exactly one status, active, cancelled or closed.

Open question for the business.  The guide's three conditions overlap and
leave gaps.  An item whose one service was delivered and then transferred to
another item meets both the cancelled condition (every service transferred,
none holding value) and the closed condition (a service delivered, the rest
delivered or removed).  The example {lit}`deliveredThenTransferred` shows it.
Which status wins, and should a delivered service be transferable at all? -/
@[open_question, checks "ONE-002.4"]
theorem item_has_one_status (v : ValueReading) (i : OrderItem) (h : i.services ≠ []) :
    (itemStatuses v i).length = 1 := by
  sorry

/-- An order is marked opened exactly when at least one of its services holds
value. -/
@[checks "ONE-003.1"]
theorem order_opened_iff (v : ValueReading) (o : Order) :
    .opened ∈ orderStatuses v o ↔ ∃ i ∈ o.items, ∃ s ∈ i.services, s.holdsValue v = true := by
  have hmem : .opened ∈ orderStatuses v o ↔ o.isOpened v = true := by
    unfold orderStatuses; split_ifs <;> simp_all
  rw [hmem]
  simp [Order.isOpened, OrderItem.isActive]

/-- An order is marked closed exactly when every item is closed or cancelled
and every service is delivered or removed. -/
@[checks "ONE-003.2"]
theorem order_closed_iff (v : ValueReading) (o : Order) :
    .closed ∈ orderStatuses v o ↔
      (∀ i ∈ o.items, i.isClosed = true ∨ i.isCancelled v = true) ∧
        ∀ i ∈ o.items, ∀ s ∈ i.services, s.delivery = .delivered ∨ s.delivery = .removed := by
  have hmem : .closed ∈ orderStatuses v o ↔ o.isClosed v = true := by
    unfold orderStatuses; split_ifs <;> simp_all
  rw [hmem]
  simp [Order.isClosed]

/-- An order is never both opened and closed, under every reading of the
guide. -/
@[checks "ONE-003.3"]
theorem opened_closed_exclusive (v : ValueReading) (o : Order) :
    ¬ (o.isOpened v = true ∧ o.isClosed v = true) := by
  rintro ⟨ho, hc⟩
  simp only [Order.isOpened, List.any_eq_true] at ho
  obtain ⟨i, hi, ha⟩ := ho
  simp only [Order.isClosed, Bool.and_eq_true, List.all_eq_true] at hc
  simp only [OrderItem.isActive, List.any_eq_true] at ha
  obtain ⟨s, hs, hv⟩ := ha
  have := hc.2 i hi s hs
  simp only [Bool.or_eq_true, beq_iff_eq] at this
  rcases this with h | h <;> simp [Service.holdsValue, h, v.delivered, v.removed] at hv

/-- An order is created opened, under every reading of the guide, when every
offer item has a passenger and a flight segment: its services start confirmed,
and a confirmed service holds value. -/
@[checks "ONE-001.4"]
theorem accept_order_opened (v : ValueReading) (o : Offer) (now : Instant) (orderId : String)
    (ord : Order) (h : accept o now orderId = .ok ord)
    (hne : ∀ oi ∈ o.items, oi.passengers ≠ [] ∧ oi.segments ≠ []) :
    orderStatuses v ord = [.opened] := by
  have hopen : ord.isOpened v = true := by
    unfold accept at h
    split_ifs at h with hexp hempty
    cases h
    obtain ⟨oi, hoi⟩ := List.exists_mem_of_ne_nil o.items (by simpa using hempty)
    obtain ⟨p, hp⟩ := List.exists_mem_of_ne_nil _ (hne oi hoi).1
    obtain ⟨seg, hseg⟩ := List.exists_mem_of_ne_nil _ (hne oi hoi).2
    simp only [Order.isOpened, List.any_map, List.any_eq_true]
    refine ⟨oi, hoi, ?_⟩
    simp only [Function.comp_apply, OrderItem.isActive, toOrderItem, servicesFor, List.any_map,
      List.any_eq_true]
    exact ⟨(p, seg), List.mem_product.mpr ⟨hp, hseg⟩, by simp [Service.holdsValue, v.confirmed]⟩
  have hclosed : ord.isClosed v = false := by
    cases hc : ord.isClosed v
    · rfl
    · exact absurd ⟨hopen, hc⟩ (opened_closed_exclusive v ord)
  simp [orderStatuses, hopen, hclosed]

/-- Every order with at least one service is opened or closed.

Open question for the business.  The guide closes an order only when every
service is delivered or removed, and keeps it opened only while a service
holds value.  It does not say whether an expired, not claimed or failed
service holds value.  Under a reading where an expired service holds none, an
order whose only service expired is neither opened nor closed.  The example
{lit}`expiredService` shows it.  Does an expired service hold value, and
should an order with one be closed? -/
@[open_question, checks "ONE-003.4"]
theorem order_opened_or_closed (v : ValueReading) (o : Order)
    (h : o.items.any (·.services ≠ [])) :
    orderStatuses v o ≠ [] := by
  sorry

end Rules.OneOrder
