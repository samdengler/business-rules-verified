package offerorder;

/** One purchased service inside an order. */
public record OrderItem(String id, String fromOfferItem, Money price, DeliveryState delivery) {}
