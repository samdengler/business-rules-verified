# ONE Order formalization survey

This survey lists rules from IATA's public ONE Order material that are candidates for the Lean model. Each candidate is classified by the test below, and the classification decides how it enters the blueprint: a clear rule becomes an ordinary node, and a vague or silent one becomes a `\notready` node linked to a GitHub issue.

This repository is a proof of concept. It is not affiliated with or endorsed by IATA, and IATA owns the standard and its documentation.

Surveyed on 2026-10-29. The entries describe each rule in our own words and link to the page it comes from. The Enhanced and Simplified Distribution guide carries an IATA notice that prohibits reproducing its content without permission, so nothing here is quoted from it. Status names such as `READY TO PROCEED` are used as identifiers.

## How candidates were chosen

A rule is a candidate if it is one of these kinds:

* **Decision**: something the system decides, such as accepting, changing, cancelling or refunding.
* **Invariant**: a property that must hold across objects or over time, such as refunds staying within payments.

Each candidate also records what the standard says about it:

* **Clear**: the source states the rule.
* **Vague**: the source states the rule with "may" or "should", or leaves a term undefined.
* **Silent**: the source names the situation and gives no rule for it.

Vague and silent candidates are the most useful. Writing them in Lean forces a decision, and that decision belongs to the business. The refund question in the current model (OO-003.2) came from a silent case.

## Sources

| Short name | Source |
| --- | --- |
| Order | [EASD guide: Order](https://standards.atlassian.net/wiki/spaces/EASD/pages/574849062/Order) |
| Cancellation | [EASD guide: Cancellation of Order Items](https://standards.atlassian.net/wiki/spaces/EASD/pages/574783569/Cancellation+of+Order+Items) |
| Modification | [EASD guide: Modification of an Order](https://standards.atlassian.net/wiki/spaces/EASD/pages/574619782/Modification+of+an+Order) |
| Value Store | [EASD guide: Value Store](https://standards.atlassian.net/wiki/spaces/EASD/pages/574554245/Value+Store) |
| Multiple methods | [EASD guide: Use of multiple payment methods to pay for a single item](https://standards.atlassian.net/wiki/spaces/EASD/pages/2592899087/Use+of+multiple+payment+methods+to+pay+for+a+single+item) |
| Commitment | [EASD guide: Commitment to pay when no amount due](https://standards.atlassian.net/wiki/spaces/EASD/pages/2593488900/Commitment+to+pay+when+no+amount+due) |
| Versioning | [EASD guide: Order Versioning](https://standards.atlassian.net/wiki/spaces/EASD/pages/574259659/Order+Versioning) |
| ORDSTS | [Airline Retailing Maturity Index: Order Status Change for Service Delivery](https://retailing.iata.org/armi/docs/ORDSTS/) |
| R797 | [IATA Resolution 797, ONE Order](https://www.iata.org/contentassets/72cbd60393ff42b5975d90ce9e049a7d/oneorder-resolution-797.pdf) |

Each page was read in full through the guide's public page API before the blueprint nodes were written.

## Candidates

### Order structure and status

| ID | Rule, in our words | Kind | Standard | What the Lean would show | Source |
| --- | --- | --- | --- | --- | --- |
| C-01 | An order has at least one order item, each order item has at least one service, and each service is for one passenger on one flight segment. | Invariant | Clear | Adds the service level the current model lacks, and `accept` has to build it. Each service carries two statuses: a service status such as `CONFIRMED` or `TRANSFERRED`, and a delivery status such as `READY TO PROCEED`. | Order |
| C-02 | Accepting an offer turns each offer item into exactly one order item. | Invariant | Clear | A theorem about `accept`, extending OO-001. | Order |
| C-03 | Order item IDs are unique within an order. | Invariant | Clear | That accepting and every later change keep the IDs unique. | Order |
| C-04 | The price is held on the order item, and an order item cannot be split. | Invariant | Clear | That no operation changes part of an item, so a change always replaces whole items. | Order |
| C-05 | Each delivery status either holds value or does not. | Decision | Silent | The source settles this only for `REMOVED HOLD VALUE` (holds value) and `REMOVED` (does not). The order and item statuses below depend on the rest. | Order |
| C-06 | An order item is `ACTIVE`, `CANCELLED` or `CLOSED`, depending on its services. | Decision | Vague | Whether the three conditions cover every combination of services and never overlap. They appear to overlap: a delivered service that is later transferred to a new item leaves its original item meeting the conditions for both `CANCELLED` and `CLOSED`. | Order |
| C-07 | An order is `OPENED` or `CLOSED`, depending on its items and services, and `CLOSED` is final. | Decision, invariant | Vague | Whether every order is one or the other. An order with a service in `EXPIRED` or `UNABLE TO DELIVER` looks like neither. Also that nothing reopens a closed order. | Order |

### Service delivery and payment

| ID | Rule, in our words | Kind | Standard | What the Lean would show | Source |
| --- | --- | --- | --- | --- | --- |
| C-08 | A service moves from `CONFIRMED` to `READY TO PROCEED` when paid, and on to `DELIVERED` or another final status. | Decision | Vague | Replaces the current four-state `step` with the standard's statuses, and makes the source say which statuses are final. The full flow is in a guide not yet read in full. | Order, ORDSTS |
| C-09 | A suspended service can only return to the status it had before, or be removed. | Invariant | Clear | The model has to remember the status before suspension. Provable once it does. | Order |
| C-10 | A service `IN PROGRESS` may block refunds and other financial actions. | Decision | Vague | "May" leaves the choice to each airline. The model makes it a parameter or an open question. | Order |
| C-11 | A confirmed service waits for payment until the payment time limit. | Decision | Silent | Same shape as offer expiry (OO-001.1). The source does not say what happens to the service when the limit passes. | Order |
| C-12 | An order item with nothing to pay moves on when the seller commits to pay zero. | Decision | Silent | The source describes the commitment message and does not say which status the services move to. | Commitment |
| C-13 | When several payment methods pay for one item, the payment succeeds only if every method succeeds. | Decision | Clear | A simple proven guarantee. | Multiple methods |
| C-14 | The amounts charged across those methods cover the item's price plus any surcharges. | Invariant | Silent | The worked example adds a card surcharge and states no rule. This decides what "paid in full" means, which the refund limit depends on. | Multiple methods |

### Change, cancellation and refund

| ID | Rule, in our words | Kind | Standard | What the Lean would show | Source |
| --- | --- | --- | --- | --- | --- |
| C-15 | An unpaid order can be cancelled directly. A paid order is cancelled by accepting a cancellation offer. | Decision | Clear | A rule with two cases, and a theorem that a paid order is never cancelled without an accepted offer. | Cancellation |
| C-16 | A cancellation penalty is either deducted from the refund or charged separately. | Invariant | Clear | That the customer's net amount is the same either way: the refundable total minus the penalty. | Cancellation |
| C-17 | Refunds go back to the payment methods that paid. | Decision | Silent | Extends OO-003. With surcharges and several methods, whether a refund can exceed the item's price. Connects to the open question OO-003.2. | Multiple methods, Cancellation |
| C-18 | Changing an item cancels the original item's services, creates a new item, and charges or refunds the difference in price. | Decision, invariant | Vague | The source shows the difference in a worked example and does not define its sign or how penalties enter it. | Modification |
| C-19 | Services kept through a change move to the new item with the same service ID, the originals are marked `TRANSFERRED`, and delivered services move too so the order stays balanced. | Invariant | Vague | "Balanced" is not defined. The model defines it and proves that transfers preserve it. | Order |
| C-20 | Value stored as an order item can only be used in a later change to the same order. | Invariant | Silent in part | That stored value never moves to another order. The source does not cover partial use or expiry. | Value Store |

### Versioning, billing and retention

| ID | Rule, in our words | Kind | Standard | What the Lean would show | Source |
| --- | --- | --- | --- | --- | --- |
| C-21 | An order's version starts at 1 and goes up by one for each group of changes. | Invariant | Clear | That the version always equals one plus the number of change groups applied. | Versioning |
| C-22 | A service provider does not bill the airline for a service before it is delivered or consumed, unless they agree otherwise. | Invariant | Clear | That every billing event refers to a delivered service. | R797 |
| C-23 | An order with an open item stays accessible for at least 13 months from creation, and for at least 7 days after all its items reach a final status. | Decision | Clear | Time arithmetic like offer expiry. | R797 |

## Expected open questions

These candidates are likely to end as open theorems or `\notready` nodes:

* C-05: which delivery statuses hold value.
* C-06: which status an item has when a delivered service is transferred out of it.
* C-07: whether every order is `OPENED` or `CLOSED`.
* C-10: whether `IN PROGRESS` blocks refunds.
* C-11: what happens to a service when the payment time limit passes.
* C-14: whether surcharges count towards the amount paid.
* C-17: how refunds are split across payment methods, and whether they can exceed the price.
* C-19: what keeps an order balanced through a transfer.

## What the current model already covers

| Current rule | Related candidates |
| --- | --- |
| OO-001, accepting an offer | C-02, C-03, C-04. C-01 changes the shape of the order `accept` builds. |
| OO-002, delivering, cancelling and refunding a service | C-08 replaces its four states with the standard's delivery statuses. C-09 and C-10 add to it. |
| OO-003, payments and refunds | C-13, C-14, C-16, C-17. |
