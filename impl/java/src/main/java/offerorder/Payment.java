package offerorder;

/** Money received from the customer against an order. */
public record Payment(String id, String order, Money amount) {}
