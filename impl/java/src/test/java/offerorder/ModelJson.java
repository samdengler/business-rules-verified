package offerorder;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.ObjectNode;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Converts between the Java types and the oracle's JSON, and answers an oracle
 * request with the Java implementation.  The JSON shapes are the ones the Lean
 * model derives (see Oracle/Handle.lean).
 */
final class ModelJson {
  static final ObjectMapper MAPPER = new ObjectMapper();
  private static final JsonNodeFactory F = JsonNodeFactory.instance;

  private static final Map<Rejection, String> REJECTIONS = Map.of(
      Rejection.EXPIRED, "expired",
      Rejection.EMPTY_OFFER, "emptyOffer",
      Rejection.MIXED_CURRENCY, "mixedCurrency");

  private ModelJson() {}

  /** Lean names enum constructors in lower camel case. */
  static String leanName(Enum<?> e) {
    return e.name().toLowerCase();
  }

  static <E extends Enum<E>> E fromLeanName(Class<E> type, String name) {
    for (E e : type.getEnumConstants()) {
      if (leanName(e).equals(name)) {
        return e;
      }
    }
    throw new IllegalArgumentException(type.getSimpleName() + " " + name);
  }

  // ---------------------------------------------------------------- to JSON

  static ObjectNode money(Money m) {
    return F.objectNode().put("amount", m.amount()).put("currency", m.currency().name());
  }

  static ObjectNode offer(Offer o) {
    ArrayNode items = F.arrayNode();
    for (OfferItem i : o.items()) {
      ObjectNode item = F.objectNode().put("id", i.id()).put("serviceCode", i.serviceCode());
      item.set("price", money(i.price()));
      item.set("passenger", F.objectNode().put("id", i.passenger().id()));
      items.add(item);
    }
    ObjectNode n = F.objectNode().put("id", o.id()).put("expiresAt", o.expiresAt())
        .put("currency", o.currency().name());
    n.set("items", items);
    return n;
  }

  static ObjectNode order(Order o) {
    ArrayNode items = F.arrayNode();
    for (OrderItem i : o.items()) {
      ObjectNode item = F.objectNode().put("id", i.id()).put("fromOfferItem", i.fromOfferItem())
          .put("delivery", leanName(i.delivery()));
      item.set("price", money(i.price()));
      items.add(item);
    }
    ObjectNode n = F.objectNode().put("id", o.id()).put("fromOffer", o.fromOffer())
        .put("createdAt", o.createdAt());
    n.set("items", items);
    n.set("price", money(o.price()));
    return n;
  }

  static ObjectNode payment(Payment p) {
    ObjectNode n = F.objectNode().put("id", p.id()).put("order", p.order());
    n.set("amount", money(p.amount()));
    return n;
  }

  static ObjectNode refund(Refund r) {
    ObjectNode n = F.objectNode().put("id", r.id()).put("payment", r.payment());
    n.set("amount", money(r.amount()));
    return n;
  }

  // -------------------------------------------------------------- requests

  static ObjectNode acceptRequest(Offer o, long now, String orderId) {
    ObjectNode n = F.objectNode().put("rule", "accept").put("now", now).put("orderId", orderId);
    n.set("offer", offer(o));
    return n;
  }

  static ObjectNode stepRequest(DeliveryState s, DeliveryEvent e) {
    return F.objectNode().put("rule", "step").put("state", leanName(s)).put("event", leanName(e));
  }

  static ObjectNode refundRequest(Payment p, Refund r) {
    ObjectNode n = F.objectNode().put("rule", "acceptRefund");
    n.set("payment", payment(p));
    n.set("refund", refund(r));
    return n;
  }

  static ObjectNode totalsRequest(List<Payment> ps, List<Refund> rs, String orderId) {
    ObjectNode n = F.objectNode().put("rule", "totals").put("orderId", orderId);
    n.set("payments", F.arrayNode().addAll(ps.stream().map(ModelJson::payment).toList()));
    n.set("refunds", F.arrayNode().addAll(rs.stream().map(ModelJson::refund).toList()));
    return n;
  }

  // -------------------------------------------------------------- from JSON

  static Money money(JsonNode n) {
    return new Money(n.get("amount").asLong(), Currency.valueOf(n.get("currency").asText()));
  }

  static Offer offer(JsonNode n) {
    List<OfferItem> items = new ArrayList<>();
    for (JsonNode i : n.get("items")) {
      items.add(new OfferItem(i.get("id").asText(), i.get("serviceCode").asText(),
          money(i.get("price")), new Passenger(i.get("passenger").get("id").asText())));
    }
    return new Offer(n.get("id").asText(), items, n.get("expiresAt").asLong(),
        Currency.valueOf(n.get("currency").asText()));
  }

  static Payment payment(JsonNode n) {
    return new Payment(n.get("id").asText(), n.get("order").asText(), money(n.get("amount")));
  }

  static Refund refund(JsonNode n) {
    return new Refund(n.get("id").asText(), n.get("payment").asText(), money(n.get("amount")));
  }

  // ----------------------------------------------------- the Java answer

  /** The Java implementation's answer to an oracle request, in the oracle's JSON. */
  static JsonNode respond(JsonNode req) {
    ObjectNode out = F.objectNode();
    switch (req.get("rule").asText()) {
      case "accept" -> {
        AcceptResult r = OfferOrderRules.accept(
            offer(req.get("offer")), req.get("now").asLong(), req.get("orderId").asText());
        switch (r) {
          case AcceptResult.Accepted a -> out.set("ok", order(a.order()));
          case AcceptResult.Rejected j -> out.put("error", REJECTIONS.get(j.reason()));
        }
      }
      case "step" -> {
        Optional<DeliveryState> next = OfferOrderRules.step(
            fromLeanName(DeliveryState.class, req.get("state").asText()),
            fromLeanName(DeliveryEvent.class, req.get("event").asText()));
        if (next.isPresent()) {
          out.put("result", leanName(next.get()));
        } else {
          out.putNull("result");
        }
      }
      case "acceptRefund" -> out.put("result",
          OfferOrderRules.acceptRefund(payment(req.get("payment")), refund(req.get("refund"))));
      case "totals" -> {
        List<Payment> ps = new ArrayList<>();
        req.get("payments").forEach(p -> ps.add(payment(p)));
        List<Refund> rs = new ArrayList<>();
        req.get("refunds").forEach(r -> rs.add(refund(r)));
        String orderId = req.get("orderId").asText();
        out.set("result", F.objectNode()
            .put("paid", OfferOrderRules.totalPaid(ps, orderId))
            .put("refunded", OfferOrderRules.totalRefunded(ps, rs, orderId)));
      }
      default -> throw new IllegalArgumentException("unknown rule " + req.get("rule"));
    }
    return normalize(out);
  }

  /** Reparse, so numbers built in Java compare equal to numbers read from the oracle. */
  static JsonNode normalize(JsonNode n) {
    try {
      return MAPPER.readTree(MAPPER.writeValueAsString(n));
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }
}
