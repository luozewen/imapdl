#!/bin/bash

set -ex

docker exec devel env \
  CFLAGS="$CFLAGS" \
  CXXFLAGS="$CXXFLAGS" \
  LDFLAGS="$LDFLAGS" \
  CMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE" \
  UT_PREFIX="$UT_PREFIX" \
  /srv/src/ci/docker/run.sh
