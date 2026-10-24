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
Each object's description below is its Lean docstring, and the box shows its fields as Lean defines them.

# Money and time

{docstring Rules.Core.Currency}

{docstring Rules.Core.Money}

{docstring Rules.Core.Money.add}

{docstring Rules.Core.Instant}

# Passengers

{docstring Rules.Core.Passenger}

# Offers

{docstring Rules.OfferOrder.OfferItem}

{docstring Rules.OfferOrder.Offer}

# Orders

{docstring Rules.OfferOrder.Order}

{docstring Rules.OfferOrder.OrderItem}

{docstring Rules.OfferOrder.DeliveryState}

{docstring Rules.OfferOrder.DeliveryEvent}

# Payments and refunds

{docstring Rules.OfferOrder.Payment}

{docstring Rules.OfferOrder.Refund}

{docstring Rules.OfferOrder.totalPaid}

{docstring Rules.OfferOrder.totalRefunded}

# Placeholders for later namespaces

These two objects exist so that later namespaces have something to build on.
The Identity namespace will replace the principal, and the Data Governance namespace will attach a classification to each data product field.

{docstring Rules.Core.Principal}

{docstring Rules.Core.Classification}
