import VersoManual
import Review.Status

/-!
The review-doc program renders the review document.

It loads the compiled document when it runs instead of linking it in, like
the status and oracle programs.  Linking it would compile every Mathlib
module the rules import to native code (about 2,800 modules in CI).  Only
Verso and {lit}`Review.Status`, which defines the document's own extensions
and must be compiled in for Verso to render them, are linked.
-/

open Lean
open Verso.Genre Manual

def config : RenderConfig where
  emitTeX := false
  emitHtmlSingle := .no
  emitHtmlMulti := .immediately
  htmlDepth := 1
  sourceLink := some "https://github.com/samdengler/airline-order-verified"

/-- Renders the document with the progress page's look and the site navigation, from the
stylesheet and script in the Review directory.  They are read at run time so that a change to
either needs no rebuild.  Run from the repository root. -/
def main (args : List String) : IO UInt32 := do
  initSearchPath (← findSysroot)
  unsafe enableInitializersExecution
  let env ← importModules #[{ module := `Review }] {} (loadExts := true)
  let doc ← IO.ofExcept <| unsafe env.evalConst (Verso.Doc.VersoDoc Manual) {} (Verso.Doc.docName `Review)
  let css ← IO.FS.readFile "Review/review.css"
  let js ← IO.FS.readFile "Review/review.js"
  manualMain doc.toPart (options := args)
    (config := { config with extraCss := Std.HashSet.ofList [{ css }], extraJs := Std.HashSet.ofList [{ js }] })
