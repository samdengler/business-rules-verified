package offerorder;

import java.util.List;

/** A customer's purchase: the items of one accepted offer. */
public record Order(String id, String fromOffer, List<OrderItem> items, Money price, long createdAt) {}
