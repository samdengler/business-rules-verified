package offerorder;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.io.IOException;
import java.util.List;
import net.jqwik.api.Arbitrary;
import net.jqwik.api.ForAll;
import net.jqwik.api.Label;
import net.jqwik.api.Property;
import net.jqwik.api.Provide;
import net.jqwik.api.lifecycle.AfterContainer;
import net.jqwik.api.lifecycle.BeforeContainer;

/**
 * Option 2, property-based testing against the model: jqwik generates
 * thousands of inputs, and for each one the Java code must give the same
 * answer as the Lean model running in {@code lake exe oracle}.
 */
@Label("Java agrees with the Lean model")
class ModelAgreementProperties {
  private static Oracle oracle;

  @BeforeContainer
  static void startOracle() throws IOException {
    oracle = Oracle.start();
  }

  @AfterContainer
  static void stopOracle() throws IOException {
    oracle.close();
  }

  @Property(tries = 2000)
  @Label("accept (OO-001)")
  void accept(@ForAll("offers") Offer offer, @ForAll("instants") long now) {
    var req = ModelJson.acceptRequest(offer, now, "ORD-1");
    assertEquals(oracle.ask(req), ModelJson.respond(req));
  }

  @Property(tries = 200)
  @Label("step (OO-002)")
  void step(@ForAll DeliveryState state, @ForAll DeliveryEvent event) {
    var req = ModelJson.stepRequest(state, event);
    assertEquals(oracle.ask(req), ModelJson.respond(req));
  }

  @Property(tries = 2000)
  @Label("acceptRefund (OO-003)")
  void acceptRefund(@ForAll("payments") Payment payment, @ForAll("refunds") Refund refund) {
    var req = ModelJson.refundRequest(payment, refund);
    assertEquals(oracle.ask(req), ModelJson.respond(req));
  }

  @Property(tries = 1000)
  @Label("totalPaid and totalRefunded")
  void totals(@ForAll("paymentLists") List<Payment> payments, @ForAll("refundLists") List<Refund> refunds) {
    var req = ModelJson.totalsRequest(payments, refunds, "ORD-1");
    assertEquals(oracle.ask(req), ModelJson.respond(req));
  }

  @Provide Arbitrary<Offer> offers() { return Generators.offers(); }
  @Provide Arbitrary<Long> instants() { return Generators.instants(); }
  @Provide Arbitrary<Payment> payments() { return Generators.payments(); }
  @Provide Arbitrary<Refund> refunds() { return Generators.refunds(); }
  @Provide Arbitrary<List<Payment>> paymentLists() { return Generators.payments().list().ofMaxSize(3); }
  @Provide Arbitrary<List<Refund>> refundLists() { return Generators.refunds().list().ofMaxSize(4); }
}
