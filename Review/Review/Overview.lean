import VersoManual

open Verso.Genre Manual

#doc (Manual) "Overview" =>
%%%
tag := "overview"
%%%

This document covers one slice of the Offer and Order domain: an offer with priced items and an expiry, the order created when a customer accepts it, payments against the order, and refunds against payments.

The slice is written as a Lean model.
Each object is a Lean type, each rule is a Lean function, and each guarantee is a Lean theorem.
A guarantee is either proven, which means Lean checked the proof, or open, which means the model found a case where it fails and the business needs to decide what the rule means.

# Sources

This is a proof of concept built from public material only.
It is not affiliated with or endorsed by IATA, and it is not an implementation of the standard.
The objects follow IATA's public Offers and Orders standard, [ONE Order](https://www.iata.org/en/programs/airline-distribution/retailing/one-order/).
The rules, prices and data are simplified and invented.

# How to read this document

The chapters follow the model:

 * *Objects* describes the offers, orders, payments, and refunds the rules talk about.
 * *Rules* gives each decision the system makes, with its EARS requirement statement.
 * *Guarantees* lists the properties claimed for the rules and whether each is proven.
 * *Examples* shows concrete scenarios and the result the model computes for each.
 * *Open questions* lists what the model could not settle and needs the team to decide.

# What is authored and what is computed

The prose in each docstring is written by a person and reviewed against the Lean by a second person.
The examples, the proven or open status of each guarantee, and the dependency graph are computed by the build.
Nobody types a status or an example result by hand: if the model changes, the build changes them.

# The blueprint

The same model is also published as a [blueprint](../blueprint/index.html), with a [dependency graph](../blueprint/dep_graph_document.html) that colors each declaration green when it is defined or proven and leaves open theorems uncolored.
A [PDF version](../blueprint/print.pdf) is available for printing.
The [progress page](../) shows the status of every rule and candidate rule for readers who do not need the Lean.
