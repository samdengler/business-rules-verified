import Lean

set_option doc.verso false

/-!
# `lake exe oracle`

Loads `Oracle.Handle` from its compiled `.olean` files and runs it in Lean's
interpreter, the same way `lake exe status` evaluates examples.  Importing
the rules directly would make the executable link Mathlib's native code.

    lake exe oracle             one JSON request per line in, one response per line out
    lake exe oracle --vectors   the conformance vectors, one JSON object per line
-/

open Lean

def main (args : List String) : IO UInt32 := do
  initSearchPath (← findSysroot)
  unsafe enableInitializersExecution
  let env ← importModules #[{ module := `Oracle.Handle }] {} (loadExts := true)
  if args.contains "--vectors" then
    let lines ← IO.ofExcept <| unsafe env.evalConst (List String) {} `Oracle.vectorLines
    for l in lines do IO.println l
    return 0
  let handle ← IO.ofExcept <| unsafe env.evalConst (String → String) {} `Oracle.handle
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout
  repeat
    let line ← stdin.getLine
    if line.isEmpty then break
    let line := line.trimAscii.toString
    if line.isEmpty then continue
    stdout.putStrLn (handle line)
    stdout.flush
  return 0
