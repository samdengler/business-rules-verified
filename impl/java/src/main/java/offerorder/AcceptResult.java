package offerorder;

/** The outcome of accepting an offer: an order, or the reason it was rejected. */
public sealed interface AcceptResult {
  record Accepted(Order order) implements AcceptResult {}

  record Rejected(Rejection reason) implements AcceptResult {}
}
