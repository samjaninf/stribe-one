#!/bin/bash

set -xe

rm -f tmp/pids/server.pid

exec bundle exec passenger \
     start \
     -p "${PORT-3000}" \
     --log-file "/dev/stdout" \
     --min-instances "${PASSENGER_MIN_INSTANCES-1}" \
     --max-pool-size "${PASSENGER_MAX_POOL_SIZE-1}"