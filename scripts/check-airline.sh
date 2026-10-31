#!/usr/bin/env bash
# Check Verified Airline's wording against this build of the model.  The
# airline's pages have their own repository; this renders them with its
# script from build/airline-data/, which stops if a page cites a requirement
# the model no longer has, calls a criterion still being decided after it is
# proven, or uses an amount the facts lack.
#
#   scripts/check-airline.sh
#
# Uses the checkout in AIRLINE_REPO, or ../verified-airline if there is one,
# and otherwise clones the repository's main branch into build/.
set -euo pipefail
cd "$(dirname "$0")/.."
repo="${AIRLINE_REPO:-../verified-airline}"
if [ ! -f "$repo/scripts/render_airline.py" ]; then
  repo=build/verified-airline
  rm -rf "$repo"
  git clone -q --depth 1 https://github.com/samdengler/verified-airline "$repo"
fi
echo "checking Verified Airline's wording in $repo"
rm -rf build/airline-check
mkdir -p build/airline-check
python3 "$repo/scripts/render_airline.py" --model build/airline-data --out build/airline-check
