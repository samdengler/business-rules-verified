package offerorder;

/** An amount in minor units (cents) in one currency. Amounts are never negative. */
public record Money(long amount, Currency currency) {}
