import VersoManual
import Rules

open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean

set_option pp.rawOnError true

#doc (Manual) "Open Questions" =>
%%%
tag := "open-questions"
%%%

The model found one rule whose intended meaning it cannot settle.
The question below is for the Offer/Order team.

# How much may be refunded against a payment?

The guarantee {lean}`Rules.OfferOrder.refunds_le_payments` claims that refunds against an order never exceed what was paid for it.
It is open, because the refund rule {lean}`Rules.OfferOrder.acceptRefund` checks each refund against its payment alone.

The build computes this counterexample, {lean}`Rules.OfferOrder.doubleRefund`: one payment of 100.00 USD, and two refunds of 60.00 USD against it.
Each refund passes the check, and together they return 120.00 USD.

:::paragraph
The question for the team:

 * Does the limit apply to each refund on its own, to all refunds against one payment together, or to all refunds against one order together?
 * Is a refund above the amount paid ever allowed, for example as a goodwill credit?
:::

The answer decides how {lean}`Rules.OfferOrder.acceptRefund` changes.
If the limit is cumulative per payment, the rule rejects a refund that would take the payment's refunded total above its amount, and the guarantee can then be proven.
