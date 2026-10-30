import Rules.Core.Attributes
import Rules.OneOrder.Theorems
import Rules.OneOrder.Change.Cancel
import Rules.OneOrder.Creation.Create
import Rules.OneOrder.Creation.Repeat
import Rules.OneOrder.Creation.Version
import Rules.OneOrder.Creation.Retention

/-!
# Guarantees of the order creation rules

Properties the order creation, version and retention rules are claimed to
have.  A guarantee that depends on a reading of the sources holds under every
reading; one left open is a question for the business.
-/

namespace Rules.OneOrder.Creation

open Rules.Core

/-! ## Selecting offer items -/

/-- What an accepted selection takes: the offer items it names, every name an
item of the offer, and every mandatory item named. -/
theorem selectItems_ok (o : MarkedOffer) (sel : List String) (items : List OfferItem)
    (h : selectItems o sel = .ok items) :
    items = o.offer.items.filter (fun oi => sel.contains oi.id) ∧
      (∀ id ∈ sel, ∃ oi ∈ o.offer.items, oi.id = id) ∧ ∀ id ∈ o.mandatory, id ∈ sel := by
  unfold selectItems at h
  split at h
  · cases h
  · rename_i hu
    split at h
    · cases h
    · rename_i hm
      cases h
      refine ⟨rfl, ?_, ?_⟩
      · intro id hid
        have := List.find?_eq_none.mp hu id hid
        simpa using this
      · intro id hid
        have := List.find?_eq_none.mp hm id hid
        simpa using this

/-- A selection that names an item the offer does not hold is rejected. -/
@[checks "ONE-401.1"]
theorem select_rejects_unknown (o : MarkedOffer) (sel : List String) (id : String) (hid : id ∈ sel)
    (hnot : ∀ oi ∈ o.offer.items, oi.id ≠ id) :
    ∃ e, selectItems o sel = .error e := by
  cases h : selectItems o sel with
  | error e => exact ⟨e, rfl⟩
  | ok items =>
    obtain ⟨-, hall, -⟩ := selectItems_ok o sel items h
    obtain ⟨oi, hoi, heq⟩ := hall id hid
    exact absurd heq (hnot oi hoi)

/-- A selection that leaves out an item the offer marks mandatory is
rejected. -/
@[checks "ONE-401.2"]
theorem select_rejects_missing_mandatory (o : MarkedOffer) (sel : List String) (id : String)
    (hm : id ∈ o.mandatory) (hnot : id ∉ sel) :
    ∃ e, selectItems o sel = .error e := by
  cases h : selectItems o sel with
  | error e => exact ⟨e, rfl⟩
  | ok items =>
    obtain ⟨-, -, hmand⟩ := selectItems_ok o sel items h
    exact absurd (hmand id hm) hnot

/-- An accepted selection takes exactly the offer items whose references it
names, and every reference it names is an item it takes. -/
@[checks "ONE-401.3"]
theorem select_takes_named_items (o : MarkedOffer) (sel : List String) (items : List OfferItem)
    (h : selectItems o sel = .ok items) :
    (∀ oi, oi ∈ items ↔ oi ∈ o.offer.items ∧ oi.id ∈ sel) ∧ ∀ id ∈ sel, ∃ oi ∈ items, oi.id = id := by
  obtain ⟨rfl, hall, -⟩ := selectItems_ok o sel items h
  refine ⟨fun oi => by simp, fun id hid => ?_⟩
  obtain ⟨oi, hoi, rfl⟩ := hall id hid
  exact ⟨oi, by simp [hoi, hid], rfl⟩

/-- When an offer marks at least one item mandatory, every accepted selection
includes one. -/
theorem select_includes_mandatory_of_marked (o : MarkedOffer) (sel : List String)
    (items : List OfferItem) (h : selectItems o sel = .ok items) (hm : o.mandatory ≠ []) :
    ∃ oi ∈ items, oi.id ∈ o.mandatory := by
  obtain ⟨rfl, hall, hmand⟩ := selectItems_ok o sel items h
  obtain ⟨id, hid⟩ := List.exists_mem_of_ne_nil _ hm
  obtain ⟨oi, hoi, rfl⟩ := hall id (hmand id hid)
  exact ⟨oi, by simp [hoi, hmand oi.id hid], hid⟩

/-- Every accepted selection includes at least one item the offer marks
mandatory.

Open question for the business.  The guidance asks for at least one mandatory
item in each offer and exempts a la carte offers.  When an offer marks no item
mandatory, every selection of its items is accepted, so a seat can be ordered
without the flight it belongs to.  The example {lit}`seatWithoutFlight` shows
it.  Which selections are allowed from an offer that marks no item mandatory,
and may a seat or a bag be ordered without its flight? -/
@[open_question, checks "ONE-401.4"]
theorem select_includes_mandatory (o : MarkedOffer) (sel : List String) (items : List OfferItem)
    (h : selectItems o sel = .ok items) :
    ∃ oi ∈ items, oi.id ∈ o.mandatory := by
  sorry

/-! ## Creating an order from several offers -/

/-- The order items one accepted selection becomes: its selected items, each
priced in the currency of the offer it names. -/
theorem orderItemsFor_ok (offers : List MarkedOffer) (now : Instant) (orderId : String)
    (s : Selection) (items : List OrderItem) (h : orderItemsFor offers now orderId s = .ok items) :
    items = (selectedFrom offers s).map (toOrderItem (itemPrefix orderId s.offer)) ∧
      ∀ oi ∈ selectedFrom offers s, ∃ o ∈ offers, o.offer.id = s.offer ∧
        oi.price.currency = o.offer.currency := by
  unfold orderItemsFor at h
  split at h
  · cases h
  · rename_i o ho
    split_ifs at h with hexp
    split at h
    · cases h
    · rename_i sel hsel
      split_ifs at h with hcur
      cases h
      obtain ⟨rfl, -, -⟩ := selectItems_ok o s.items sel hsel
      have hmem := List.mem_of_find?_eq_some ho
      have hid : o.offer.id = s.offer := by simpa using List.find?_some ho
      refine ⟨by simp [selectedFrom, ho], ?_⟩
      intro oi hoi
      simp only [selectedFrom, ho] at hoi
      refine ⟨o, hmem, hid, ?_⟩
      simp only [Bool.not_eq_true, List.any_eq_false, bne_iff_ne, ne_eq, Decidable.not_not] at hcur
      exact hcur oi hoi

/-- The order items of an accepted request: the selected items of each
selection in turn, each priced in the currency of the offer it came from. -/
theorem orderItemsForAll_ok (offers : List MarkedOffer) (now : Instant) (orderId : String)
    (req : List Selection) (items : List OrderItem)
    (h : orderItemsForAll offers now orderId req = .ok items) :
    items = req.flatMap (fun s => (selectedFrom offers s).map (toOrderItem (itemPrefix orderId s.offer))) ∧
      ∀ s ∈ req, ∀ oi ∈ selectedFrom offers s, ∃ o ∈ offers, o.offer.id = s.offer ∧
        oi.price.currency = o.offer.currency := by
  induction req generalizing items with
  | nil => cases h; simp
  | cons s rest ih =>
    simp only [orderItemsForAll] at h
    split at h
    · cases h
    · cases h
    · rename_i a b is more ha hb
      cases h
      obtain ⟨rfl, hcur⟩ := orderItemsFor_ok offers now orderId s is ha
      obtain ⟨rfl, hcurs⟩ := ih more hb
      refine ⟨by simp, ?_⟩
      intro s' hs'
      rcases List.mem_cons.mp hs' with rfl | hs'
      · exact hcur
      · exact hcurs s' hs'

/-- A request with a rejected selection is rejected as a whole. -/
theorem orderItemsForAll_error (offers : List MarkedOffer) (now : Instant) (orderId : String)
    (req : List Selection) (s : Selection) (hs : s ∈ req) (e : CreateRejection)
    (he : orderItemsFor offers now orderId s = .error e) :
    ∃ e', orderItemsForAll offers now orderId req = .error e' := by
  induction req with
  | nil => cases hs
  | cons t rest ih =>
    simp only [orderItemsForAll]
    rcases List.mem_cons.mp hs with rfl | hs'
    · rw [he]; exact ⟨e, rfl⟩
    · obtain ⟨e', he'⟩ := ih hs'
      rw [he']
      cases orderItemsFor offers now orderId t <;> exact ⟨_, rfl⟩

/-- What an accepted request became: the order items of every selection, at
least one, in an order with the reference and instant given. -/
theorem createOrder_ok (offers : List MarkedOffer) (req : List Selection) (now : Instant)
    (orderId : String) (ord : Order) (h : createOrder offers req now orderId = .ok ord) :
    ∃ items, orderItemsForAll offers now orderId req = .ok items ∧ items ≠ [] ∧
      ord = { id := orderId, items, createdAt := now } := by
  unfold createOrder at h
  split at h
  · cases h
  · cases h
  · rename_i items hne hitems
    cases h
    exact ⟨items, hitems, hne, rfl⟩

/-- An accepted request becomes an order whose items are, for each selection
in turn, the items it selects from its offer and no others. -/
@[checks "ONE-402.1"]
theorem create_items_match_selection (offers : List MarkedOffer) (req : List Selection) (now : Instant)
    (orderId : String) (ord : Order) (h : createOrder offers req now orderId = .ok ord) :
    ord.items = req.flatMap (fun s => (selectedFrom offers s).map (toOrderItem (itemPrefix orderId s.offer))) ∧
      ∀ s ∈ req, ∀ oi, oi ∈ selectedFrom offers s ↔
        ∃ o, offers.find? (·.offer.id == s.offer) = some o ∧ oi ∈ o.offer.items ∧ oi.id ∈ s.items := by
  refine ⟨?_, fun s _ oi => ?_⟩
  · obtain ⟨items, hitems, -, rfl⟩ := createOrder_ok offers req now orderId ord h
    exact (orderItemsForAll_ok offers now orderId req items hitems).1
  · unfold selectedFrom
    split
    · rename_i o ho
      simp [ho]
    · rename_i hnone
      simp [hnone]

/-- An order created from offers priced in one currency has a total in that
currency: the sum of the prices of the selected items. -/
@[checks "ONE-402.2"]
theorem create_price_eq_sum (offers : List MarkedOffer) (req : List Selection) (now : Instant)
    (orderId : String) (ord : Order) (c : Currency) (h : createOrder offers req now orderId = .ok ord)
    (hc : ∀ s ∈ req, ∀ o ∈ offers, o.offer.id = s.offer → o.offer.currency = c) :
    Change.orderPrice ord c = some ⟨((req.flatMap (selectedFrom offers)).map (·.price.amount)).sum, c⟩ := by
  obtain ⟨items, hitems, -, rfl⟩ := createOrder_ok offers req now orderId ord h
  obtain ⟨rfl, hcur⟩ := orderItemsForAll_ok offers now orderId req items hitems
  have hall : (req.flatMap (fun s => (selectedFrom offers s).map
      (toOrderItem (itemPrefix orderId s.offer)))).all (·.price.currency == c) = true := by
    simp only [List.all_eq_true, List.mem_flatMap, List.mem_map, beq_iff_eq]
    rintro i ⟨s, hs, oi, hoi, rfl⟩
    obtain ⟨o, ho, hid, hoc⟩ := hcur s hs oi hoi
    simp [toOrderItem, hoc, hc s hs o ho hid]
  simp only [Change.orderPrice, hall, ↓reduceIte, List.map_flatMap]
  simp [toOrderItem, Function.comp_def]

/-- A request that names an offer which has expired at the instant of the
request is rejected as a whole: no order is created. -/
@[checks "ONE-402.3"]
theorem create_rejects_expired (offers : List MarkedOffer) (req : List Selection) (now : Instant)
    (orderId : String) (s : Selection) (hs : s ∈ req) (o : MarkedOffer)
    (ho : offers.find? (·.offer.id == s.offer) = some o) (hexp : now ≥ o.offer.expiresAt) :
    ∃ e, createOrder offers req now orderId = .error e := by
  have he : orderItemsFor offers now orderId s = .error (.expired s.offer) := by
    simp [orderItemsFor, ho, hexp]
  obtain ⟨e, he'⟩ := orderItemsForAll_error offers now orderId req s hs _ he
  exact ⟨e, by simp [createOrder, he']⟩

/-- A request that selects no item from any offer is rejected. -/
@[checks "ONE-402.4"]
theorem create_rejects_empty (offers : List MarkedOffer) (req : List Selection) (now : Instant)
    (orderId : String) (hempty : ∀ s ∈ req, selectedFrom offers s = []) :
    ∃ e, createOrder offers req now orderId = .error e := by
  cases hall : orderItemsForAll offers now orderId req with
  | error e => exact ⟨e, by simp [createOrder, hall]⟩
  | ok items =>
    obtain ⟨rfl, -⟩ := orderItemsForAll_ok offers now orderId req items hall
    have : req.flatMap (fun s => (selectedFrom offers s).map (toOrderItem (itemPrefix orderId s.offer))) = [] := by
      simp only [List.flatMap_eq_nil_iff, List.map_eq_nil_iff]
      exact hempty
    exact ⟨.noItems, by simp [createOrder, hall, this]⟩

/-- Every order created has a total price in a single currency.

Open question for the business.  Each offer is checked for its own currency,
and a request may select from offers priced in different currencies.  The
order then holds items in two currencies, and its item prices have no sum.
The example {lit}`twoCurrencies` shows it: a flight priced in EUR and a hotel
transfer priced in USD go into one order that has no total.  May one order
hold items priced in more than one currency, and if so, what is its total? -/
@[open_question, checks "ONE-402.5"]
theorem create_single_currency (offers : List MarkedOffer) (req : List Selection) (now : Instant)
    (orderId : String) (ord : Order) (h : createOrder offers req now orderId = .ok ord) :
    ∃ c, (Change.orderPrice ord c).isSome := by
  sorry

/-! ## Repeated create requests -/

/-- A request that names no offer with an order gets the order
{name}`createOrder` creates, recorded against every offer it names, under
every reading. -/
@[checks "ONE-403.1"]
theorem create_once_records (hd : RepeatHandling) (book : List CreatedOrder) (offers : List MarkedOffer)
    (req : List Selection) (now : Instant) (orderId : String) (ord : Order) (book' : List CreatedOrder)
    (hfresh : ∀ e ∈ book, e.fromAny req = false)
    (h : createOnce hd book offers req now orderId = .ok (ord, book')) :
    createOrder offers req now orderId = .ok ord ∧ book' = book ++ [⟨req.map (·.offer), ord⟩] := by
  have hnone : book.find? (·.fromAny req) = none :=
    List.find?_eq_none.mpr fun e he => by simp [hfresh e he]
  simp only [createOnce, hnone] at h
  cases hc : createOrder offers req now orderId with
  | error e => simp [hc, Except.map] at h
  | ok o =>
    simp only [hc, Except.map] at h
    cases h
    exact ⟨rfl, rfl⟩

/-- Where the airline returns the existing order, a request that names an
offer with an order is answered with an order recorded for one of the offers
it names, and nothing new is recorded. -/
@[checks "ONE-403.2"]
theorem repeat_returns_existing (book : List CreatedOrder) (offers : List MarkedOffer)
    (req : List Selection) (now : Instant) (orderId : String)
    (hused : ∃ e ∈ book, e.fromAny req = true) :
    ∃ e ∈ book, e.fromAny req = true ∧
      createOnce .returnExisting book offers req now orderId = .ok (e.order, book) := by
  cases hf : book.find? (·.fromAny req) with
  | none =>
    obtain ⟨e, he, hany⟩ := hused
    exact absurd hany (by simpa using List.find?_eq_none.mp hf e he)
  | some e =>
    exact ⟨e, List.mem_of_find?_eq_some hf, List.find?_some hf, by simp [createOnce, hf]⟩

/-- Where the airline rejects repeated requests, a request that names an offer
with an order is rejected. -/
@[checks "ONE-403.3"]
theorem repeat_rejected (book : List CreatedOrder) (offers : List MarkedOffer)
    (req : List Selection) (now : Instant) (orderId : String)
    (hused : ∃ e ∈ book, e.fromAny req = true) :
    ∃ r, createOnce .reject book offers req now orderId = .error r := by
  cases hf : book.find? (·.fromAny req) with
  | none =>
    obtain ⟨e, he, hany⟩ := hused
    exact absurd hany (by simpa using List.find?_eq_none.mp hf e he)
  | some e => exact ⟨.offerUsed e.order.id, by simp [createOnce, hf]⟩

/-- Under the readings that return the existing order or reject the request,
no offer ever appears in two recorded orders. -/
theorem once_per_offer_of_ne (hd : RepeatHandling) (hne : hd ≠ .createAgain) (book : List CreatedOrder)
    (offers : List MarkedOffer) (req : List Selection) (now : Instant) (orderId : String) (ord : Order)
    (book' : List CreatedOrder) (hbook : OncePerOffer book)
    (h : createOnce hd book offers req now orderId = .ok (ord, book')) :
    OncePerOffer book' := by
  cases hf : book.find? (·.fromAny req) with
  | some e =>
    cases hd with
    | returnExisting =>
      simp only [createOnce, hf] at h
      cases h
      exact hbook
    | reject => simp [createOnce, hf] at h
    | createAgain => exact absurd rfl hne
  | none =>
    have hfresh : ∀ e ∈ book, e.fromAny req = false := fun e he => by
      simpa using List.find?_eq_none.mp hf e he
    obtain ⟨-, rfl⟩ := create_once_records hd book offers req now orderId ord book' hfresh h
    intro offer
    rw [List.filter_append, List.length_append]
    by_cases hin : (req.map (·.offer)).contains offer = true
    · have hzero : book.filter (fun e => e.offers.contains offer) = [] := by
        rw [List.filter_eq_nil_iff]
        intro e he hc
        have := hfresh e he
        simp only [CreatedOrder.fromAny, List.any_eq_false] at this
        simp only [List.contains_iff_mem, List.mem_map] at hin
        obtain ⟨s, hs, rfl⟩ := hin
        exact this s hs hc
      rw [hzero, List.length_nil, Nat.zero_add]
      exact (List.length_filter_le _ _).trans (le_of_eq List.length_singleton)
    · have hin' : ∀ s ∈ req, s.offer ≠ offer := by
        intro s hs heq
        apply hin
        simp only [List.contains_iff_mem, List.mem_map]
        exact ⟨s, hs, heq⟩
      have : [(⟨req.map (·.offer), ord⟩ : CreatedOrder)].filter (fun e => e.offers.contains offer) = [] := by
        simpa using hin'
      rw [this]
      simpa using hbook offer

/-- No offer ever produces two orders: once an offer appears in a recorded
order, no request adds another order for it.

Open question for the business.  The sources do not say that creating an
order uses up its offer.  Under the reading where the airline creates another
order for a repeated request, a request sent again after a timeout gives the
customer a second order from the same offer.  The example
{lit}`repeatedRequest` shows it.  Does creating an order use up its offer, and
how does the airline recognize a request it has already answered? -/
@[open_question, checks "ONE-403.4"]
theorem once_per_offer (hd : RepeatHandling) (book : List CreatedOrder) (offers : List MarkedOffer)
    (req : List Selection) (now : Instant) (orderId : String) (ord : Order) (book' : List CreatedOrder)
    (hbook : OncePerOffer book) (h : createOnce hd book offers req now orderId = .ok (ord, book')) :
    OncePerOffer book' := by
  sorry

/-! ## Order versions and history -/

/-- A new order is at version 1, with no change groups and an empty history
under both readings. -/
@[checks "ONE-404.1"]
theorem create_version_one (o : Order) (l : HistoryListing) :
    (OrderRecord.create o).version = 1 ∧ (OrderRecord.create o).groups = [] ∧
      (orderHistory l (OrderRecord.create o)).initial = o ∧
      (orderHistory l (OrderRecord.create o)).entries = [] := by
  cases l <;> simp [OrderRecord.create, orderHistory, labelled]

/-- Applying a group of changes applies it to the order, records it and raises
the version by one. -/
@[checks "ONE-404.2"]
theorem record_raises_version (r : OrderRecord) (g : ChangeGroup) :
    (recordChanges r g).current = applyGroup r.current g ∧
      (recordChanges r g).groups = r.groups ++ [g] ∧ (recordChanges r g).version = r.version + 1 :=
  ⟨rfl, rfl, rfl⟩

/-- Applying groups in turn adds them to the history, raises the version by
their number and applies each to the order. -/
theorem foldl_recordChanges (r : OrderRecord) (gs : List ChangeGroup) :
    (gs.foldl recordChanges r).initial = r.initial ∧ (gs.foldl recordChanges r).groups = r.groups ++ gs ∧
      (gs.foldl recordChanges r).version = r.version + gs.length ∧
      (gs.foldl recordChanges r).current = replay r.current gs := by
  induction gs generalizing r with
  | nil => simp [replay]
  | cons g gs ih =>
    obtain ⟨h1, h2, h3, h4⟩ := ih (recordChanges r g)
    simp only [List.foldl_cons, h1, h2, h3, h4]
    refine ⟨rfl, by simp [recordChanges], by simp [recordChanges]; omega, rfl⟩

/-- After any number of change groups, an order's version is one more than
their number, and its history holds exactly those groups. -/
@[checks "ONE-404.3"]
theorem version_counts_groups (o : Order) (gs : List ChangeGroup) :
    (OrderRecord.after o gs).version = gs.length + 1 ∧ (OrderRecord.after o gs).groups = gs := by
  obtain ⟨-, h2, h3, -⟩ := foldl_recordChanges (OrderRecord.create o) gs
  unfold OrderRecord.after
  rw [h2, h3]
  simp only [OrderRecord.create, List.nil_append, and_true]
  omega

/-- The record of an order after change groups starts from the order as
created, holds those groups and has them applied to it. -/
theorem after_record (o : Order) (gs : List ChangeGroup) :
    (OrderRecord.after o gs).initial = o ∧ (OrderRecord.after o gs).groups = gs ∧
      (OrderRecord.after o gs).current = replay o gs := by
  obtain ⟨h1, h2, -, h4⟩ := foldl_recordChanges (OrderRecord.create o) gs
  unfold OrderRecord.after
  rw [h1, h2, h4]
  simp [OrderRecord.create]

/-- An order's history, under both readings, holds the order at version 1 and
each change group once, labelled with the version it produced: the first group
applied with version 2, the next with version 3, and so on. -/
@[checks "ONE-404.4"]
theorem history_lists_each_group (l : HistoryListing) (o : Order) (gs : List ChangeGroup) :
    (orderHistory l (OrderRecord.after o gs)).initial = o ∧
      (orderHistory l (OrderRecord.after o gs)).entries.Perm (gs.mapIdx fun k g => ⟨k + 2, g⟩) := by
  obtain ⟨hi, hg, -⟩ := after_record o gs
  cases l
  · simp [orderHistory, hg, hi, labelled]
  · simp [orderHistory, hg, hi, labelled]

/-- The groups of a history listed oldest first, in the order listed, are the
groups applied. -/
theorem labelled_groups (gs : List ChangeGroup) : (labelled gs).map (·.group) = gs := by
  apply List.ext_getElem
  · simp [labelled]
  · intro n _ _
    simp [labelled]

/-- Where the history lists change groups oldest first, applying them in the
order listed to the order at version 1 gives the order as it is now. -/
theorem history_rebuilds_of_oldestFirst (o : Order) (gs : List ChangeGroup) :
    (orderHistory .oldestFirst (OrderRecord.after o gs)).rebuild = (OrderRecord.after o gs).current := by
  obtain ⟨hi, hg, hc⟩ := after_record o gs
  simp only [History.rebuild, orderHistory, hi, hg, hc, labelled_groups]

/-- Applying the change groups of an order's history to the order at version
1, in the order listed, gives the order as it is now, under both readings.

Open question for the business.  The guide lists change groups oldest first,
each raising the version by one, while the capability page for order history
lists them newest first and says each lowers the version.  Applied newest
first, a group that removes an item runs before the group that added it, and
the item comes back.  The example {lit}`newestFirstHistory` shows it.  In
which order does the history list its change groups, and does a history
requested from version v include the group that produced v? -/
@[open_question, checks "ONE-404.5"]
theorem history_rebuilds_current (l : HistoryListing) (o : Order) (gs : List ChangeGroup) :
    (orderHistory l (OrderRecord.after o gs)).rebuild = (OrderRecord.after o gs).current := by
  sorry

/-! ## Changes against a stale version -/

/-- A change that carries the order's current version is applied and raises
the version by one, under both readings. -/
@[checks "ONE-405.1"]
theorem current_version_applied (s : StaleHandling) (r : OrderRecord) (g : ChangeGroup) :
    requestChange s r (some r.version) g = .ok (recordChanges r g) ∧
      (recordChanges r g).version = r.version + 1 := by
  simp [requestChange, recordChanges]

/-- A change that carries no version is applied, under both readings. -/
@[checks "ONE-405.2"]
theorem no_version_applied (s : StaleHandling) (r : OrderRecord) (g : ChangeGroup) :
    requestChange s r none g = .ok (recordChanges r g) := rfl

/-- Where the airline rejects stale versions, a change that carries a version
other than the current one is rejected. -/
theorem stale_rejected_of_reject (r : OrderRecord) (v : Nat) (g : ChangeGroup) (hv : v ≠ r.version) :
    requestChange .reject r (some v) g = .error .stale := by
  simp [requestChange, hv]

/-- A change that carries a version other than the order's current version is
rejected, under both readings.

Open question for the business.  The guide lets the airline return an error
when the versions differ and does not require it.  Under the reading where
the airline applies the change anyway, a seller who saw an older version
overwrites a change it never saw.  The example {lit}`twoSellersOneVersion`
shows it.  Does a version mismatch always reject the change, and may a change
be sent without a version? -/
@[open_question, checks "ONE-405.3"]
theorem stale_rejected (s : StaleHandling) (r : OrderRecord) (v : Nat) (g : ChangeGroup)
    (hv : v ≠ r.version) :
    ∃ e, requestChange s r (some v) g = .error e := by
  sorry

/-! ## Order retention -/

/-- An order with an active item is kept until 13 months after its creation,
under every reading and every count of months. -/
@[checks "ONE-406.1"]
theorem keep_from_creation (m : MonthCount) (v : ValueReading) (o : Order)
    (firstUse finalSince : Option Instant) (now : Instant)
    (hact : ∃ i ∈ o.items, i.isActive v = true) (hnow : now < m.thirteenAfter o.createdAt) :
    mustKeep m v o firstUse finalSince now = true := by
  have hopen : o.isOpened v = true := by simpa [Order.isOpened] using hact
  simp [mustKeep, hopen, hnow]

/-- An order with an active item that has been used is kept until 13 months
after its first usage, under every reading and every count of months. -/
@[checks "ONE-406.2"]
theorem keep_from_first_use (m : MonthCount) (v : ValueReading) (o : Order) (t : Instant)
    (finalSince : Option Instant) (now : Instant)
    (hact : ∃ i ∈ o.items, i.isActive v = true) (hnow : now < m.thirteenAfter t) :
    mustKeep m v o (some t) finalSince now = true := by
  have hopen : o.isOpened v = true := by simpa [Order.isOpened] using hact
  simp [mustKeep, hopen, hnow]

/-- An order whose items have all become closed or cancelled is kept for 7
days after that, under every reading and every count of months. -/
@[checks "ONE-406.3"]
theorem keep_after_final (m : MonthCount) (v : ValueReading) (o : Order) (firstUse : Option Instant)
    (t now : Instant) (hfinal : ∀ i ∈ o.items, i.isClosed = true ∨ i.isCancelled v = true)
    (hnow : now.epochSeconds < t.epochSeconds + sevenDays) :
    mustKeep m v o firstUse (some t) now = true := by
  have hopen : o.isOpened v = false := by
    simp only [Order.isOpened, List.any_eq_false]
    intro i hi ha
    rcases hfinal i hi with hc | hc
    · exact active_not_closed v i ⟨ha, hc⟩
    · exact active_not_cancelled v i ⟨ha, hc⟩
  simp [mustKeep, hopen, hnow]

/-- An order is kept while it has an active item, under every reading and
every count of months.

Open question for the business.  The resolution asks for 13 months from
creation and 13 months from first usage, and nothing after both have passed.
An item whose services are removed with their value held stays active for as
long as the customer does not use the value.  The example
{lit}`storedValueNeverUsed` shows it: two years after creation the order still
holds value and no longer has to be kept.  What are an open item and first
usage, and must an order that still holds value stay accessible? -/
@[open_question, checks "ONE-406.4"]
theorem keep_while_active (m : MonthCount) (v : ValueReading) (o : Order)
    (firstUse finalSince : Option Instant) (now : Instant)
    (hact : ∃ i ∈ o.items, i.isActive v = true) :
    mustKeep m v o firstUse finalSince now = true := by
  sorry

end Rules.OneOrder.Creation
