//! The Rust rules from `impl/rust`, exported to WebAssembly for the try-it
//! panels in the review document.
//!
//! `Verify/RustRules.lean` proves that `step` and `accept_refund` compute what
//! the Lean model computes.  The functions below only translate the page's
//! numbers into those functions' arguments and back; they are not part of the
//! proof.

use offer_order_rules::{accept_refund, step, Currency, DeliveryEvent, DeliveryState, Money, Payment, Refund};

/// The delivery states, in the order the page numbers them.
const STATES: [DeliveryState; 4] = [
    DeliveryState::Ready,
    DeliveryState::Delivered,
    DeliveryState::Cancelled,
    DeliveryState::Refunded,
];

/// The delivery events, in the order the page numbers them.
const EVENTS: [DeliveryEvent; 3] = [DeliveryEvent::Deliver, DeliveryEvent::Cancel, DeliveryEvent::Refund];

/// The state after `event` in `state`, as an index into `STATES`; -1 when the
/// rule refuses the event, and -2 when an index is out of range.
#[no_mangle]
pub extern "C" fn step_index(state: u32, event: u32) -> i32 {
    let (Some(&s), Some(&e)) = (STATES.get(state as usize), EVENTS.get(event as usize)) else {
        return -2;
    };
    match step(s, e) {
        Some(next) => STATES.iter().position(|&x| x == next).map_or(-2, |i| i as i32),
        None => -1,
    }
}

/// 1 if a refund of `refund_amount`, naming payment `refund_payment`, is
/// accepted against payment `payment_id` of `payment_amount`, and 0 if not.
/// Amounts are in minor units of USD.
#[no_mangle]
pub extern "C" fn accept_refund_flag(payment_id: u64, payment_amount: u64, refund_payment: u64, refund_amount: u64) -> u32 {
    let payment = Payment { id: payment_id, order: 1, amount: Money { amount: payment_amount, currency: Currency::Usd } };
    let refund = Refund { id: 1, payment: refund_payment, amount: Money { amount: refund_amount, currency: Currency::Usd } };
    accept_refund(&payment, &refund) as u32
}
