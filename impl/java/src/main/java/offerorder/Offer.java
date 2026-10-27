package offerorder;

import java.util.List;

/** Priced items shown to a customer, valid until {@code expiresAt} (epoch seconds). */
public record Offer(String id, List<OfferItem> items, long expiresAt, Currency currency) {}
