#!/bin/bash

set -eux

. "${BASH_SOURCE%/*}"/config.sh

if [[ $CXXFLAGS == *--coverage* || $CFLAGS == *--coverage* ]]; then
  bash <(curl -s https://codecov.io/bash) -f "$build"/coverage.info \
    || echo "Codecov.io reporting failed"
fi
