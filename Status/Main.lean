import Lean
import Rules



set_option doc.verso false

/-!
# Status executable

`lake exe status` loads the compiled `Rules` environment and reports, for
every documented declaration under `Rules.Core` and `Rules.OfferOrder`, what
kind of declaration it is, its docstring and EARS statement, and its status.
A theorem's status comes from the axioms it depends on, so nobody can mark a
rule proven by hand.

It writes `build/status.json` and `build/ears.md`.
-/

open Lean Meta

namespace Status

/-- The namespaces whose declarations make up the model. -/
def roots : List Name := [`Rules.Core, `Rules.OfferOrder]

structure Entry where
  name : Name
  module : Name
  kind : String
  docstring : String
  ears : Option String
  status : String
  value : Option String
  deriving Inhabited

/-- The text after `EARS:` in a docstring, up to the first blank line, with
line breaks folded into spaces. -/
def earsOf (doc : String) : Option String := do
  let parts := doc.splitOn "EARS:"
  guard (parts.length ≥ 2)
  let rest := "EARS:".intercalate (parts.drop 1)
  let para := (rest.splitOn "\n\n").head!
  let words := ((para.replace "\n" " ").splitOn " ").filter (!·.isEmpty)
  return " ".intercalate words

def inModel (n : Name) : Bool :=
  roots.any (·.isPrefixOf n) && !n.isInternalDetail

def kindOf (env : Environment) (n : Name) (ci : ConstantInfo) : Option String :=
  if Rules.Core.caseAttr.hasTag env n then some "case" else
  match ci with
  | .thmInfo _ => some "theorem"
  | .axiomInfo _ => some "axiom"
  | .defnInfo _ => some "def"
  | .inductInfo _ => some (if isStructure env n then "structure" else "inductive")
  | _ => none

def usesSorry (n : Name) : CoreM Bool :=
  return (← collectAxioms n).contains ``sorryAx

def statusOf (n : Name) (kind : String) : CoreM String :=
  match kind with
  | "theorem" => return if ← usesSorry n then "open" else "proven"
  | "axiom" => return "assumption"
  | _ => return "definition"

/-- The `Repr` rendering of a case's computed value. -/
def evalCase (n : Name) : MetaM String := do
  let e ← mkAppM ``reprStr #[mkConst n]
  unsafe evalExpr String (mkConst ``String) e

def collect (env : Environment) : MetaM (Array Entry) := do
  let mut out := #[]
  for (n, ci) in env.constants.toList do
    unless inModel n do continue
    if env.isProjectionFn n || (← isInstance n) then continue
    let some kind := kindOf env n ci | continue
    let some doc ← findDocString? env n | continue
    let some modIdx := env.getModuleIdxFor? n | continue
    let module := env.header.moduleNames[modIdx.toNat]!
    let value ← if kind == "case" then some <$> evalCase n else pure none
    out := out.push
      { name := n, module, kind, docstring := doc.trimAscii.toString, ears := earsOf doc,
        status := ← statusOf n kind, value }
  return out.qsort (fun a b => a.name.toString < b.name.toString)

/-- Declarations anywhere under the model's namespaces that depend on `sorry`. -/
def sorryDecls : CoreM (Array Name) := do
  let mut out := #[]
  for (n, ci) in (← getEnv).constants.toList do
    if roots.any (·.isPrefixOf n) && (ci matches .thmInfo _ || ci matches .defnInfo _) then
      if ← usesSorry n then out := out.push n
  return out

def Entry.json (e : Entry) : Json :=
  Json.mkObj <|
    [("name", toJson e.name.toString), ("module", toJson e.module.toString),
     ("kind", toJson e.kind), ("docstring", toJson e.docstring),
     ("ears", toJson e.ears), ("status", toJson e.status)] ++
    (match e.value with | some v => [("value", toJson v)] | none => [])

def countIn (es : Array Entry) (ns : Name) (status : String) : Nat :=
  (es.filter fun e => ns.isPrefixOf e.name && e.kind == "theorem" && e.status == status).size

def earsTable (es : Array Entry) : String := Id.run do
  let mut s := "| EARS statement | Declaration | Status |\n| --- | --- | --- |\n"
  for e in es do
    if let some t := e.ears then
      s := s ++ s!"| {t} | `{e.name}` | {e.status} |\n"
  return s

end Status

open Status in
def main : IO UInt32 := do
  initSearchPath (← findSysroot)
  unsafe enableInitializersExecution
  let env ← importModules #[{ module := `Rules }] {} (loadExts := true)
  let ctx : Core.Context := { fileName := "<status>", fileMap := default }
  let (entries, _) ← (collect env).toIO ctx { env }
  let summary := Json.mkObj <| roots.map fun ns =>
    (ns.toString, Json.mkObj
      [("proven", toJson (countIn entries ns "proven")),
       ("open", toJson (countIn entries ns "open"))])
  IO.FS.createDirAll "build"
  IO.FS.writeFile "build/status.json" <| (Json.mkObj
    [("summary", summary),
     ("declarations", Json.arr (entries.map (·.json)))]).pretty ++ "\n"
  IO.FS.writeFile "build/ears.md" (earsTable entries)
  for ns in roots do
    IO.println s!"{ns}: {countIn entries ns "proven"} proven, {countIn entries ns "open"} open"
  IO.println s!"{entries.size} declarations written to build/status.json and build/ears.md"
  return 0
