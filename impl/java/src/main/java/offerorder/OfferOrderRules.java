package offerorder;

import java.util.List;
import java.util.Optional;

/**
 * The Offer and Order rules, written the way a service team would write them.
 * The Lean model in Rules/OfferOrder/ is the specification; the tests in
 * src/test check this class against it.
 */
public final class OfferOrderRules {
  private OfferOrderRules() {}

  /** OO-001: accept an offer at {@code now} (epoch seconds), creating order {@code orderId}. */
  public static AcceptResult accept(Offer offer, long now, String orderId) {
    if (now >= offer.expiresAt()) {
      return new AcceptResult.Rejected(Rejection.EXPIRED);
    }
    if (offer.items().isEmpty()) {
      return new AcceptResult.Rejected(Rejection.EMPTY_OFFER);
    }
    if (offer.items().stream().anyMatch(i -> i.price().currency() != offer.currency())) {
      return new AcceptResult.Rejected(Rejection.MIXED_CURRENCY);
    }
    List<OrderItem> items = offer.items().stream()
        .map(i -> new OrderItem(orderId + "-" + i.id(), i.id(), i.price(), DeliveryState.READY))
        .toList();
    long total = offer.items().stream().mapToLong(i -> i.price().amount()).sum();
    return new AcceptResult.Accepted(
        new Order(orderId, offer.id(), items, new Money(total, offer.currency()), now));
  }

  /** OO-002: the state after {@code event}, or empty when the event is not allowed. */
  public static Optional<DeliveryState> step(DeliveryState state, DeliveryEvent event) {
    return switch (state) {
      case READY -> switch (event) {
        case DELIVER -> Optional.of(DeliveryState.DELIVERED);
        case CANCEL -> Optional.of(DeliveryState.CANCELLED);
        case REFUND -> Optional.empty();
      };
      case CANCELLED -> event == DeliveryEvent.REFUND
          ? Optional.of(DeliveryState.REFUNDED)
          : Optional.empty();
      case DELIVERED, REFUNDED -> Optional.empty();
    };
  }

  /** OO-003: whether {@code refund} is accepted against {@code payment}. */
  public static boolean acceptRefund(Payment payment, Refund refund) {
    return refund.payment().equals(payment.id())
        && refund.amount().amount() <= payment.amount().amount();
  }

  /** The total received in the payments for an order, in minor units. */
  public static long totalPaid(List<Payment> payments, String orderId) {
    return payments.stream()
        .filter(p -> p.order().equals(orderId))
        .mapToLong(p -> p.amount().amount())
        .sum();
  }

  /** The total returned in refunds against the payments for an order, in minor units. */
  public static long totalRefunded(List<Payment> payments, List<Refund> refunds, String orderId) {
    List<String> paymentIds = payments.stream()
        .filter(p -> p.order().equals(orderId))
        .map(Payment::id)
        .toList();
    return refunds.stream()
        .filter(r -> paymentIds.contains(r.payment()))
        .mapToLong(r -> r.amount().amount())
        .sum();
  }
}
