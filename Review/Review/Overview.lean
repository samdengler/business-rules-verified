import VersoManual

open Verso.Genre Manual

#doc (Manual) "Overview" =>
%%%
tag := "overview"
%%%

This document covers one slice of the Offer and Order domain: an offer with priced items and an expiry, the order created when a customer accepts it, the delivery of each service in the order, payments against the order, and refunds against payments.

The slice is written as a Lean model.
Each object is a Lean type, each rule is a Lean function, and each guarantee is a Lean theorem.
A guarantee is either proven, which means Lean checked a proof that it holds for every input, or open, which means it has no proof and is marked as a question for the business.
The one open guarantee has a counterexample: an example the build computes shows the rule as written breaking it.

# Sources

This is a proof of concept built from public material only.
It is not affiliated with or endorsed by IATA, and it is not an implementation of the standard.
The objects follow IATA's public Offers and Orders standard, [ONE Order](https://www.iata.org/en/programs/airline-distribution/retailing/one-order/).
The rules, prices and data are simplified and invented.

# How to read this document

Each requirement has its own chapter: *Accepting an offer*, *Delivery transitions* and *Accepting a refund*.
A requirement chapter gives:

 * the rule, with its EARS statement, user story and acceptance criteria;
 * how each acceptance criterion is checked, and its status;
 * the guarantees Lean proves about the rule;
 * the examples the build computes, as Given, When and Then, with the result Lean computed.

After the requirements, *Open questions* lists what the model could not settle and needs the team to decide, *Objects* describes the offers, orders, payments, and refunds the rules talk about, and *EARS requirements* lists every requirement statement in one table.

Two other pages show the same model, and the bar at the top of every page links both: the [progress page](../) gives the status of every rule and candidate rule, and the [dependency graph](../graph/) shows what each rule depends on.
The [blueprint](../blueprint/index.html), written for the people who work on the Lean, restates the model as numbered definitions and theorems, with a [PDF](../blueprint/print.pdf) for printing.

# What is authored and what is computed

The prose in each docstring is written by a person and reviewed against the Lean by a second person.
The examples, the proven or open status of each guarantee, and the dependency graph are computed by the build.
Nobody types a status or an example result by hand: if the model changes, the build changes them.
