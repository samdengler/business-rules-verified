import VersoManual

/-!
# Status labels and generated HTML

The status role marks a status in the review document. In HTML it becomes a
label with an icon, styled like the statuses on the progress page; in TeX it
is the plain text.

The rawHtml code block puts HTML that the build generated, such as the
delivery state diagram and the try-it panels, into the page as it is.
-/

open Verso Genre Manual
open Verso.Doc.Elab
open Verso.ArgParse
open Lean (Json ToJson)

namespace Review

/-- The icon shown before each status, by kind. -/
def statusIcon : String → String
  | "proven" | "modelled" => "✓"
  | "open" => "!"
  | "example" => "◆"
  | _ => "…"

inline_extension Inline.status (kind : String) where
  data := ToJson.toJson kind
  traverse _ _ _ := pure none
  toTeX := some fun go _ _ content => content.mapM go
  toHtml :=
    open Verso.Output.Html in
    some fun go _ data content => do
      let kind := match data with
        | .str s => s
        | _ => "unknown"
      let classes := s!"status s-{kind}"
      pure {{<span class={{classes}}><span class="ico" aria-hidden="true">{{statusIcon kind}}</span>{{← content.mapM go}}</span>}}

structure StatusArgs where
  kind : String

instance : FromArgs StatusArgs DocElabM where
  fromArgs := StatusArgs.mk <$> .positional `kind .string

/-- A status label. The argument is the kind: {lit}`proven`, {lit}`modelled`, {lit}`open` or {lit}`example`. -/
@[role]
def status : RoleExpanderOf StatusArgs
  | {kind}, content => do
    ``(Verso.Doc.Inline.other (Inline.status $(Lean.quote kind)) #[$[$(← content.mapM elabInline)],*])

block_extension Block.rawHtml (html : String) where
  data := ToJson.toJson html
  traverse _ _ _ := pure none
  toTeX := some fun _ _ _ _ _ => pure .empty
  toHtml :=
    open Verso.Output.Html in
    some fun _ _ _ data _ => do
      match data with
      | .str s => pure (.text false s)
      | _ => pure .empty

/-- HTML written by the build, placed in the page without escaping. Only
generated chapters use it. -/
@[code_block]
def rawHtml : CodeBlockExpanderOf Unit
  | (), str => ``(Verso.Doc.Block.other (Block.rawHtml $(Lean.quote str.getString)) #[])

/-- Like rawHtml, but the block names a generated string constant instead of
holding the HTML.  The front page uses it for the requirement cards, so the
cards change when the generated module does. -/
@[code_block]
def rawHtmlDef : CodeBlockExpanderOf Unit
  | (), str => do
    let name := Lean.mkIdent ((str.getString.replace "\n" "").replace " " "").toName
    ``(Verso.Doc.Block.other (Block.rawHtml $name) #[])

end Review
