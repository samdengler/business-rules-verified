# ONE Order formalization survey

This survey lists rules from IATA's public ONE Order material that are candidates for the Lean model. Each candidate is classified by the test below, and the classification decides how it enters the blueprint: a clear rule becomes an ordinary node, and a vague or silent one becomes a `\notready` node linked to a GitHub issue.

This repository is a proof of concept. It is not affiliated with or endorsed by IATA, and IATA owns the standard and its documentation.

First surveyed on 2026-10-29; the [second round](#second-round) read every area in full. The entries describe each rule in our own words and link to the page it comes from. The Enhanced and Simplified Distribution guide carries an IATA notice that prohibits reproducing its content without permission, so nothing here is quoted from it. Status names such as `READY TO PROCEED` are used as identifiers.

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

## Second round

The second round, on 2026-10-29, read each area's pages in full, including the worked examples and their XML samples, and returned 160 candidates. Candidates that two areas found independently were merged, which leaves 138, numbered C-24 to C-161. Each is a blueprint node in `blueprint/src/areas/`, with the rule in our own words, a case to check where the sources suggest one, the open point for vague and silent rules, and links to its pages.

Some candidates record places where the sources disagree with each other, for example a worked example that contradicts a concept page. Those are open points too: the business decides which reading holds.


### Offers, prices and conditions

| ID | Rule | Kind | Standard | Capabilities |
| --- | --- | --- | --- | --- |
| C-24 | Offer expiry ends other limits | Guarantee | Vague | SHPFLT |
| C-25 | Price guarantee at an instant | Definition | Clear | SHPFLT |
| C-26 | Accepting after the guarantee lapses | Definition | Silent | SHPFLT |
| C-27 | Order time limits only extend | Guarantee | Clear | SHPFLT |
| C-28 | Payment time limit at creation | Definition | Vague | SHPFLT |
| C-29 | Nesting of guarantee time limits | Guarantee | Vague | SHPFLT |
| C-30 | Restriction rule in force | Definition | Vague | SHPOR1, SHPOR2 |
| C-31 | Voluntary change under a restriction | Guarantee | Vague | SHPOR1, SHPOR2 |
| C-32 | Refund owed on voluntary cancellation | Definition | Vague | SHPOR1, SHPOR2 |
| C-33 | Taxes on a non-refundable fare | Guarantee | Silent | SHPOR1, SHPOR2 |
| C-34 | Price total from its parts | Guarantee | Vague | SHPFLT, SHPDSC |
| C-35 | Tax summary total and detail | Guarantee | Clear | SHPFLT |
| C-36 | Consumption tax lines add up | Guarantee | Silent | SHPFLT |
| C-37 | Seller margin stays outside order | Guarantee | Clear |  |
| C-38 | Mandatory and optional offer items | Definition | Vague | SHPFLT |
| C-39 | Offer responsible airline owns order | Guarantee | Clear | SHPITL |
| C-40 | Terms of a combined interline offer | Definition | Silent | SHPITL |
| C-41 | Currency of an offer's amounts | Definition | Vague | SHPLOC |
| C-42 | Time limits as UTC instants | Definition | Vague | SHPFLT |

### Ancillaries, seats and bundles

| ID | Rule | Kind | Standard | Capabilities |
| --- | --- | --- | --- | --- |
| C-43 | Dependent service and its parent | Definition | Vague | SHPANC, ORDRE2 |
| C-44 | Ancillary needs a flight service | Guarantee | Vague | SHPANC, SHPSTO, SHPSTA, ORDRE2 |
| C-45 | Cancelling a flight with ancillaries | Definition | Silent | ORDRE2, SHPANC |
| C-46 | Dependents when a flight changes | Definition | Silent | ORDRE2, ORDOCN |
| C-47 | Dependent impact shown before acceptance | Guarantee | Vague | ORDRE2 |
| C-48 | Dependent service lost by airline change | Definition | Silent | ORDRE2 |
| C-49 | One passenger per seat | Guarantee | Silent | SHPSTA, SHPSTO, SHPSTP |
| C-50 | One seat per passenger per segment | Guarantee | Silent | SHPSTA, SHPSTP, ORDRE2 |
| C-51 | Seat needs an eligible price point | Guarantee | Vague | SHPSTP, SHPSTA |
| C-52 | A-la-carte offer item | Definition | Clear | SHPANC, SHPSTP, ORDRE2 |
| C-53 | Price of an a-la-carte selection | Definition | Vague | SHPANC, ORDRE2, SHPSTP |
| C-54 | Bundle of services | Definition | Vague | SHPBND |
| C-55 | Value of one bundled service | Definition | Silent | SHPBND |
| C-56 | Pick M of N price | Guarantee | Vague | SHPBND |
| C-57 | Free seat creates a zero-priced item | Guarantee | Vague | SHPSTP, ORDRE2 |
| C-58 | Pooled baggage allowance | Definition | Vague | SHPANC |
| C-59 | Extra baggage weight | Definition | Vague | SHPANC |
| C-60 | Matching a taxonomy criterion | Definition | Silent | SHPSRV, SHPAN2, SHPAN3 |
| C-61 | Removing a passenger and dependents | Guarantee | Vague | ORDRE2, SHPANC |

### Order creation and order information

| ID | Rule | Kind | Standard | Capabilities |
| --- | --- | --- | --- | --- |
| C-62 | Selecting items from an offer | Definition | Vague | ORDCRE, ORDWPM, ORDCWT, SHPANC, SHPBND |
| C-63 | Order items match the selection | Guarantee | Clear | ORDCRE, ORDWPM |
| C-64 | Atomic order creation | Guarantee | Vague | ORDCRE, ORDWPM |
| C-65 | Failed payment at order creation | Definition | Vague | ORDCRE |
| C-66 | One order per offer | Guarantee | Silent | ORDCRE, ORDWPM |
| C-67 | Statuses of a new order | Guarantee | Vague | ORDWPM, ORDCRE |
| C-68 | Paying for part of an order | Definition | Silent | ORDWPM, ORDCRE |
| C-69 | Order items in a retrieved order | Definition | Vague | ORDRET |
| C-70 | Read access to an order | Definition | Silent | ORDRET, ORDLST, ORDHIS |
| C-71 | Group order limits | Definition | Silent | ORDGRP |
| C-72 | History rebuilds every version | Guarantee | Vague | ORDHIS, ORDRET, ORDOC2 |
| C-73 | Version tracks seller-visible changes | Guarantee | Vague | ORDRET, ORDHIS, ORDOC2 |
| C-74 | Change against a stale version | Definition | Vague | ORDRET, ORDHIS, ORDOC2 |
| C-75 | Service IDs in an order | Guarantee | Vague | ORDCRE, ORDRET, ORDOC2 |
| C-76 | Retention after first usage | Definition | Vague | ORDRET, ORDHIS |
| C-77 | Order ID | Definition | Vague | ORDCRE, ORDWPM, ORDRET |
| C-78 | Order owner is the offer owner | Guarantee | Vague | ORDCRE, ORDWPM |
| C-79 | Order total from item prices | Guarantee | Vague | ORDCRE, ORDWPM |
| C-80 | Verifying distribution chain identities | Definition | Vague | ORDCRE, ORDWPM |

### Change and cancellation (seller-initiated)

| ID | Rule | Kind | Standard | Capabilities |
| --- | --- | --- | --- | --- |
| C-81 | Price differential of a change | Definition | Vague | ORDRSH, ORDCAN, ORDCA2, ORDPEN, ORDFOR, ORDREU |
| C-82 | Due amounts net to the difference | Guarantee | Vague | ORDRSH, ORDCAN, ORDPEN, ORDFOR |
| C-83 | Order balance after servicing | Guarantee | Vague | ORDPEN, ORDFOR, ORDRSH, PAYREF, PAYSUM |
| C-84 | Change accepted before payment | Definition | Silent | ORDRSH, ORDPEN, ORDFOR, PAYREF, PAYORD |
| C-85 | Penalty larger than the refund | Definition | Silent | ORDCAN, ORDCA2, ORDPEN |
| C-86 | Full cancellation keeps no residual | Guarantee | Vague | ORDCA2, ORDREU |
| C-87 | Cancelling a partly paid order | Definition | Vague | ORDCA2, ORDCAN |
| C-88 | Removing one passenger from an item | Definition | Silent | ORDCAN, ORDRSH |
| C-89 | Reusable amount on cancellation | Definition | Silent | ORDREU, ORDCAN |
| C-90 | Settling money the airline owes | Definition | Vague | ORDCAN, ORDRSH, ORDREU, ORDFOR |
| C-91 | Value store time windows | Definition | Silent | ORDCA2, ORDCAN |
| C-92 | Stored value is used once | Guarantee | Silent | ORDREU |
| C-93 | Transferred originals hold no value | Guarantee | Vague | ORDRSH |
| C-94 | Refund waits for separate penalty | Guarantee | Clear | ORDPEN, ORDCAN |
| C-95 | Penalties and forfeits persist | Guarantee | Clear | ORDPEN, ORDFOR |
| C-96 | Name change through an offer | Definition | Silent | ORDNAM |
| C-97 | Changes made without an offer | Definition | Vague | ORDPAX, ORDRSH, ORDNAM, ORDCAN, ORDCA2 |
| C-98 | Full cancellation equals item cancellations | Guarantee | Vague | ORDCA2, ORDCAN |
| C-99 | Stored value belongs to payer | Guarantee | Silent | ORDREU |

### Airline-initiated change

| ID | Rule | Kind | Standard | Capabilities |
| --- | --- | --- | --- | --- |
| C-100 | Penalty when declining an airline change | Guarantee | Silent | ORDOCN |
| C-101 | Refund for a cancelled flight | Guarantee | Silent | ORDOCN |
| C-102 | Consequence of a missed time limit | Definition | Vague | ORDOCN |
| C-103 | Change applied before seller response | Guarantee | Vague | ORDOCN, ORDOC2 |
| C-104 | Paid status after re-accommodation | Guarantee | Vague | ORDOCN, ORDOC2 |
| C-105 | Unacknowledged change notice | Guarantee | Silent | ORDOCN |
| C-106 | Changes that require a customer choice | Definition | Silent | ORDOCN |
| C-107 | Voluntary and involuntary change | Definition | Vague | ORDOCN, ORDOC2 |
| C-108 | Pending follow-up actions | Guarantee | Vague | ORDOCN |
| C-109 | Repricing after waitlist confirmation | Definition | Vague | ORDOCN |
| C-110 | Who is told of a change | Definition | Vague | ORDOCN, STPNTF |
| C-111 | Cancelled service in an active item | Guarantee | Vague | ORDOCN |
| C-112 | Price of reshopping after airline change | Guarantee | Vague | ORDOCN |
| C-113 | Seller follow-up action | Definition | Clear | ORDOCN, ORDOC2 |

### Delivery and fulfilment

| ID | Rule | Kind | Standard | Capabilities |
| --- | --- | --- | --- | --- |
| C-114 | Who sets each delivery status | Definition | Vague | ORDSTS, ORDDEL |
| C-115 | Payment before delivery starts | Guarantee | Vague | ORDDEL |
| C-116 | Final delivery statuses | Definition | Vague | ORDSTS |
| C-117 | Held value after cancellation | Definition | Vague |  |
| C-118 | Expiry of an unclaimed service | Definition | Vague | ORDSTS |
| C-119 | Passenger no-show | Definition | Vague | ORDSTS |
| C-120 | Refund after a failed delivery | Definition | Silent | ORDSTS |
| C-121 | Seller told of status changes | Guarantee | Vague | ORDST2 |
| C-122 | Announced future delivery status | Guarantee | Vague |  |
| C-123 | No changes after closing | Guarantee | Vague |  |
| C-124 | Transfer keeps delivery status | Guarantee | Vague |  |
| C-125 | Delivery milestones and status | Guarantee | Vague | ORDSTS |

### Payment

| ID | Rule | Kind | Standard | Capabilities |
| --- | --- | --- | --- | --- |
| C-126 | Paid order item | Definition | Vague | PAYORD, PAYSUM, PAYMIX |
| C-127 | Payment status and its moves | Definition | Vague | PAYSUM, PAYRCV, PAYGTW, PAYSET |
| C-128 | Effects of a payment outcome | Guarantee | Vague | PAYORD, PAYGTW, PAYSUM, ORDDEL |
| C-129 | Time limit on unpaid items | Guarantee | Vague | PAYORD, ORDWPM |
| C-130 | Unpaid item at its time limit | Definition | Vague | PAYORD, PAYGTW |
| C-131 | No payment after the limits | Guarantee | Vague | PAYORD, PAYRCV |
| C-132 | Failed payment leaves items unpaid | Guarantee | Clear | PAYMIX |
| C-133 | Allocating a payment across items | Definition | Silent | PAYMIX |
| C-134 | Combinable payment methods | Definition | Silent | PAYMIX, PAYCPC |
| C-135 | Surcharge on each payment method | Definition | Clear | PAYMIX, PAYCPC |
| C-136 | Quoted surcharge at payment time | Guarantee | Vague | PAYCPC, PAYRCV |
| C-137 | Refundable payment surcharges | Definition | Vague | PAYREF, PAYMIX |
| C-138 | Refund as a negative payment | Definition | Silent | PAYREF, PAYSUM |
| C-139 | Retrying a failed payment | Definition | Vague | PAYRCV, PAY3D2 |
| C-140 | Commitment only when nothing due | Guarantee | Vague | PAYORD, PAYMIX |
| C-141 | Paying with a voucher | Definition | Silent | PAYVCH, PAYMIX |

### Commission, accounting and settlement

| ID | Rule | Kind | Standard | Capabilities |
| --- | --- | --- | --- | --- |
| C-142 | Settlement value of a service | Definition | Vague | ACCRE2 |
| C-143 | Billing limited to delivered services | Guarantee | Vague | ACCSTS |
| C-144 | First accounting posting after payment | Guarantee | Vague | ACCRE2, ACCREP |
| C-145 | Revenue recognized at final status | Guarantee | Vague | ACCSTS, ORDSTS |
| C-146 | Money balance of an order | Guarantee | Silent | ACCSTS, ACCRE2 |
| C-147 | Commission on an item | Definition | Vague | PAYCOM |
| C-148 | Net clearance amount | Definition | Vague | PAYCMT, STTCAP, PAYSET, PAYREF |
| C-149 | Commission cleared exactly once | Guarantee | Clear | PAYCMT |
| C-150 | Clearance request matches the order | Guarantee | Clear | STTCAP, PAYCMT |
| C-151 | One clearance per payment commitment | Guarantee | Vague | STTCAP, PAYSET |
| C-152 | Clearance status | Definition | Vague | STTSUM, STTCAP, STTCAN |
| C-153 | Cancelling a clearance | Definition | Vague | STTCAN |
| C-154 | Clearing total | Guarantee | Vague | STTSUM |
| C-155 | Net position per remittance date | Guarantee | Vague | STTSUM, STTCAP |
| C-156 | Settled and unsettled clearance amounts | Guarantee | Vague | STTSUM, STTHST |
| C-157 | Netting on a change | Definition | Vague |  |
| C-158 | Order of accounting postings | Guarantee | Vague | ACCSTS, ACCRE2 |
| C-159 | Commission from offer to order | Guarantee | Vague | PAYCOM |
| C-160 | Requesting a clearance | Definition | Vague | STTCAP |
| C-161 | Allocating a short remittance | Definition | Vague | STTSUM |
