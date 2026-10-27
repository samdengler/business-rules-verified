import Lean.Data.Json
import Rules

set_option doc.verso false

/-!
# Test oracle

The model's rules behind a JSON interface, so an implementation in another
language can be checked against them.  `lake exe oracle` reads one request
per line on standard input and writes one response per line.  Requests:

    {"rule": "accept", "offer": {...}, "now": 1793102340, "orderId": "ORD-1"}
    {"rule": "step", "state": "ready", "event": "deliver"}
    {"rule": "acceptRefund", "payment": {...}, "refund": {...}}
    {"rule": "totals", "payments": [...], "refunds": [...], "orderId": "ORD-1"}

Responses are `{"ok": order}` or `{"error": rejection}` for `accept`,
`{"result": ...}` for the others, and `{"failure": message}` for a request
the oracle cannot read.  `lake exe oracle --vectors` prints the conformance
vectors: fixed requests with the model's responses.
-/

open Lean Rules.Core Rules.OfferOrder

namespace Oracle

/-- An instant is sent as its epoch seconds. -/
instance : ToJson Instant := ⟨fun i => toJson i.epochSeconds⟩
instance : FromJson Instant := ⟨fun j => (⟨·⟩) <$> fromJson? j⟩

deriving instance ToJson, FromJson for Currency, Money, Passenger, OfferItem, Offer,
  DeliveryState, DeliveryEvent, OrderItem, Order, Rejection, Payment, Refund

/-- The model's answer to one request. -/
def respond (req : Json) : Except String Json := do
  match ← req.getObjValAs? String "rule" with
  | "accept" =>
    let o ← req.getObjValAs? Offer "offer"
    let now ← req.getObjValAs? Instant "now"
    let orderId ← req.getObjValAs? String "orderId"
    return match accept o now orderId with
      | .ok ord => Json.mkObj [("ok", toJson ord)]
      | .error r => Json.mkObj [("error", toJson r)]
  | "step" =>
    let s ← req.getObjValAs? DeliveryState "state"
    let e ← req.getObjValAs? DeliveryEvent "event"
    return Json.mkObj [("result", toJson (step s e))]
  | "acceptRefund" =>
    let p ← req.getObjValAs? Payment "payment"
    let r ← req.getObjValAs? Refund "refund"
    return Json.mkObj [("result", toJson (acceptRefund p r))]
  | "totals" =>
    let ps ← req.getObjValAs? (List Payment) "payments"
    let rs ← req.getObjValAs? (List Refund) "refunds"
    let orderId ← req.getObjValAs? String "orderId"
    return Json.mkObj [("result", Json.mkObj
      [("paid", toJson (totalPaid ps orderId)), ("refunded", toJson (totalRefunded ps rs orderId))])]
  | other => throw s!"unknown rule {other}"

/-- One response line for one request line. -/
def handle (line : String) : String :=
  match Json.parse line >>= respond with
  | .ok j => j.compress
  | .error e => (Json.mkObj [("failure", toJson e)]).compress

def acceptReq (o : Offer) (now : Nat) (orderId : String) : Json :=
  Json.mkObj [("rule", "accept"), ("offer", toJson o), ("now", toJson now), ("orderId", toJson orderId)]

def refundReq (p : Payment) (r : Refund) : Json :=
  Json.mkObj [("rule", "acceptRefund"), ("payment", toJson p), ("refund", toJson r)]

/-- Fixed requests that every implementation must answer as the model does:
the inputs of the `@[case]` examples, the boundaries around them, and every
delivery state and event. -/
def vectorRequests : List (String × Json) :=
  let exp := sampleOffer.expiresAt.epochSeconds
  let eurBag := { sampleOffer with
    items := sampleOffer.items.map fun i =>
      if i.serviceCode = "BAG" then { i with price := ⟨4000, .EUR⟩ } else i }
  [ ("accept before expiry", acceptReq sampleOffer (exp - 60) "ORD-1"),
    ("accept one second before expiry", acceptReq sampleOffer (exp - 1) "ORD-1"),
    ("accept at expiry", acceptReq sampleOffer exp "ORD-2"),
    ("accept after expiry", acceptReq sampleOffer (exp + 1) "ORD-2"),
    ("accept mixed currency", acceptReq eurBag (exp - 60) "ORD-3"),
    ("accept empty offer", acceptReq { sampleOffer with items := [] } (exp - 60) "ORD-4"),
    ("accept empty offer after expiry", acceptReq { sampleOffer with items := [] } (exp + 1) "ORD-4"),
    ("refund below payment", refundReq samplePayment ⟨"REF-1", "PAY-1", ⟨6000, .USD⟩⟩),
    ("refund equal to payment", refundReq samplePayment ⟨"REF-1", "PAY-1", ⟨10000, .USD⟩⟩),
    ("refund above payment", refundReq samplePayment ⟨"REF-1", "PAY-1", ⟨10001, .USD⟩⟩),
    ("refund against another payment", refundReq samplePayment ⟨"REF-1", "PAY-2", ⟨6000, .USD⟩⟩),
    ("totals for two refunds against one payment", Json.mkObj
      [("rule", "totals"), ("payments", toJson [samplePayment]),
       ("refunds", toJson [(⟨"REF-1", "PAY-1", ⟨6000, .USD⟩⟩ : Refund), ⟨"REF-2", "PAY-1", ⟨6000, .USD⟩⟩]),
       ("orderId", "ORD-1")]) ] ++
  ([DeliveryState.ready, .delivered, .cancelled, .refunded].flatMap fun s =>
    [DeliveryEvent.deliver, .cancel, .refund].map fun e =>
      (s!"step {(toJson s).getStr?.toOption.getD ""} {(toJson e).getStr?.toOption.getD ""}",
       Json.mkObj [("rule", "step"), ("state", toJson s), ("event", toJson e)]))

/-- The vectors as JSON lines: a name, the request, and the model's response. -/
def vectorLines : List String :=
  vectorRequests.map fun (name, req) =>
    let resp := (respond req).toOption.getD (Json.mkObj [("failure", "unreadable vector")])
    (Json.mkObj [("name", toJson name), ("request", req), ("response", resp)]).compress

end Oracle
