#!/bin/sh
# Gives nginx a DNS resolver for the flight-data relays in default.conf.
# Those look their upstream hosts up at request time, which nginx can only do
# with an explicit `resolver`; use whatever nameservers this container was given.
set -eu

ns=$(awk '/^nameserver/ { a = $2; if (a ~ /:/) a = "[" a "]"; printf "%s ", a }' \
       /etc/resolv.conf 2>/dev/null || true)
[ -n "$ns" ] || ns="1.1.1.1 8.8.8.8"

echo "resolver ${ns}valid=60s ipv6=off;" > /etc/nginx/conf.d/00-resolver.conf
echo "$0: flight data resolver: ${ns}"
