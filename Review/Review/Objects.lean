import VersoManual
import Rules

open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean

set_option pp.rawOnError true

#doc (Manual) "Objects" =>
%%%
tag := "objects"
%%%

The objects are the things the rules talk about.
Shared concepts such as money and time live in the `Core` namespace, which every business group uses; the pilot's Offer and Order objects live in the `OfferOrder` namespace, and the ONE Order objects in the `OneOrder` namespace.
Each card gives an object's description from its Lean docstring, then its fields, then the object as Lean states it.

# Money and time

{docstring Rules.Core.Currency +hideStructureConstructor (label := "object")}

{docstring Rules.Core.Money +hideStructureConstructor (label := "object")}

{docstring Rules.Core.Money.add +hideStructureConstructor (label := "calculation")}

{docstring Rules.Core.Instant +hideStructureConstructor (label := "object")}

# Passengers

{docstring Rules.Core.Passenger +hideStructureConstructor (label := "object")}

# Offers

{docstring Rules.OfferOrder.OfferItem +hideStructureConstructor (label := "object")}

{docstring Rules.OfferOrder.Offer +hideStructureConstructor (label := "object")}

{docstring Rules.OfferOrder.Rejection +hideStructureConstructor (label := "object")}

# Orders

{docstring Rules.OfferOrder.Order +hideStructureConstructor (label := "object")}

{docstring Rules.OfferOrder.OrderItem +hideStructureConstructor (label := "object")}

{docstring Rules.OfferOrder.DeliveryState +hideStructureConstructor (label := "object")}

{docstring Rules.OfferOrder.DeliveryEvent +hideStructureConstructor (label := "object")}

# Payments and refunds

{docstring Rules.OfferOrder.Payment +hideStructureConstructor (label := "object")}

{docstring Rules.OfferOrder.Refund +hideStructureConstructor (label := "object")}

{docstring Rules.OfferOrder.totalPaid +hideStructureConstructor (label := "calculation")}

{docstring Rules.OfferOrder.totalRefunded +hideStructureConstructor (label := "calculation")}

# ONE Order objects

The ONE Order rules follow the standard as IATA's public guide describes it, in the `OneOrder` namespace.
An order holds order items, and each order item holds services, one for each passenger and flight segment.
Each area of the standard adds its own objects; their cards are in the requirement chapters that use them.

{docstring Rules.OneOrder.OfferItem +hideStructureConstructor (label := "object")}

{docstring Rules.OneOrder.Offer +hideStructureConstructor (label := "object")}

{docstring Rules.OneOrder.Order +hideStructureConstructor (label := "object")}

{docstring Rules.OneOrder.OrderItem +hideStructureConstructor (label := "object")}

{docstring Rules.OneOrder.Service +hideStructureConstructor (label := "object")}

{docstring Rules.OneOrder.ServiceStatus +hideStructureConstructor (label := "object")}

{docstring Rules.OneOrder.DeliveryStatus +hideStructureConstructor (label := "object")}

{docstring Rules.OneOrder.ValueReading +hideStructureConstructor (label := "reading")}

# Placeholders for later namespaces

These two objects exist so that later namespaces have something to build on.
The Identity namespace will replace the principal, and the Data Governance namespace will attach a classification to each data product field.

{docstring Rules.Core.Principal +hideStructureConstructor (label := "placeholder")}

{docstring Rules.Core.Classification +hideStructureConstructor (label := "placeholder")}
