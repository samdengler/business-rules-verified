import VersoManual
import Rules
import Review.Generated.Ears

open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean

set_option pp.rawOnError true

#doc (Manual) "Rules" =>
%%%
tag := "rules"
%%%

A rule is a decision the system makes.
Each rule below is a Lean function; its description starts with the EARS requirement statement that the spec-driven development team consumes.
The function names in this chapter are checked against the model, so renaming a function without updating this chapter fails the document build.

# Accepting an offer

The function {lean}`Rules.OfferOrder.accept` decides whether an offer becomes an order.
It takes the offer, the current time, and the new order's reference, and returns either the order or the reason for rejecting it.

{docstring Rules.OfferOrder.accept}

{docstring Rules.OfferOrder.Rejection}

# Delivering, cancelling, and refunding a service

The function {lean}`Rules.OfferOrder.step` applies a delivery event to a purchased service.

{docstring Rules.OfferOrder.step}

# Accepting a refund

The function {lean}`Rules.OfferOrder.acceptRefund` decides whether a refund is accepted against a payment.

{docstring Rules.OfferOrder.acceptRefund}

{include 1 Review.Generated.Ears}
