import Rules.Core.Attributes
import Rules.OneOrder.Change.Theorems
import Rules.OneOrder.AirlineChange.Theorems
import Rules.OneOrder.Ancillaries.Theorems
import Rules.OneOrder.Payment.Theorems

/-!
# Delivery statuses across the areas

Rules in four areas change a service's delivery status.  Each of them does it
through the delivery status table, and this module states that once for all of
them.  A rule that wrote a delivery status directly, as the areas did before,
would break the theorem here.
-/

namespace Rules.OneOrder

open Rules.Core
open Rules.OneOrder.Delivery

/-- The services of an order, item by item. -/
def orderServices (o : Order) : List Service := o.items.flatMap (·.services)

/-- The services of an order as the payment rules see it, item by item. -/
def payableServices (items : List Payment.PayableItem) : List Service :=
  items.flatMap (·.item.services)

/-- Cancelling an unpaid order at once moves each service along the table. -/
theorem cancelDirect_moves (m : MoveReading) (o : Order) :
    MovesAlongTable m (orderServices o) (orderServices (Change.cancelDirect m o)) := by
  unfold orderServices Change.cancelDirect
  exact movesAlongTable_flatMap m (fun (i : OrderItem) => i.services) _
    (fun i => movesAlongTable_map m _ (fun s => endWith_follows m .remove .cancelled s) _) _

/-- A change to an order item moves each service of the order's existing items
along the table. -/
theorem changeItem_moves (m : MoveReading) (o o' : Order) (c : Change.ItemChange)
    (h : Change.changeItem m o c = .ok o') :
    MovesAlongTable m (orderServices o) ((o'.items.take o.items.length).flatMap (·.services)) := by
  obtain ⟨old, -, -, rfl⟩ := Change.changeItem_ok m o o' c h
  have htake : (o.items.map (Change.afterChange m c) ++ [Change.newItemOf c old]).take o.items.length =
      o.items.map (Change.afterChange m c) := by
    simp
  simp only [htake]
  refine movesAlongTable_flatMap m (fun (i : OrderItem) => i.services) _ (fun i => ?_) _
  unfold Change.afterChange
  split_ifs
  · refine movesAlongTable_map m _ (fun s => ?_) _
    unfold Change.originalAfterChange
    split_ifs
    · exact ⟨rfl, Or.inl rfl⟩
    · exact endWith_follows m .remove .cancelled s
  · exact movesAlongTable_refl m _

/-- An airline change to an order item moves each service of the order's
existing items along the table, under both readings of when it takes
effect. -/
theorem notifyChange_moves (m : MoveReading) (a : AirlineChange.ApplyAt)
    (vo vo' : AirlineChange.VersionedOrder) (c : AirlineChange.Reaccommodation)
    (h : AirlineChange.notifyChange m a vo c = .ok vo') :
    MovesAlongTable m (orderServices vo.order)
      ((vo'.order.items.take vo.order.items.length).flatMap (·.services)) := by
  cases a with
  | acceptance =>
    rw [AirlineChange.notify_at_acceptance m vo c vo' h]
    simpa [orderServices] using movesAlongTable_refl m (orderServices vo.order)
  | notice =>
    obtain ⟨old, -, hc, -⟩ := AirlineChange.notify_at_notice m vo c vo' h
    exact changeItem_moves m vo.order vo'.order _ hc

/-- Cancelling order items moves each service of the order along the table,
under every reading. -/
theorem cancelItems_moves (m : MoveReading) (h : Ancillaries.DependentHandling)
    (r : Ancillaries.LinkReading) (d : Ancillaries.ServiceDetails) (allows : String → Bool)
    (o o' : Order) (named : List String) (hok : Ancillaries.cancelItems m h r d allows o named = .ok o') :
    MovesAlongTable m (orderServices o) (orderServices o') := by
  unfold orderServices
  rw [Ancillaries.cancelItems_ok m h r d allows o o' named hok]
  refine movesAlongTable_flatMap m (fun (i : OrderItem) => i.services) _ (fun i => ?_) _
  unfold Ancillaries.itemAfterCancel
  split_ifs
  · exact movesAlongTable_map m _ (fun s => follows_ite_endWith m .remove .cancelled isLive s) _
  · refine movesAlongTable_map m _ (fun s => ?_) _
    split_ifs
    · exact follows_ite_endWith m .remove .cancelled isLive s
    · exact follows_self m s
  · exact movesAlongTable_refl m _

/-- Removing services from a bundle moves each service of the order along the
table, under every reading. -/
theorem removeFromBundle_moves (m : MoveReading) (sh : Ancillaries.BundleShare) (o o' : Order)
    (item : String) (ids : List String) (x : Money)
    (h : Ancillaries.removeFromBundle m sh o item ids = .ok (o', x)) :
    MovesAlongTable m (orderServices o) (orderServices o') := by
  obtain ⟨-, -, hitems, -⟩ := Ancillaries.removeFromBundle_ok m sh o o' item ids x h
  unfold orderServices
  rw [hitems]
  refine movesAlongTable_flatMap m (fun (i : OrderItem) => i.services) _ (fun j => ?_) _
  split_ifs
  · refine movesAlongTable_map m _ (fun s => ?_) _
    split_ifs
    · exact follows_ite_endWith m .remove .cancelled isLive s
    · exact follows_self m s
  · exact movesAlongTable_refl m _

/-- The airline cancelling a flight moves each service of the order along the
table, under every reading. -/
theorem cancelFlight_moves (m : MoveReading) (r : AirlineChange.FlightRefund) (seg : String) (o : Order) :
    MovesAlongTable m (orderServices o) (orderServices (AirlineChange.cancelFlight m r seg o).order) := by
  unfold orderServices AirlineChange.cancelFlight
  refine movesAlongTable_flatMap m (fun (i : OrderItem) => i.services) _
    (fun i => movesAlongTable_map m _ (fun s => ?_) _) _
  unfold AirlineChange.cancelOnFlight
  split_ifs
  · exact endWith_follows m .unable .cancelled s
  · exact follows_self m s

/-- Removing unpaid items at their payment time limit moves each service of the
order along the table, under every reading. -/
theorem expireUnpaid_moves (m : MoveReading) (r : Payment.Removal) (now : Instant)
    (o : Payment.PayableOrder) :
    MovesAlongTable m (payableServices o.items) (payableServices (Payment.expireUnpaid m r now o).items) := by
  unfold payableServices Payment.expireUnpaid
  refine movesAlongTable_flatMap m (fun (pi : Payment.PayableItem) => pi.item.services) _ (fun pi => ?_) _
  split_ifs
  · exact movesAlongTable_map m _ (fun s => endWith_follows m r.event .cancelled s) _
  · exact movesAlongTable_refl m _

/-- A successful payment moves each service of the items it covers along the
table: a CONFIRMED service is paid and becomes READY TO PROCEED. -/
theorem applyOutcome_moves (m : MoveReading) (p : Payment.Transaction) (items : List Payment.PayableItem) :
    MovesAlongTable m (payableServices items) (payableServices (Payment.applyOutcome p items)) := by
  unfold payableServices Payment.applyOutcome
  split_ifs
  · refine movesAlongTable_flatMap m (fun (pi : Payment.PayableItem) => pi.item.services) _ (fun pi => ?_) _
    split_ifs
    · refine movesAlongTable_map m _ (fun s => ?_) _
      split_ifs with hc
      · exact ⟨rfl, Or.inr ⟨.pay, by simp [step, move, hc]⟩⟩
      · exact follows_self m s
    · exact movesAlongTable_refl m _
  · exact movesAlongTable_refl m _

/-- Every rule outside the Delivery area that changes a service's delivery
status moves it only along a move of the delivery status table, keeping its
reference, under every reading of the sources: cancelling an unpaid order,
changing an order item, an airline change, cancelling order items, removing
services from a bundle, the airline cancelling a flight, removing unpaid items
at their payment time limit, and a successful payment. -/
@[checks "ONE-105.3"]
theorem delivery_moves_follow_table (m : MoveReading) :
    (∀ o, MovesAlongTable m (orderServices o) (orderServices (Change.cancelDirect m o))) ∧
    (∀ o o' c, Change.changeItem m o c = .ok o' →
      MovesAlongTable m (orderServices o) ((o'.items.take o.items.length).flatMap (·.services))) ∧
    (∀ a vo vo' c, AirlineChange.notifyChange m a vo c = .ok vo' →
      MovesAlongTable m (orderServices vo.order)
        ((vo'.order.items.take vo.order.items.length).flatMap (·.services))) ∧
    (∀ h r d allows o o' named, Ancillaries.cancelItems m h r d allows o named = .ok o' →
      MovesAlongTable m (orderServices o) (orderServices o')) ∧
    (∀ sh o o' item ids x, Ancillaries.removeFromBundle m sh o item ids = .ok (o', x) →
      MovesAlongTable m (orderServices o) (orderServices o')) ∧
    (∀ r seg o, MovesAlongTable m (orderServices o)
      (orderServices (AirlineChange.cancelFlight m r seg o).order)) ∧
    (∀ r now o, MovesAlongTable m (payableServices o.items)
      (payableServices (Payment.expireUnpaid m r now o).items)) ∧
    (∀ p items, MovesAlongTable m (payableServices items)
      (payableServices (Payment.applyOutcome p items))) :=
  ⟨cancelDirect_moves m, changeItem_moves m, notifyChange_moves m, cancelItems_moves m,
    removeFromBundle_moves m, cancelFlight_moves m, expireUnpaid_moves m, applyOutcome_moves m⟩

end Rules.OneOrder
