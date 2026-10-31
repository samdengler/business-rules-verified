import Lean

set_option doc.verso false

/-!
# `lake exe airline-facts`

Loads `Airline.Evaluate` from its compiled `.olean` files and runs it in
Lean's interpreter, the same way `lake exe oracle` runs the rules.  Importing
the rules directly would make the executable link Mathlib's native code.

    lake exe airline-facts > build/airline-data/facts.json

Prints the facts the airline's pages read: Verified Airline's fares evaluated
with the model's functions.  Exits nonzero, printing nothing on standard
output, if two readings of the guide give different answers for any fact.
-/

open Lean

def main : IO UInt32 := do
  initSearchPath (← findSysroot)
  unsafe enableInitializersExecution
  let env ← importModules #[{ module := `Airline.Evaluate }] {} (loadExts := true)
  let facts ← IO.ofExcept <| unsafe env.evalConst (Except String String) {} `Airline.factsText
  match facts with
  | .ok text =>
    IO.println text
    return 0
  | .error e =>
    IO.eprintln s!"airline-facts: {e}"
    return 1
