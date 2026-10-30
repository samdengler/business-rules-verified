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
Shared concepts such as money and time live in the `Core` namespace, which every business group uses; the Offer and Order objects live in the `OfferOrder` namespace.
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

# Placeholders for later namespaces

These two objects exist so that later namespaces have something to build on.
The Identity namespace will replace the principal, and the Data Governance namespace will attach a classification to each data product field.

{docstring Rules.Core.Principal +hideStructureConstructor (label := "placeholder")}

{docstring Rules.Core.Classification +hideStructureConstructor (label := "placeholder")}
