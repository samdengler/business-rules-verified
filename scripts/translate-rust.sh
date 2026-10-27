#!/usr/bin/env bash
# Translate impl/rust into Lean with Charon and Aeneas, writing
# Verify/Rust/OfferOrderRules.lean.
#
#   scripts/translate-rust.sh
#
# Uses the Aeneas release pinned below (it bundles Charon), downloaded once
# into .aeneas/, and the nightly Rust toolchain that release names, installed
# with rustup.  Set AENEAS_DIR to use an Aeneas release unpacked elsewhere.
# The Lean dependency on Aeneas in lakefile.toml is pinned to the same commit.
set -euo pipefail
cd "$(dirname "$0")/.."

AENEAS_RELEASE="nightly-2026.10.26-da2b22e"

if [ -z "${AENEAS_DIR:-}" ]; then
  case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) asset=aeneas-macos-aarch64.tar.gz ;;
    Linux-x86_64) asset=aeneas-linux-x86_64.tar.gz ;;
    Linux-aarch64) asset=aeneas-linux-aarch64.tar.gz ;;
    *) echo "no Aeneas release for $(uname -s)-$(uname -m); set AENEAS_DIR" >&2; exit 1 ;;
  esac
  AENEAS_DIR=".aeneas/$AENEAS_RELEASE"
  if [ ! -x "$AENEAS_DIR/aeneas" ]; then
    mkdir -p "$AENEAS_DIR"
    curl -fsSL "https://github.com/AeneasVerif/aeneas/releases/download/$AENEAS_RELEASE/$asset" \
      | tar xz -C "$AENEAS_DIR"
  fi
fi
AENEAS_DIR="$(cd "$AENEAS_DIR" && pwd)"

toolchain="$(sed -n 's/^channel = "\(.*\)"/\1/p' "$AENEAS_DIR/rust-toolchain")"
rustup toolchain list | grep -q "^$toolchain" ||
  rustup toolchain install "$toolchain" --profile minimal --component rustc-dev,llvm-tools,rust-src

mkdir -p build/rust
(cd impl/rust && RUSTUP_TOOLCHAIN="$toolchain" "$AENEAS_DIR/charon" cargo --preset=aeneas \
  --dest-file ../../build/rust/offer_order_rules.llbc)
"$AENEAS_DIR/aeneas" -backend lean -dest Verify/Rust build/rust/offer_order_rules.llbc
