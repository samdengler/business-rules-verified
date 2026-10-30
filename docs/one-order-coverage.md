# ONE Order coverage map

This map lists the capabilities of IATA's ONE Order and NDC standards and how far the model covers each one. It follows the [ONE Order survey](one-order-survey.md): the first round listed rules from nine pages, the second read every area in full, and this map shows how much of the standard the candidates cover.

This repository is a proof of concept. It is not affiliated with or endorsed by IATA, and IATA owns the standard and its documentation. Capability names are IATA's, used as identifiers; everything else here is in our own words.

Surveyed on 2026-10-30.

## Sources and method

* The capability list is IATA's [Airline Retailing Maturity Index](https://retailing.iata.org/armi/docs/) checklist: 75 capabilities, each with a code. The 12 setup capabilities (codes starting STP), such as bug tracking, documentation and sandboxes, are about running an implementation and are left out. That leaves 63.
* The [EASD implementation guide](https://standards.atlassian.net/wiki/spaces/EASD/overview) groups the same ground into Shop, Order, Payment and Legacy capabilities and concepts; its concept pages are where the rules are described.
* **Status** compares each capability with the Lean model and the blueprint: *In Lean, in part* means a rule or object in the model covers some of it; *Candidate* means a blueprint node from the survey covers some of it; *Not started* means neither.
* **Rule content** is our judgment, from the capability's name and the guide's concept pages, of how much it holds that is worth proving: *High* for decisions about money, status or what the customer is owed; *Medium* for rules that matter but are mostly data handling; *Low* for presentation and integration, where there is little to prove. An area's pages are read in full before its nodes are written.

## Summary

| Area | Capabilities | In Lean, in part | Candidate | Not started | High rule content |
| --- | --- | --- | --- | --- | --- |
| Shopping | 22 | 9 | 5 | 8 | 3 |
| Order creation | 5 | 3 | 1 | 1 | 2 |
| Order information | 3 | 2 | 1 | 0 | 0 |
| Change and cancellation | 9 | 7 | 2 | 0 | 6 |
| Airline-initiated change | 2 | 2 | 0 | 0 | 1 |
| Delivery | 3 | 2 | 1 | 0 | 2 |
| Payment | 10 | 8 | 2 | 0 | 3 |
| Commission | 2 | 2 | 0 | 0 | 1 |
| Accounting and settlement | 7 | 6 | 1 | 0 | 1 |
| **All** | **63** | **41** | **13** | **9** | **19** |

After the eight areas were written in Lean, 41 capabilities are in Lean in part, and 18 of the 19 with high rule content. The one left is SHPITL, flights operated by other airlines, which has candidates only. The nine at *Not started* are shopping capabilities with little rule content, such as rich media, affinity shopping and device types, or ones whose pages hold no rule worth writing down (SHPOPE, SHPPER, SHPMOD).

## Second survey round

The second round, on 2026-10-29, read every area's pages in full: the EASD guide's concept pages and worked examples, the ARMI capability pages and general guidance, the Settlement with Orders and Order Accounting guides, and Resolution 797. Eight surveys returned 160 candidates; 22 duplicated each other across areas and were merged, which leaves C-24 to C-161. They are listed in the [ONE Order survey](one-order-survey.md#second-round) and written as blueprint nodes in `blueprint/src/areas/`.

Most of them are vague or silent: the source names the situation and leaves the rule to each airline, or its worked examples disagree with its concept pages. Those become decisions for the business before they can be written in Lean.

## Where to go next

Every area now has rules in Lean, and most of what remains is a decision for the business:

1. **The open questions.** Each open guarantee in the review document, in the chapter Questions from the ONE Order rules, comes with an example that breaks it and the question to answer. An answer becomes a change to the rule, or a choice of reading, and the guarantee can then be proven.
2. **The candidates still marked as needing a decision.** About seventy candidates are not yet in Lean because the sources leave them open; the blueprint node says what needs deciding.
3. **Interline offers** (SHPITL, C-39 and C-40) and the order owner (C-78) are the high-content rules not yet written.
4. **Implementation checks.** The Java and Rust checks cover the pilot rules only. The ONE Order rules can get the same treatment area by area.

## Shopping

| Code | Capability | Status | In the model or blueprint | Rule content |
| --- | --- | --- | --- | --- |
| [SHPFLT](https://retailing.iata.org/armi/docs/SHPFLT/) | Shop for Flights | In Lean, in part | Offer, OfferItem, expiry (OO-001); no shopping or pricing; C-24 to C-29, C-34 to C-36, C-38, C-42 | Medium |
| [SHPOR1](https://retailing.iata.org/armi/docs/SHPOR1/) | Offer Conditions and Restrictions | In Lean, in part | C-30 to C-33 | High |
| [SHPOR2](https://retailing.iata.org/armi/docs/SHPOR2/) | Offer Restrictions | In Lean, in part | C-30 to C-33 | High |
| [SHPBND](https://retailing.iata.org/armi/docs/SHPBND/) | Construct Bundled Offers | In Lean, in part | C-54 to C-56, C-62 | Medium |
| [SHPANC](https://retailing.iata.org/armi/docs/SHPANC/) | Shop For or with Ancillaries | In Lean, in part | OfferItem has a service code only; C-43 to C-45, C-52 to C-53, C-58 to C-59, C-61 to C-62 | Medium |
| [SHPAN2](https://retailing.iata.org/armi/docs/SHPAN2/) | Additional Airline Supplied Ancillaries (e.g. meals, WIFI, lounge, insurance, priority boarding, etc.) | Candidate | C-60 | Low |
| [SHPAN3](https://retailing.iata.org/armi/docs/SHPAN3/) | Additional 3rd Party Ancillaries (e.g. bag pick-up, mobility device, lounge, insurance) | Candidate | C-60 | Low |
| [SHPMOD](https://retailing.iata.org/armi/docs/SHPMOD/) | Transportation Ancillaries (bus, train, etc.) | Not started |  | Low |
| [SHPSTA](https://retailing.iata.org/armi/docs/SHPSTA/) | Seat Map and Availability | In Lean, in part | C-44, C-49 to C-51 | Medium |
| [SHPSTO](https://retailing.iata.org/armi/docs/SHPSTO/) | Seat Options | In Lean, in part | C-44, C-49 | Low |
| [SHPSTP](https://retailing.iata.org/armi/docs/SHPSTP/) | Seat Map and Price Points | In Lean, in part | C-49 to C-53, C-57 | Medium |
| [SHPITL](https://retailing.iata.org/armi/docs/SHPITL/) | Returns Flights Operated by Other Airlines | Candidate | C-39 to C-40 | High |
| [SHPOPE](https://retailing.iata.org/armi/docs/SHPOPE/) | Multi City/Open Jaw Itineraries | Not started |  | Medium |
| [SHPPER](https://retailing.iata.org/armi/docs/SHPPER/) | Personalize Offers Based on Passenger Type, Loyalty Programs or Other Agreements | Not started |  | Medium |
| [SHPDSC](https://retailing.iata.org/armi/docs/SHPDSC/) | Airline Offers Including Discounted Benefits and/or Promotions | In Lean, in part | C-34 | Medium |
| [SHPLOC](https://retailing.iata.org/armi/docs/SHPLOC/) | Airline Offers with Localization (offers in local languages or currencies) | Candidate | Currency and Money exist; no conversion; C-41 | Medium |
| [SHPSRV](https://retailing.iata.org/armi/docs/SHPSRV/) | Use of Airline Taxonomy | Candidate | C-60 | Low |
| [SHPAFF](https://retailing.iata.org/armi/docs/SHPAFF/) | Affinity Shopping | Not started |  | Low |
| [SHPCMA](https://retailing.iata.org/armi/docs/SHPCMA/) | Comparative Shopping for Ancillaries | Not started |  | Low |
| [SHPCMF](https://retailing.iata.org/armi/docs/SHPCMF/) | Comparative Shopping for Flights | Not started |  | Low |
| [SHPRMD](https://retailing.iata.org/armi/docs/SHPRMD/) | Rich Media Included in Offers | Not started |  | Low |
| [SHPDVC](https://retailing.iata.org/armi/docs/SHPDVC/) | Customer Touchpoints / Device Types | Not started |  | Low |

## Order creation

| Code | Capability | Status | In the model or blueprint | Rule content |
| --- | --- | --- | --- | --- |
| [ORDCRE](https://retailing.iata.org/armi/docs/ORDCRE/) | Order Creation With Instant Payment | In Lean, in part | accept (OO-001); payment at creation not modelled; C-62 to C-68, C-75, C-77 to C-80 | High |
| [ORDWPM](https://retailing.iata.org/armi/docs/ORDWPM/) | Create Order Without Payment | In Lean, in part | ONE Order accept (ONE-001) creates services awaiting payment; accept (OO-001); C-11 payment time limit, C-12 commit to pay nothing; C-62 to C-64, C-66 to C-68, C-77 to C-80, C-129 | High |
| [ORDCWT](https://retailing.iata.org/armi/docs/ORDCWT/) | Order Creation Without Tickets/EMDs | In Lean, in part | The model's orders have no tickets or EMDs; C-62 | Medium |
| [ORDGRP](https://retailing.iata.org/armi/docs/ORDGRP/) | Order Management for Groups | Candidate | C-71 | Medium |
| [ORDMSK](https://retailing.iata.org/armi/docs/ORDMSK/) | Ability to Indicate Masked Prices | Not started |  | Low |

## Order information

| Code | Capability | Status | In the model or blueprint | Rule content |
| --- | --- | --- | --- | --- |
| [ORDRET](https://retailing.iata.org/armi/docs/ORDRET/) | Order Information Upon Request | In Lean, in part | C-23 retention; C-69 to C-70, C-72 to C-77 | Low |
| [ORDLST](https://retailing.iata.org/armi/docs/ORDLST/) | Order Information on Multiple Orders | Candidate | C-70 | Low |
| [ORDHIS](https://retailing.iata.org/armi/docs/ORDHIS/) | Historical Information on Orders | In Lean, in part | C-21 order version; C-70, C-72 to C-74, C-76 | Medium |

## Change and cancellation

| Code | Capability | Status | In the model or blueprint | Rule content |
| --- | --- | --- | --- | --- |
| [ORDRSH](https://retailing.iata.org/armi/docs/ORDRSH/) | Seller-Initiated Change to an Order Requiring a Reshop | In Lean, in part | C-18 changing an item, C-19 transfers, C-03, C-04; C-81 to C-84, C-88, C-90, C-93, C-97 | High |
| [ORDPAX](https://retailing.iata.org/armi/docs/ORDPAX/) | Seller-Initiated Change to an Order Not Requiring Reshop | Candidate | C-97 | Medium |
| [ORDNAM](https://retailing.iata.org/armi/docs/ORDNAM/) | Names Changes/Corrections Through Reshopping | Candidate | C-96 to C-97 | Medium |
| [ORDRE2](https://retailing.iata.org/armi/docs/ORDRE2/) | Reshopping for Ancillaries | In Lean, in part | C-43 to C-48, C-50, C-52 to C-53, C-57, C-61 | Medium |
| [ORDCAN](https://retailing.iata.org/armi/docs/ORDCAN/) | Cancel OrderItem | In Lean, in part | C-15 cancelling, C-06 item status; C-81 to C-82, C-85, C-87 to C-91, C-94, C-97 to C-98 | High |
| [ORDCA2](https://retailing.iata.org/armi/docs/ORDCA2/) | Cancel Full Order | In Lean, in part | C-15 cancelling, C-07 order status; C-81, C-85 to C-87, C-91, C-97 to C-98 | High |
| [ORDPEN](https://retailing.iata.org/armi/docs/ORDPEN/) | Seller-initiated Change/Cancel to an Order with penalties applied | In Lean, in part | C-16 cancellation penalty; C-81 to C-85, C-94 to C-95 | High |
| [ORDFOR](https://retailing.iata.org/armi/docs/ORDFOR/) | Seller-initiated Change/Cancel to an Order with forfeited amounts | In Lean, in part | Close to C-16 and C-20; C-81 to C-84, C-90, C-95 | High |
| [ORDREU](https://retailing.iata.org/armi/docs/ORDREU/) | Cancellation of Order Item(s) resulting in Reusable Amount | In Lean, in part | C-20 stored value; C-81, C-86, C-89 to C-90, C-92, C-99 | High |

## Airline-initiated change

| Code | Capability | Status | In the model or blueprint | Rule content |
| --- | --- | --- | --- | --- |
| [ORDOCN](https://retailing.iata.org/armi/docs/ORDOCN/) | Notification of Airline Initiated Changes on an Order | In Lean, in part | C-46, C-100 to C-113 | High |
| [ORDOC2](https://retailing.iata.org/armi/docs/ORDOC2/) | Notification with Advanced Features | In Lean, in part | C-72 to C-75, C-103 to C-104, C-107, C-113 | Medium |

## Delivery

| Code | Capability | Status | In the model or blueprint | Rule content |
| --- | --- | --- | --- | --- |
| [ORDSTS](https://retailing.iata.org/armi/docs/ORDSTS/) | Order Status Change for Service Delivery | In Lean, in part | step (OO-002) in 4 states; C-08 to C-10 for the full status list; C-114, C-116, C-118 to C-120, C-125, C-145 | High |
| [ORDDEL](https://retailing.iata.org/armi/docs/ORDDEL/) | Order Notification for Fulfillment of Services with no Tickets and EMDs | In Lean, in part | C-08 delivery status; C-114 to C-115, C-128 | High |
| [ORDST2](https://retailing.iata.org/armi/docs/ORDST2/) | Order Notification for Fulfillment of Services to the Seller | Candidate | C-121 | Medium |

## Payment

| Code | Capability | Status | In the model or blueprint | Rule content |
| --- | --- | --- | --- | --- |
| [PAYORD](https://retailing.iata.org/armi/docs/PAYORD/) | Pay for an Existing Unpaid Order or Order Items | In Lean, in part | Payment (OO-003); C-11 payment time limit; C-84, C-126, C-128 to C-131, C-140 | High |
| [PAYMIX](https://retailing.iata.org/armi/docs/PAYMIX/) | Pay Using Mixed Payment Instruments | In Lean, in part | C-13 several methods, C-14 amount charged; C-126, C-132 to C-135, C-137, C-140 to C-141 | High |
| [PAYREF](https://retailing.iata.org/armi/docs/PAYREF/) | Refund Amount for Any Change to an Order | In Lean, in part | acceptRefund (OO-003) and the open refund question; C-17 refunds across methods; C-83 to C-84, C-137 to C-138, C-148 | High |
| [PAYRCV](https://retailing.iata.org/armi/docs/PAYRCV/) | Payment Recovery | In Lean, in part | C-127, C-131, C-136, C-139 | Medium |
| [PAYSUM](https://retailing.iata.org/armi/docs/PAYSUM/) | Payment Transaction Summary | In Lean, in part | C-83, C-126 to C-128, C-138 | Low |
| [PAYCPC](https://retailing.iata.org/armi/docs/PAYCPC/) | Pay Using Customer Card | In Lean, in part | C-134 to C-136 | Low |
| [PAYGTW](https://retailing.iata.org/armi/docs/PAYGTW/) | Pay Using Payment Gateway | In Lean, in part | C-127 to C-128, C-130 | Low |
| [PAYSET](https://retailing.iata.org/armi/docs/PAYSET/) | Pay Using Settlement Platform | In Lean, in part | C-127, C-148, C-151 | Medium |
| [PAYVCH](https://retailing.iata.org/armi/docs/PAYVCH/) | Pay Using Vouchers | Candidate | Close to C-20 stored value; C-141 | Medium |
| [PAY3D2](https://retailing.iata.org/armi/docs/PAY3D2/) | Seller Authenticates Payer (3D-Secure v2) | Candidate | C-139 | Low |

## Commission

| Code | Capability | Status | In the model or blueprint | Rule content |
| --- | --- | --- | --- | --- |
| [PAYCOM](https://retailing.iata.org/armi/docs/PAYCOM/) | Disclosure of Commission | In Lean, in part | C-147, C-159 | High |
| [PAYCMT](https://retailing.iata.org/armi/docs/PAYCMT/) | Commitment for Clearance of Commission | In Lean, in part | C-148 to C-150 | Medium |

## Accounting and settlement

| Code | Capability | Status | In the model or blueprint | Rule content |
| --- | --- | --- | --- | --- |
| [ACCSTS](https://retailing.iata.org/armi/docs/ACCSTS/) | Order Status Change for Revenue Recognition | In Lean, in part | C-22 billing after delivery; C-143, C-145 to C-146, C-158 | High |
| [ACCREP](https://retailing.iata.org/armi/docs/ACCREP/) | Accounting Order Sales Information Reporting | Candidate | C-144 | Medium |
| [ACCRE2](https://retailing.iata.org/armi/docs/ACCRE2/) | Accounting Order Sales Reporting with No Tickets and EMDs | In Lean, in part | C-142, C-144, C-146, C-158 | Medium |
| [STTCAP](https://retailing.iata.org/armi/docs/STTCAP/) | Payment Clearance Capture and Notification | In Lean, in part | C-148, C-150 to C-152, C-155, C-160 | Medium |
| [STTCAN](https://retailing.iata.org/armi/docs/STTCAN/) | Payment Clearance Cancellation | In Lean, in part | C-152 to C-153 | Medium |
| [STTSUM](https://retailing.iata.org/armi/docs/STTSUM/) | Payment Summary Management | In Lean, in part | C-152, C-154 to C-156, C-161 | Low |
| [STTHST](https://retailing.iata.org/armi/docs/STTHST/) | Payment Clearance History Management | In Lean, in part | C-156 | Low |

## Setup capabilities left out

One of these, STPOPM, order-level permissions, carries rules about who may act on an order. It belongs with the Identity namespace the model plans, where authorization rules would live.

[STP247](https://retailing.iata.org/armi/docs/STP247/) Order Support 24/7 Team, [STPBG2](https://retailing.iata.org/armi/docs/STPBG2/) Online Bug Tracking Platform, [STPBUG](https://retailing.iata.org/armi/docs/STPBUG/) Bug Tracking, [STPDC2](https://retailing.iata.org/armi/docs/STPDC2/) Online Documentation, [STPDOC](https://retailing.iata.org/armi/docs/STPDOC/) User Documentation, [STPNEG](https://retailing.iata.org/armi/docs/STPNEG/) Negative Test Cases, [STPNTF](https://retailing.iata.org/armi/docs/STPNTF/) Notif Message Setup, [STPOBG](https://retailing.iata.org/armi/docs/STPOBG/) Onboarding, [STPOPM](https://retailing.iata.org/armi/docs/STPOPM/) Order-Level Permissions Management, [STPOSP](https://retailing.iata.org/armi/docs/STPOSP/) Order Support, [STPTSP](https://retailing.iata.org/armi/docs/STPTSP/) Technical Support, [STPTST](https://retailing.iata.org/armi/docs/STPTST/) Sandbox/Testing Environment.
