import Rules.Core.Attributes
import Rules.OfferOrder.Order
import Rules.OneOrder.Theorems
import Rules.OneOrder.Delivery.Moves

/-!
# Guarantees about delivery statuses

Properties the delivery status rules are claimed to have.  A guarantee about
moves holds for every reading of the sources (see {lit}`MoveReading`), and a
guarantee about value for every reading of the guide (see {lit}`ValueReading`);
one left open is a question for the business.
-/

namespace Rules.OneOrder.Delivery

open Rules.Core

/-! ## Moves between delivery statuses -/

/-- A REQUESTED service the airline confirms becomes CONFIRMED, under every
reading. -/
@[checks "ONE-101.1"]
theorem confirm_marks_confirmed (m : MoveReading) : move m .requested .confirm = some .confirmed :=
  rfl

/-- A CONFIRMED service whose payment succeeds becomes READY TO PROCEED, under
every reading. -/
@[checks "ONE-101.2"]
theorem pay_marks_ready (m : MoveReading) : move m .confirmed .pay = some .readyToProceed :=
  rfl

/-- A service that is READY TO PROCEED, READY TO DELIVER or IN PROGRESS becomes
DELIVERED when it is delivered, under every reading.  READY TO DELIVER and IN
PROGRESS may be skipped. -/
@[checks "ONE-101.3"]
theorem deliver_marks_delivered (m : MoveReading) (s : DeliveryStatus)
    (hs : s = .readyToProceed ∨ s = .readyToDeliver ∨ s = .inProgress) :
    move m s .deliver = some .delivered := by
  rcases hs with rfl | rfl | rfl <;> rfl

/-- The statuses a service can be in while no payment for it has succeeded,
under a reading that refuses delivery before payment and the return from
UNABLE TO DELIVER. -/
private def unpaid : DeliveryStatus → Bool
  | .requested | .confirmed | .removed | .removedHoldValue | .expired | .notClaimed
  | .unableToDeliver | .failedToDeliver => true
  | _ => false

private def Unpaid (r : DeliveryRecord) : Prop :=
  unpaid r.status = true ∨ (r.status = .suspended ∧ ∀ s, r.suspendedFrom = some s → unpaid s = true)

private theorem step_unpaid (m : MoveReading) (hd : m.deliverBeforePayment = false)
    (hu : m.unableReturns = false) (r : DeliveryRecord) (e : DeliveryEvent)
    (he : ¬ (e = .pay ∧ (step m r e).isSome = true)) (h : Unpaid r) :
    Unpaid ((step m r e).getD r) := by
  obtain ⟨s, o⟩ := r
  rcases o with _ | x <;> cases s <;> cases e <;>
    simp_all [Unpaid, unpaid, step, move, endService, endBeforeDelivery, suspendable, isFinal]

private theorem run_unpaid (m : MoveReading) (hd : m.deliverBeforePayment = false)
    (hu : m.unableReturns = false) (r : DeliveryRecord) (es : List DeliveryEvent)
    (hpay : paymentSucceeds m r es = false) (h : Unpaid r) : Unpaid (run m r es) := by
  induction es generalizing r with
  | nil => simpa [run] using h
  | cons e es ih =>
    simp only [paymentSucceeds, Bool.or_eq_false_iff, Bool.and_eq_false_iff, beq_eq_false_iff_ne] at hpay
    refine ih _ hpay.2 (step_unpaid m hd hu r e ?_ h)
    rintro ⟨rfl, hs⟩
    rcases hpay.1 with h' | h'
    · exact h' rfl
    · simp [h'] at hs

/-- A service that starts REQUESTED or CONFIRMED never reaches READY TO PROCEED,
READY TO DELIVER, IN PROGRESS or DELIVERED while no payment for it has
succeeded, whatever other events happen to it.

Open question for the business.  The sources treat READY TO PROCEED as the
payment gate but never forbid delivery from CONFIRMED, and they do not say
whether an UNABLE TO DELIVER service returns to READY TO PROCEED once the
constraint lifts.  Under a reading that allows either move, a service nobody
paid for is delivered.  The examples {lit}`deliveredBeforePayment` and
{lit}`unpaidAfterForceMajeure` show it.  May delivery start before payment,
and when an UNABLE TO DELIVER service can be delivered again, does it return
to the status it left or to READY TO PROCEED? -/
@[open_question, checks "ONE-101.4"]
theorem paid_before_delivery (m : MoveReading) (s : DeliveryStatus) (es : List DeliveryEvent)
    (hs : s = .requested ∨ s = .confirmed) (hpay : paymentSucceeds m ⟨s, none⟩ es = false) :
    (run m ⟨s, none⟩ es).status ∉
      [DeliveryStatus.readyToProceed, .readyToDeliver, .inProgress, .delivered] := by
  sorry

/-- Under every reading that refuses delivery before payment and keeps an
UNABLE TO DELIVER service from returning to READY TO PROCEED, a service that
starts REQUESTED or CONFIRMED never reaches READY TO PROCEED, READY TO DELIVER,
IN PROGRESS or DELIVERED while no payment for it has succeeded. -/
@[checks "ONE-101.5"]
theorem paid_before_delivery_with_gate (m : MoveReading) (hd : m.deliverBeforePayment = false)
    (hu : m.unableReturns = false) (s : DeliveryStatus) (es : List DeliveryEvent)
    (hs : s = .requested ∨ s = .confirmed) (hpay : paymentSucceeds m ⟨s, none⟩ es = false) :
    (run m ⟨s, none⟩ es).status ∉
      [DeliveryStatus.readyToProceed, .readyToDeliver, .inProgress, .delivered] := by
  have h := run_unpaid m hd hu ⟨s, none⟩ es hpay (by rcases hs with rfl | rfl <;> simp [Unpaid, unpaid])
  generalize run m ⟨s, none⟩ es = r at h
  obtain ⟨t, o⟩ := r
  rcases h with h | ⟨h, -⟩ <;> cases t <;> simp_all [unpaid]

/-! ## Services that end without delivery -/

/-- A service that is CONFIRMED, READY TO PROCEED or READY TO DELIVER becomes
REMOVED when it is cancelled with none of its value kept, and REMOVED HOLD
VALUE when the airline holds its value, under every reading. -/
@[checks "ONE-102.1"]
theorem cancel_removes (m : MoveReading) (s : DeliveryStatus)
    (hs : s = .confirmed ∨ s = .readyToProceed ∨ s = .readyToDeliver) :
    move m s .remove = some .removed ∧ move m s .removeHoldValue = some .removedHoldValue := by
  rcases hs with rfl | rfl | rfl <;> exact ⟨rfl, rfl⟩

/-- The only event a REMOVED HOLD VALUE service accepts is the release of its
value, which makes it REMOVED, under every reading. -/
@[checks "ONE-102.2"]
theorem held_value_only_released (m : MoveReading) (before : Option DeliveryStatus)
    (e : DeliveryEvent) (r : DeliveryRecord) :
    step m ⟨.removedHoldValue, before⟩ e = some r ↔ e = .releaseValue ∧ r = ⟨.removed, none⟩ := by
  cases e <;> simp [step, move, endService, suspendable, isFinal, eq_comm]

/-- A service that is CONFIRMED, READY TO PROCEED or READY TO DELIVER becomes
EXPIRED when its consumption time limit passes, under every reading. -/
@[checks "ONE-102.3"]
theorem expire_marks_expired (m : MoveReading) (s : DeliveryStatus)
    (hs : s = .confirmed ∨ s = .readyToProceed ∨ s = .readyToDeliver) :
    move m s .expire = some .expired := by
  rcases hs with rfl | rfl | rfl <;> rfl

/-- A service that is CONFIRMED, READY TO PROCEED or READY TO DELIVER becomes
NOT CLAIMED when the passenger prevents its delivery, under every reading. -/
@[checks "ONE-102.4"]
theorem no_show_marks_not_claimed (m : MoveReading) (s : DeliveryStatus)
    (hs : s = .confirmed ∨ s = .readyToProceed ∨ s = .readyToDeliver) :
    move m s .notClaimed = some .notClaimed := by
  rcases hs with rfl | rfl | rfl <;> rfl

/-- A service that is CONFIRMED, READY TO PROCEED or READY TO DELIVER becomes
UNABLE TO DELIVER when legal, regulatory or force majeure constraints prevent
its delivery, under every reading. -/
@[checks "ONE-102.5"]
theorem unable_marks_unable (m : MoveReading) (s : DeliveryStatus)
    (hs : s = .confirmed ∨ s = .readyToProceed ∨ s = .readyToDeliver) :
    move m s .unable = some .unableToDeliver := by
  rcases hs with rfl | rfl | rfl <;> rfl

/-- A service that is CONFIRMED, READY TO PROCEED, READY TO DELIVER or IN
PROGRESS becomes FAILED TO DELIVER when the airline or its provider fails to
deliver it, under every reading. -/
@[checks "ONE-102.6"]
theorem fail_marks_failed (m : MoveReading) (s : DeliveryStatus)
    (hs : s = .confirmed ∨ s = .readyToProceed ∨ s = .readyToDeliver ∨ s = .inProgress) :
    move m s .fail = some .failedToDeliver := by
  rcases hs with rfl | rfl | rfl | rfl <;> rfl

/-! ## Final delivery statuses -/

/-- No event moves a service out of a final delivery status, under every
reading: not a delivery, a cancellation or a suspension. -/
@[checks "ONE-103.1"]
theorem final_refuses_all (m : MoveReading) (r : DeliveryRecord) (e : DeliveryEvent)
    (h : isFinal r.status = true) : step m r e = none := by
  obtain ⟨s, o⟩ := r
  cases s <;> simp [isFinal] at h <;> cases e <;> rfl

/-- Every service that is not in a final delivery status can reach one, under
every reading.  For an UNABLE TO DELIVER service, under a reading where it does
not return to READY TO PROCEED, the only way is to suspend it and then remove
it. -/
@[checks "ONE-103.2"]
theorem final_reachable (m : MoveReading) (r : DeliveryRecord) (h : isFinal r.status = false) :
    ∃ es, isFinal (run m r es).status = true := by
  obtain ⟨s, o⟩ := r
  cases s <;> simp [isFinal] at h
  all_goals first
    | exact ⟨[.suspend, .remove], rfl⟩
    | exact ⟨[.releaseValue], rfl⟩

/-- No event changes the delivery status of a service in a closed order, under
every reading of the sources and of the guide: a closed order's services are
all DELIVERED or REMOVED, and both are final. -/
@[checks "ONE-103.3"]
theorem closed_order_refuses_events (m : MoveReading) (v : ValueReading) (o : Order)
    (h : OrderStatus.closed ∈ orderStatuses v o) (i : OrderItem) (hi : i ∈ o.items)
    (s : Service) (hs : s ∈ i.services) (before : Option DeliveryStatus) (e : DeliveryEvent) :
    step m ⟨s.delivery, before⟩ e = none := by
  apply final_refuses_all
  rcases ((order_closed_iff v o).mp h).2 i hi s hs with h' | h' <;> simp [h', isFinal]

/-- An order whose services have all reached a final delivery status is closed,
under every reading of the guide.

Open question for the business.  The guide closes an order only when every
service is DELIVERED or REMOVED.  EXPIRED, NOT CLAIMED and FAILED TO DELIVER
are final too, but an order whose services end in them is never closed.  Under
a reading where such a service holds value the order stays opened for good;
under one where it holds none the order has no status.  The examples
{lit}`noShowOrder` and {lit}`failedDeliveryOrder` show it.  Should an order
close once every service is final, and do EXPIRED, NOT CLAIMED and FAILED TO
DELIVER hold value? -/
@[open_question, checks "ONE-103.4"]
theorem all_final_order_closed (v : ValueReading) (o : Order)
    (hne : ∃ i ∈ o.items, i.services ≠ [])
    (h : ∀ i ∈ o.items, ∀ s ∈ i.services, isFinal s.delivery = true) :
    orderStatuses v o = [.closed] := by
  sorry

/-! ## Suspended services -/

/-- The airline can suspend a service in any status that is not final, except
REMOVED HOLD VALUE, and the record keeps the status it left, under every
reading. -/
@[checks "ONE-104.1"]
theorem suspend_records_status (m : MoveReading) (s : DeliveryStatus)
    (before : Option DeliveryStatus) (hs : suspendable s = true) :
    step m ⟨s, before⟩ .suspend = some ⟨.suspended, some s⟩ := by
  cases s <;> simp_all [step, suspendable, isFinal]

/-- A suspended service whose suspension is lifted returns to the delivery
status it had when it was suspended, whatever other events arrived while it
was suspended, under every reading. -/
@[checks "ONE-104.2"]
theorem resume_returns (m : MoveReading) (s : DeliveryStatus) (before : Option DeliveryStatus)
    (hs : suspendable s = true) (es : List DeliveryEvent)
    (hes : ∀ e ∈ es, e ≠ .resume ∧ e ≠ .remove) :
    step m (run m ((step m ⟨s, before⟩ .suspend).getD ⟨s, before⟩) es) .resume =
      some ⟨s, none⟩ := by
  rw [suspend_records_status m s before hs, Option.getD_some]
  suffices run m ⟨.suspended, some s⟩ es = ⟨.suspended, some s⟩ by rw [this]; rfl
  induction es with
  | nil => rfl
  | cons e es ih =>
    obtain ⟨h1, h2⟩ := hes e List.mem_cons_self
    have : step m ⟨.suspended, some s⟩ e = none := by
      cases e <;> first | rfl | contradiction
    simp only [run, this, Option.getD_none]
    exact ih fun e' he' => hes e' (List.mem_cons_of_mem _ he')

/-- A suspended service that is cancelled becomes REMOVED, under every
reading. -/
@[checks "ONE-104.3"]
theorem suspended_cancel_removes (m : MoveReading) (before : Option DeliveryStatus) :
    step m ⟨.suspended, before⟩ .remove = some ⟨.removed, none⟩ :=
  rfl

/-- A suspended service moves only to the delivery status it had before it was
suspended, or to REMOVED, under every reading. -/
@[checks "ONE-104.4"]
theorem suspended_moves_back_or_removed (m : MoveReading) (r r' : DeliveryRecord)
    (e : DeliveryEvent) (hs : r.status = .suspended) (h : step m r e = some r') :
    r'.status = .removed ∨ some r'.status = r.suspendedFrom := by
  obtain ⟨s, o⟩ := r
  simp only at hs
  subst hs
  cases e <;> simp [step] at h
  · subst h
    simp
  · obtain ⟨x, rfl, rfl⟩ := h
    simp

/-- An event other than a suspension follows the delivery status table for a
service that is not suspended, under every reading. -/
@[checks "ONE-104.5"]
theorem step_follows_table (m : MoveReading) (s : DeliveryStatus) (before : Option DeliveryStatus)
    (e : DeliveryEvent) (hs : s ≠ .suspended) (he : e ≠ .suspend) :
    step m ⟨s, before⟩ e = (move m s e).map fun s' => ⟨s', none⟩ := by
  cases s <;> cases e <;> first | rfl | contradiction

/-! ## The pilot's delivery states -/

/-- The pilot's delivery states as ONE Order delivery statuses: ready is READY
TO PROCEED, a cancelled service waiting for its refund is REMOVED HOLD VALUE,
and refunded is REMOVED. -/
def fromPilotState : Rules.OfferOrder.DeliveryState → DeliveryStatus
  | .ready => .readyToProceed
  | .delivered => .delivered
  | .cancelled => .removedHoldValue
  | .refunded => .removed

/-- The pilot's delivery events as ONE Order events: a cancellation holds the
service's value until the refund releases it. -/
def fromPilotEvent : Rules.OfferOrder.DeliveryEvent → DeliveryEvent
  | .deliver => .deliver
  | .cancel => .removeHoldValue
  | .refund => .releaseValue

/-- The pilot's transitions are the ONE Order moves between the matching
statuses, under every reading: each pilot move is a ONE Order move, and each
event the pilot refuses is refused by the ONE Order table too. -/
theorem pilot_step_within_table (m : MoveReading) (s : Rules.OfferOrder.DeliveryState)
    (e : Rules.OfferOrder.DeliveryEvent) :
    (Rules.OfferOrder.step s e).map fromPilotState = move m (fromPilotState s) (fromPilotEvent e) := by
  cases s <;> cases e <;> rfl

end Rules.OneOrder.Delivery
