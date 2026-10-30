import VersoManual
import Review

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
  let css ← IO.FS.readFile "Review/review.css"
  let js ← IO.FS.readFile "Review/review.js"
  manualMain (%doc Review) (options := args)
    (config := { config with extraCss := Std.HashSet.ofList [{ css }], extraJs := Std.HashSet.ofList [{ js }] })
