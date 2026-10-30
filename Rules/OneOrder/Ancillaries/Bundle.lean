import Rules.Core.Attributes
import Rules.OneOrder.Ancillaries.Cancel

/-!
# Removing a service from a bundle

A bundle is sold at one price.  In the seat worked example one order item at
1,000.00 EUR holds both passengers' flights and bags, and the cancellation page
removes a passenger by cancelling that passenger's services inside such an
item.  The guide prices a bundle only as a whole and does not say how much of
the price belongs to one of its services.  The model takes the share as a
parameter, a reading of the sources.
-/

namespace Rules.OneOrder.Ancillaries

open Rules.Core
open Rules.OneOrder.AirlineChange (isLive)

/-- How much of a bundle's price belongs to one of its services, in minor units
of the bundle's currency.  No source says, so the model takes the answer as a
parameter: a reading of the sources, such as stated component prices,
stand-alone prices, or no share at all. -/
structure BundleShare where
  /-- The share of an order item's price that belongs to one of its services. -/
  share : OrderItem → Service → Nat

/-- Why a request to remove services from a bundle was refused. -/
inductive BundleRejection
  /-- The order has no item with the reference given. -/
  | unknownItem (item : String)
  /-- The item holds no service with a reference named. -/
  | unknownService (service : String)
  deriving DecidableEq, Repr, Inhabited

/-- An order item after services are removed from it: each named service
cancelled if it is live, every other service as it was, and the price as it
was. -/
def removeServices (ids : List String) (i : OrderItem) : OrderItem :=
  { i with services := i.services.map fun s => if ids.contains s.id then endService s else s }

/-- The amount returned for the named live services of a bundle: the sum of
their shares under the reading, in the bundle's currency. -/
def bundleReturn (sh : BundleShare) (i : OrderItem) (ids : List String) : Money :=
  ⟨((i.services.filter fun s => ids.contains s.id && isLive s).map (sh.share i)).sum, i.price.currency⟩

/-- EARS: When a seller removes services from a bundle, the system shall cancel
them and return their share of the bundle price under the reading.

Story: As a customer who drops one passenger from a bundled trip, I want back
the part of the price that passenger's services were worth, so that I pay
only for what I keep.

Acceptance criteria:

* ONE-607.1: When services are removed from a bundle, the system shall mark
  each named live service CANCELLED with delivery status REMOVED and leave
  the bundle's other services and its price as they were.
* ONE-607.2: When services are removed from a bundle, the system shall return
  the sum of the shares of the named live services under the reading, in the
  bundle's currency.
* ONE-607.3: When services are removed from a bundle, the system shall return
  no more than the bundle price.
* ONE-607.4: When every service of a bundle is removed, the system shall
  return the whole bundle price.

A bundle here is one order item holding several services, as on the guide's
bundles page.  The share of each service is the reading's
({name}`BundleShare`).  Whether the rest of the bundle is repriced, as the
cancellation page suggests, is not modelled. -/
@[ears "ONE-607"]
def removeFromBundle (sh : BundleShare) (o : Order) (item : String) (ids : List String) :
    Except BundleRejection (Order × Money) :=
  match o.items.find? (·.id == item) with
  | none => .error (.unknownItem item)
  | some i =>
    match ids.find? (fun id => !i.services.any (·.id == id)) with
    | some id => .error (.unknownService id)
    | none =>
      .ok ({ o with items := o.items.map fun j => if j.id == item then removeServices ids j else j },
        bundleReturn sh i ids)

end Rules.OneOrder.Ancillaries
