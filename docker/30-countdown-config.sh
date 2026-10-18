#!/bin/sh
# Renders the deadline into the served page before nginx starts.
# nginx:alpine runs everything in /docker-entrypoint.d/ at container start.
set -eu

root=/usr/share/nginx/html
template=/usr/share/nginx/template/index.html

: "${COUNTDOWN_TARGET:=}"
: "${COUNTDOWN_TZ:=}"
: "${COUNTDOWN_LABEL:=}"
: "${COUNTDOWN_FLIGHT:=}"
: "${COUNTDOWN_ROUTE:=}"

# The deadline is required. Refusing to start is deliberate: a container that
# came up serving some fallback date would look like a working deploy.
if [ -z "$COUNTDOWN_TARGET" ]; then
  echo "" >&2
  echo "  COUNTDOWN_TARGET is not set - refusing to start." >&2
  echo "" >&2
  echo "  Set it in .env next to docker-compose.yml, for example:" >&2
  echo "      COUNTDOWN_TARGET=2026-10-29T18:00:00" >&2
  echo "      COUNTDOWN_TZ=America/Los_Angeles" >&2
  echo "" >&2
  echo "  Start from .env.example, then: docker compose up -d --build" >&2
  echo "" >&2
  exit 1
fi

# Single quotes would break out of the JS string literals below.
for v in "$COUNTDOWN_TARGET" "$COUNTDOWN_TZ" "$COUNTDOWN_LABEL" "$COUNTDOWN_FLIGHT" "$COUNTDOWN_ROUTE"; do
  case "$v" in
    *\'*|*\*) echo "$0: COUNTDOWN_* values may not contain quotes or backslashes" >&2; exit 1 ;;
  esac
done

# Flight and tail numbers are letters, digits, spaces and dashes, with commas
# between the flights of a connection - anything else is a typo the tracker
# would only fail on hours later, at zero.
case "$COUNTDOWN_FLIGHT" in
  *[!A-Za-z0-9\ ,-]*) echo "$0: COUNTDOWN_FLIGHT '$COUNTDOWN_FLIGHT' is not a flight or tail number (e.g. UA 1, UAL1, N81110, or AS 414, AS 488)" >&2; exit 1 ;;
esac
case "$COUNTDOWN_ROUTE" in
  *[!A-Za-z\ ,\>-]*) echo "$0: COUNTDOWN_ROUTE '$COUNTDOWN_ROUTE' should be airport codes, e.g. SFO-ICN or PIT-SEA-PDX" >&2; exit 1 ;;
esac

started=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

block=$(mktemp)
cat > "$block" <<JS
<script>
  /* Written into the page at container start ($started). This wins over
     config.js, so a cached or stale config.js cannot change the deadline. */
  window.COUNTDOWN = {
    target: '${COUNTDOWN_TARGET}',
    tz: '${COUNTDOWN_TZ}',
    label: '${COUNTDOWN_LABEL}',
    flight: '${COUNTDOWN_FLIGHT}',
    route: '${COUNTDOWN_ROUTE}',
    generatedAt: '${started}'
  };
</script>
JS

# Always render from the pristine template, so restarts stay idempotent.
# `r` then `d` substitutes the file at the placeholder with no escaping worries:
# the values can contain slashes (timezones do) and ampersands safely.
sed -e "/<!--COUNTDOWN_CONFIG-->/r $block" \
    -e "/<!--COUNTDOWN_CONFIG-->/d" \
    "$template" > "$root/index.html"
rm -f "$block"

if ! grep -q "window.COUNTDOWN" "$root/index.html"; then
  echo "$0: failed to inline the deadline into index.html" >&2
  exit 1
fi

# Kept in step for anyone loading site/config.js directly; the page ignores it
# whenever the inlined block above is present.
cat > "$root/config.js" <<JS
// Generated at container start from COUNTDOWN_* environment variables.
window.COUNTDOWN = {
  target: '${COUNTDOWN_TARGET}',
  tz: '${COUNTDOWN_TZ}',
  label: '${COUNTDOWN_LABEL}',
  flight: '${COUNTDOWN_FLIGHT}',
  route: '${COUNTDOWN_ROUTE}',
  generatedAt: '${started}'
};
JS

echo "$0: deadline set to '${COUNTDOWN_TARGET}' ${COUNTDOWN_TZ:+(${COUNTDOWN_TZ})} at $started"
if [ -n "$COUNTDOWN_FLIGHT" ]; then
  echo "$0: tracking flight '${COUNTDOWN_FLIGHT}'${COUNTDOWN_ROUTE:+ (${COUNTDOWN_ROUTE})} after zero"
else
  echo "$0: no COUNTDOWN_FLIGHT set - the page just says TIME'S UP at zero"
fi
