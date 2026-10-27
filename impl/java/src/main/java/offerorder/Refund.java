package offerorder;

/** Money returned to the customer against one payment. */
public record Refund(String id, String payment, Money amount) {}
