# ONE Order coverage map

This map lists the capabilities of IATA's ONE Order and NDC standards and how far the model covers each one. It is the second step after the [ONE Order survey](one-order-survey.md): the survey listed rules from nine pages, and this map shows how much of the standard those pages cover.

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
| Shopping | 22 | 1 | 0 | 21 | 3 |
| Order creation | 5 | 2 | 1 | 2 | 2 |
| Order information | 3 | 0 | 2 | 1 | 0 |
| Change and cancellation | 9 | 0 | 5 | 4 | 6 |
| Airline-initiated change | 2 | 0 | 0 | 2 | 1 |
| Delivery | 3 | 1 | 1 | 1 | 2 |
| Payment | 10 | 1 | 2 | 7 | 3 |
| Commission | 2 | 0 | 0 | 2 | 1 |
| Accounting and settlement | 7 | 0 | 1 | 6 | 1 |
| **All** | **63** | **5** | **12** | **46** | **19** |

Of the 19 capabilities with high rule content, 13 are touched by the model or the survey's candidates and 6 are not started.

## Where to go next

The six capabilities with high rule content and nothing in the model are SHPOR1 and SHPOR2 (offer conditions and restrictions), SHPITL (flights operated by other airlines), ORDFOR (changes and cancellations with forfeited amounts), ORDOCN (airline-initiated changes) and PAYCOM (disclosure of commission).

Three directions follow from them:

1. **What the customer is owed on a change or cancellation.** Offer conditions (SHPOR1, SHPOR2) decide whether an item can be changed or refunded and what penalty applies; penalties, forfeited amounts and reusable value (ORDPEN, ORDFOR, ORDREU) follow from them; refunds (PAYREF) close the loop. It extends the open refund question and the survey's change and cancellation candidates, and it is where a formal model is most likely to find cases the business has not decided.
2. **Airline-initiated change.** Schedule changes and disruption (ORDOCN, ORDOC2): what the airline may change, what it must tell the seller, and what the customer may then do.
3. **Money between parties.** Interline offers (SHPITL), commission (PAYCOM, PAYCMT), and accounting and settlement (ACCSTS, ACCREP, the STT capabilities): which party is owed what, and when.

## Shopping

| Code | Capability | Status | In the model or blueprint | Rule content |
| --- | --- | --- | --- | --- |
| [SHPFLT](https://retailing.iata.org/armi/docs/SHPFLT/) | Shop for Flights | In Lean, in part | Offer, OfferItem, expiry (OO-001); no shopping or pricing | Medium |
| [SHPOR1](https://retailing.iata.org/armi/docs/SHPOR1/) | Offer Conditions and Restrictions | Not started |  | High |
| [SHPOR2](https://retailing.iata.org/armi/docs/SHPOR2/) | Offer Restrictions | Not started |  | High |
| [SHPBND](https://retailing.iata.org/armi/docs/SHPBND/) | Construct Bundled Offers | Not started |  | Medium |
| [SHPANC](https://retailing.iata.org/armi/docs/SHPANC/) | Shop For or with Ancillaries | Not started | OfferItem has a service code only | Medium |
| [SHPAN2](https://retailing.iata.org/armi/docs/SHPAN2/) | Additional Airline Supplied Ancillaries (e.g. meals, WIFI, lounge, insurance, priority boarding, etc.) | Not started |  | Low |
| [SHPAN3](https://retailing.iata.org/armi/docs/SHPAN3/) | Additional 3rd Party Ancillaries (e.g. bag pick-up, mobility device, lounge, insurance) | Not started |  | Low |
| [SHPMOD](https://retailing.iata.org/armi/docs/SHPMOD/) | Transportation Ancillaries (bus, train, etc.) | Not started |  | Low |
| [SHPSTA](https://retailing.iata.org/armi/docs/SHPSTA/) | Seat Map and Availability | Not started |  | Medium |
| [SHPSTO](https://retailing.iata.org/armi/docs/SHPSTO/) | Seat Options | Not started |  | Low |
| [SHPSTP](https://retailing.iata.org/armi/docs/SHPSTP/) | Seat Map and Price Points | Not started |  | Medium |
| [SHPITL](https://retailing.iata.org/armi/docs/SHPITL/) | Returns Flights Operated by Other Airlines | Not started |  | High |
| [SHPOPE](https://retailing.iata.org/armi/docs/SHPOPE/) | Multi City/Open Jaw Itineraries | Not started |  | Medium |
| [SHPPER](https://retailing.iata.org/armi/docs/SHPPER/) | Personalize Offers Based on Passenger Type, Loyalty Programs or Other Agreements | Not started |  | Medium |
| [SHPDSC](https://retailing.iata.org/armi/docs/SHPDSC/) | Airline Offers Including Discounted Benefits and/or Promotions | Not started |  | Medium |
| [SHPLOC](https://retailing.iata.org/armi/docs/SHPLOC/) | Airline Offers with Localization (offers in local languages or currencies) | Not started | Currency and Money exist; no conversion | Medium |
| [SHPSRV](https://retailing.iata.org/armi/docs/SHPSRV/) | Use of Airline Taxonomy | Not started |  | Low |
| [SHPAFF](https://retailing.iata.org/armi/docs/SHPAFF/) | Affinity Shopping | Not started |  | Low |
| [SHPCMA](https://retailing.iata.org/armi/docs/SHPCMA/) | Comparative Shopping for Ancillaries | Not started |  | Low |
| [SHPCMF](https://retailing.iata.org/armi/docs/SHPCMF/) | Comparative Shopping for Flights | Not started |  | Low |
| [SHPRMD](https://retailing.iata.org/armi/docs/SHPRMD/) | Rich Media Included in Offers | Not started |  | Low |
| [SHPDVC](https://retailing.iata.org/armi/docs/SHPDVC/) | Customer Touchpoints / Device Types | Not started |  | Low |

## Order creation

| Code | Capability | Status | In the model or blueprint | Rule content |
| --- | --- | --- | --- | --- |
| [ORDCRE](https://retailing.iata.org/armi/docs/ORDCRE/) | Order Creation With Instant Payment | In Lean, in part | accept (OO-001); payment at creation not modelled | High |
| [ORDWPM](https://retailing.iata.org/armi/docs/ORDWPM/) | Create Order Without Payment | Candidate | accept (OO-001); C-11 payment time limit, C-12 commit to pay nothing | High |
| [ORDCWT](https://retailing.iata.org/armi/docs/ORDCWT/) | Order Creation Without Tickets/EMDs | In Lean, in part | The model's orders have no tickets or EMDs | Medium |
| [ORDGRP](https://retailing.iata.org/armi/docs/ORDGRP/) | Order Management for Groups | Not started |  | Medium |
| [ORDMSK](https://retailing.iata.org/armi/docs/ORDMSK/) | Ability to Indicate Masked Prices | Not started |  | Low |

## Order information

| Code | Capability | Status | In the model or blueprint | Rule content |
| --- | --- | --- | --- | --- |
| [ORDRET](https://retailing.iata.org/armi/docs/ORDRET/) | Order Information Upon Request | Candidate | C-23 retention | Low |
| [ORDLST](https://retailing.iata.org/armi/docs/ORDLST/) | Order Information on Multiple Orders | Not started |  | Low |
| [ORDHIS](https://retailing.iata.org/armi/docs/ORDHIS/) | Historical Information on Orders | Candidate | C-21 order version | Medium |

## Change and cancellation

| Code | Capability | Status | In the model or blueprint | Rule content |
| --- | --- | --- | --- | --- |
| [ORDRSH](https://retailing.iata.org/armi/docs/ORDRSH/) | Seller-Initiated Change to an Order Requiring a Reshop | Candidate | C-18 changing an item, C-19 transfers, C-03, C-04 | High |
| [ORDPAX](https://retailing.iata.org/armi/docs/ORDPAX/) | Seller-Initiated Change to an Order Not Requiring Reshop | Not started |  | Medium |
| [ORDNAM](https://retailing.iata.org/armi/docs/ORDNAM/) | Names Changes/Corrections Through Reshopping | Not started |  | Medium |
| [ORDRE2](https://retailing.iata.org/armi/docs/ORDRE2/) | Reshopping for Ancillaries | Not started |  | Medium |
| [ORDCAN](https://retailing.iata.org/armi/docs/ORDCAN/) | Cancel OrderItem | Candidate | C-15 cancelling, C-06 item status | High |
| [ORDCA2](https://retailing.iata.org/armi/docs/ORDCA2/) | Cancel Full Order | Candidate | C-15 cancelling, C-07 order status | High |
| [ORDPEN](https://retailing.iata.org/armi/docs/ORDPEN/) | Seller-initiated Change/Cancel to an Order with penalties applied | Candidate | C-16 cancellation penalty | High |
| [ORDFOR](https://retailing.iata.org/armi/docs/ORDFOR/) | Seller-initiated Change/Cancel to an Order with forfeited amounts | Not started | Close to C-16 and C-20 | High |
| [ORDREU](https://retailing.iata.org/armi/docs/ORDREU/) | Cancellation of Order Item(s) resulting in Reusable Amount | Candidate | C-20 stored value | High |

## Airline-initiated change

| Code | Capability | Status | In the model or blueprint | Rule content |
| --- | --- | --- | --- | --- |
| [ORDOCN](https://retailing.iata.org/armi/docs/ORDOCN/) | Notification of Airline Initiated Changes on an Order | Not started |  | High |
| [ORDOC2](https://retailing.iata.org/armi/docs/ORDOC2/) | Notification with Advanced Features | Not started |  | Medium |

## Delivery

| Code | Capability | Status | In the model or blueprint | Rule content |
| --- | --- | --- | --- | --- |
| [ORDSTS](https://retailing.iata.org/armi/docs/ORDSTS/) | Order Status Change for Service Delivery | In Lean, in part | step (OO-002) in 4 states; C-08 to C-10 for the full status list | High |
| [ORDDEL](https://retailing.iata.org/armi/docs/ORDDEL/) | Order Notification for Fulfillment of Services with no Tickets and EMDs | Candidate | C-08 delivery status | High |
| [ORDST2](https://retailing.iata.org/armi/docs/ORDST2/) | Order Notification for Fulfillment of Services to the Seller | Not started |  | Medium |

## Payment

| Code | Capability | Status | In the model or blueprint | Rule content |
| --- | --- | --- | --- | --- |
| [PAYORD](https://retailing.iata.org/armi/docs/PAYORD/) | Pay for an Existing Unpaid Order or Order Items | Candidate | Payment (OO-003); C-11 payment time limit | High |
| [PAYMIX](https://retailing.iata.org/armi/docs/PAYMIX/) | Pay Using Mixed Payment Instruments | Candidate | C-13 several methods, C-14 amount charged | High |
| [PAYREF](https://retailing.iata.org/armi/docs/PAYREF/) | Refund Amount for Any Change to an Order | In Lean, in part | acceptRefund (OO-003) and the open refund question; C-17 refunds across methods | High |
| [PAYRCV](https://retailing.iata.org/armi/docs/PAYRCV/) | Payment Recovery | Not started |  | Medium |
| [PAYSUM](https://retailing.iata.org/armi/docs/PAYSUM/) | Payment Transaction Summary | Not started |  | Low |
| [PAYCPC](https://retailing.iata.org/armi/docs/PAYCPC/) | Pay Using Customer Card | Not started |  | Low |
| [PAYGTW](https://retailing.iata.org/armi/docs/PAYGTW/) | Pay Using Payment Gateway | Not started |  | Low |
| [PAYSET](https://retailing.iata.org/armi/docs/PAYSET/) | Pay Using Settlement Platform | Not started |  | Medium |
| [PAYVCH](https://retailing.iata.org/armi/docs/PAYVCH/) | Pay Using Vouchers | Not started | Close to C-20 stored value | Medium |
| [PAY3D2](https://retailing.iata.org/armi/docs/PAY3D2/) | Seller Authenticates Payer (3D-Secure v2) | Not started |  | Low |

## Commission

| Code | Capability | Status | In the model or blueprint | Rule content |
| --- | --- | --- | --- | --- |
| [PAYCOM](https://retailing.iata.org/armi/docs/PAYCOM/) | Disclosure of Commission | Not started |  | High |
| [PAYCMT](https://retailing.iata.org/armi/docs/PAYCMT/) | Commitment for Clearance of Commission | Not started |  | Medium |

## Accounting and settlement

| Code | Capability | Status | In the model or blueprint | Rule content |
| --- | --- | --- | --- | --- |
| [ACCSTS](https://retailing.iata.org/armi/docs/ACCSTS/) | Order Status Change for Revenue Recognition | Candidate | C-22 billing after delivery | High |
| [ACCREP](https://retailing.iata.org/armi/docs/ACCREP/) | Accounting Order Sales Information Reporting | Not started |  | Medium |
| [ACCRE2](https://retailing.iata.org/armi/docs/ACCRE2/) | Accounting Order Sales Reporting with No Tickets and EMDs | Not started |  | Medium |
| [STTCAP](https://retailing.iata.org/armi/docs/STTCAP/) | Payment Clearance Capture and Notification | Not started |  | Medium |
| [STTCAN](https://retailing.iata.org/armi/docs/STTCAN/) | Payment Clearance Cancellation | Not started |  | Medium |
| [STTSUM](https://retailing.iata.org/armi/docs/STTSUM/) | Payment Summary Management | Not started |  | Low |
| [STTHST](https://retailing.iata.org/armi/docs/STTHST/) | Payment Clearance History Management | Not started |  | Low |

## Setup capabilities left out

One of these, STPOPM, order-level permissions, carries rules about who may act on an order. It belongs with the Identity namespace the model plans, where authorization rules would live.

[STP247](https://retailing.iata.org/armi/docs/STP247/) Order Support 24/7 Team, [STPBG2](https://retailing.iata.org/armi/docs/STPBG2/) Online Bug Tracking Platform, [STPBUG](https://retailing.iata.org/armi/docs/STPBUG/) Bug Tracking, [STPDC2](https://retailing.iata.org/armi/docs/STPDC2/) Online Documentation, [STPDOC](https://retailing.iata.org/armi/docs/STPDOC/) User Documentation, [STPNEG](https://retailing.iata.org/armi/docs/STPNEG/) Negative Test Cases, [STPNTF](https://retailing.iata.org/armi/docs/STPNTF/) Notif Message Setup, [STPOBG](https://retailing.iata.org/armi/docs/STPOBG/) Onboarding, [STPOPM](https://retailing.iata.org/armi/docs/STPOPM/) Order-Level Permissions Management, [STPOSP](https://retailing.iata.org/armi/docs/STPOSP/) Order Support, [STPTSP](https://retailing.iata.org/armi/docs/STPTSP/) Technical Support, [STPTST](https://retailing.iata.org/armi/docs/STPTST/) Sandbox/Testing Environment.
