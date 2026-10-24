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

It writes `build/status.json`, and the EARS table as `build/ears.md` and
`build/ears.csv`.  It exits nonzero if an EARS statement does not follow
exactly one EARS template.
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
  earsId : Option String
  status : String
  /-- Theorems whose statement mentions this declaration. -/
  provenBy : Array Name
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

/-- The EARS templates, as the opening words a statement starts with. -/
def templates : List (String × String) :=
  [("ubiquitous", "The system shall"), ("event-driven", "When "),
   ("state-driven", "While "), ("unwanted behavior", "If "), ("optional", "Where ")]

/-- The template a statement follows, if it follows exactly one.  Every
template but the ubiquitous one must also contain "the system shall". -/
def templateOf (ears : String) : Option String :=
  match templates.filter (fun (_, p) => ears.startsWith p) with
  | [(t, _)] => if t == "ubiquitous" || (ears.splitOn "the system shall").length == 2 then some t else none
  | _ => none

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
    -- Syntax declarations such as `ears` are tooling, not part of the model.
    if ci.type.isConstOf ``ParserDescr || ci.type.isConstOf ``TrailingParserDescr then continue
    let some kind := kindOf env n ci | continue
    let some doc ← findDocString? env n | continue
    let some modIdx := env.getModuleIdxFor? n | continue
    let module := env.header.moduleNames[modIdx.toNat]!
    let value ← if kind == "case" then some <$> evalCase n else pure none
    out := out.push
      { name := n, module, kind, docstring := doc.trimAscii.toString, ears := earsOf doc,
        earsId := Rules.Core.earsAttr.getParam? env n,
        status := ← statusOf n kind, value, provenBy := #[] }
  -- A theorem proves something about every model declaration its statement mentions.
  let theorems := out.filter (·.kind == "theorem")
  out := out.map fun e =>
    { e with provenBy := (theorems.filter fun t =>
        t.name != e.name && ((env.find? t.name).map (·.type.getUsedConstants.contains e.name)).getD false).map (·.name) }
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
     ("ears", toJson e.ears), ("earsId", toJson e.earsId), ("status", toJson e.status),
     ("provenBy", toJson (e.provenBy.map (·.toString)))] ++
    (match e.value with | some v => [("value", toJson v)] | none => [])

def countIn (es : Array Entry) (ns : Name) (status : String) : Nat :=
  (es.filter fun e => ns.isPrefixOf e.name && e.kind == "theorem" && e.status == status).size

/-- Declarations with an EARS statement, ordered by EARS ID. -/
def earsRows (es : Array Entry) : Array Entry :=
  (es.filter (·.ears.isSome)).qsort fun a b => (a.earsId.getD "~") < (b.earsId.getD "~")

def provenByText (es : Array Entry) (e : Entry) (sep : String) (fmt : Name → String) : String :=
  let parts := e.provenBy.toList.map fun t =>
    let isOpen := es.any fun x => x.name == t && x.status == "open"
    fmt t ++ (if isOpen then " (open)" else "")
  if parts.isEmpty then "none" else sep.intercalate parts

def earsTable (es : Array Entry) : String := Id.run do
  let mut s := "| ID | EARS statement | Declaration | Status | Proven by |\n| --- | --- | --- | --- | --- |\n"
  for e in earsRows es do
    let pb := provenByText es e ", " fun t => s!"`{t.getString!}`"
    s := s ++ s!"| {e.earsId.getD ""} | {e.ears.getD ""} | `{e.name}` | {e.status} | {pb} |\n"
  return s

def csvField (s : String) : String :=
  if s.any (fun c => c == ',' || c == '"' || c == '\n') then
    "\"" ++ s.replace "\"" "\"\"" ++ "\""
  else s

def earsCsv (es : Array Entry) : String := Id.run do
  let mut s := "id,ears,declaration,status,proven_by\n"
  for e in earsRows es do
    let pb := provenByText es e "; " toString
    let row := [e.earsId.getD "", e.ears.getD "", e.name.toString, e.status, pb]
    s := s ++ ",".intercalate (row.map csvField) ++ "\n"
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
  IO.FS.writeFile "build/ears.csv" (earsCsv entries)
  let mut ok := true
  for e in earsRows entries do
    if templateOf (e.ears.getD "") |>.isNone then
      IO.eprintln s!"error: the EARS statement of {e.name} does not follow exactly one EARS template"
      ok := false
    if e.earsId.isNone then
      IO.eprintln s!"error: {e.name} has an EARS statement but no @[ears \"ID\"] attribute"
      ok := false
  for ns in roots do
    IO.println s!"{ns}: {countIn entries ns "proven"} proven, {countIn entries ns "open"} open"
  IO.println s!"{entries.size} declarations written to build/status.json; {(earsRows entries).size} EARS rows to build/ears.md and build/ears.csv"
  return if ok then 0 else 1
