import VersoManual
import Review.Status
import Review.Generated.Front
import Review.Overview
import Review.Generated.OO001
import Review.Generated.OO002
import Review.Generated.OO003
import Review.OpenQuestions
import Review.Objects
import Review.Generated.Ears

open Verso.Genre Manual
open Review

#doc (Manual) "Airline Order: Business Rules for Review" =>
%%%
authors := ["Sam Dengler"]
shortTitle := "Airline Order"
%%%

This document describes the offer and order rules as a Lean model, for review by the Offer/Order team.
There is one chapter per requirement. Every rule, guarantee, and example in them is drawn from the model and checked when the document is built.

```rawHtmlDef
Review.Generated.Front.html
```

{include 1 Review.Overview}

{include 1 Review.Generated.OO001}

{include 1 Review.Generated.OO002}

{include 1 Review.Generated.OO003}

{include 1 Review.OpenQuestions}

{include 1 Review.Objects}

{include 1 Review.Generated.Ears}
