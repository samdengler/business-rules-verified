import VersoManual
import Review

open Verso.Genre Manual

def config : RenderConfig where
  emitTeX := false
  emitHtmlSingle := .no
  emitHtmlMulti := .immediately
  htmlDepth := 1
  sourceLink := some "https://github.com/samdengler/business-rules-verified"

def main := manualMain (%doc Review) (config := config)
