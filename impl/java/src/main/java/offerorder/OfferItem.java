package offerorder;

/** One priced service in an offer, for one passenger. */
public record OfferItem(String id, String serviceCode, Money price, Passenger passenger) {}
