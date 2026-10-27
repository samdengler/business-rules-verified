//! The Offer and Order rules in Rust, for the third implementation check.
//!
//! Charon and Aeneas translate this file into Lean (`Verify/Rust/`), and
//! `Verify/RustRules.lean` proves that the translation computes what the Lean
//! model in `Rules/OfferOrder/` computes, for every input.
//!
//! Aeneas handles enums, integers and structs, and not strings, so references
//! are numbers here where the model uses strings.  The proofs hold for any
//! way of naming those numbers as strings that gives different numbers
//! different names.

/// Where a purchased service is in its life.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum DeliveryState {
    Ready,
    Delivered,
    Cancelled,
    Refunded,
}

/// Something that happens to a purchased service.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum DeliveryEvent {
    Deliver,
    Cancel,
    Refund,
}

/// OO-002: the state after `event`, or `None` when the event is not allowed.
pub fn step(state: DeliveryState, event: DeliveryEvent) -> Option<DeliveryState> {
    match (state, event) {
        (DeliveryState::Ready, DeliveryEvent::Deliver) => Some(DeliveryState::Delivered),
        (DeliveryState::Ready, DeliveryEvent::Cancel) => Some(DeliveryState::Cancelled),
        (DeliveryState::Cancelled, DeliveryEvent::Refund) => Some(DeliveryState::Refunded),
        _ => None,
    }
}

/// The currencies prices are quoted in.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Currency {
    Usd,
    Eur,
    Gbp,
}

/// An amount in minor units (cents) in one currency.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Money {
    pub amount: u64,
    pub currency: Currency,
}

/// Money received from the customer against an order.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Payment {
    pub id: u64,
    pub order: u64,
    pub amount: Money,
}

/// Money returned to the customer against one payment.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Refund {
    pub id: u64,
    pub payment: u64,
    pub amount: Money,
}

/// OO-003: whether `refund` is accepted against `payment`.
pub fn accept_refund(payment: &Payment, refund: &Refund) -> bool {
    refund.payment == payment.id && refund.amount.amount <= payment.amount.amount
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn delivered_service_cannot_be_cancelled() {
        assert_eq!(step(DeliveryState::Delivered, DeliveryEvent::Cancel), None);
    }

    #[test]
    fn refund_up_to_the_payment_is_accepted() {
        let usd = |amount| Money { amount, currency: Currency::Usd };
        let p = Payment { id: 1, order: 1, amount: usd(10_000) };
        assert!(accept_refund(&p, &Refund { id: 1, payment: 1, amount: usd(10_000) }));
        assert!(!accept_refund(&p, &Refund { id: 2, payment: 1, amount: usd(10_001) }));
        assert!(!accept_refund(&p, &Refund { id: 3, payment: 2, amount: usd(6_000) }));
    }
}
