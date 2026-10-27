package offerorder;

import java.util.List;
import java.util.stream.IntStream;
import net.jqwik.api.Arbitraries;
import net.jqwik.api.Arbitrary;
import net.jqwik.api.Combinators;

/**
 * Random inputs for the property tests.  Values are kept small and close
 * together (a few currencies, nearby instants, shared payment IDs) so that the
 * interesting cases, such as acceptance exactly at expiry or two refunds
 * against one payment, come up often.
 */
final class Generators {
  private Generators() {}

  static Arbitrary<Currency> currencies() {
    return Arbitraries.frequency(
        net.jqwik.api.Tuple.of(6, Currency.USD),
        net.jqwik.api.Tuple.of(1, Currency.EUR),
        net.jqwik.api.Tuple.of(1, Currency.GBP));
  }

  static Arbitrary<Money> money() {
    return Combinators.combine(Arbitraries.longs().between(0, 50_000), currencies()).as(Money::new);
  }

  static Arbitrary<Offer> offers() {
    Arbitrary<List<Money>> prices = money().list().ofMaxSize(4);
    Arbitrary<Long> expiresAt = Arbitraries.longs().between(1_000, 1_010);
    return Combinators.combine(prices, expiresAt, currencies()).as((ps, exp, cur) ->
        new Offer("OFF-1",
            IntStream.range(0, ps.size())
                .mapToObj(i -> new OfferItem("OI-" + (i + 1), i == 0 ? "FLT" : "BAG", ps.get(i),
                    new Passenger("PAX-1")))
                .toList(),
            exp, cur));
  }

  /** Instants around the offers' expiry, so before, at and after all occur. */
  static Arbitrary<Long> instants() {
    return Arbitraries.longs().between(995, 1_015);
  }

  static Arbitrary<Payment> payments() {
    return Combinators.combine(
            Arbitraries.of("PAY-1", "PAY-2", "PAY-3"),
            Arbitraries.of("ORD-1", "ORD-2"),
            Arbitraries.longs().between(0, 20_000))
        .as((id, order, amount) -> new Payment(id, order, new Money(amount, Currency.USD)));
  }

  static Arbitrary<Refund> refunds() {
    return Combinators.combine(
            Arbitraries.of("REF-1", "REF-2", "REF-3"),
            Arbitraries.of("PAY-1", "PAY-2", "PAY-3"),
            Arbitraries.longs().between(0, 20_000))
        .as((id, payment, amount) -> new Refund(id, payment, new Money(amount, Currency.USD)));
  }

  /** Payments for one order with distinct IDs, as the open theorem assumes. */
  static Arbitrary<List<Payment>> distinctPayments() {
    return payments().list().ofMinSize(1).ofMaxSize(3).uniqueElements(Payment::id)
        .map(ps -> ps.stream().map(p -> new Payment(p.id(), "ORD-1", p.amount())).toList());
  }
}
