#!/usr/bin/env bash
# Compile impl/wasm, the Rust rules exported for the review document's try-it
# panels, to build/try/rules.wasm.
#
#   scripts/build-wasm.sh
#
# Needs rustup; adds the wasm32-unknown-unknown target if it is missing.
set -euo pipefail
cd "$(dirname "$0")/.."

rustup target list --installed | grep -q '^wasm32-unknown-unknown$' ||
  rustup target add wasm32-unknown-unknown
cargo build --quiet --release --target wasm32-unknown-unknown --manifest-path impl/wasm/Cargo.toml
mkdir -p build/try
cp impl/wasm/target/wasm32-unknown-unknown/release/offer_order_rules_wasm.wasm build/try/rules.wasm
