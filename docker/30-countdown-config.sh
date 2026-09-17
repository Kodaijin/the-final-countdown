#!/bin/sh
# Writes site config from environment variables before nginx starts.
# nginx:alpine runs everything in /docker-entrypoint.d/ at container start.
set -eu

out=/usr/share/nginx/html/config.js

: "${COUNTDOWN_TARGET:=}"
: "${COUNTDOWN_TZ:=}"
: "${COUNTDOWN_LABEL:=}"

# Nothing configured: keep the defaults baked into the image.
if [ -z "$COUNTDOWN_TARGET" ] && [ -z "$COUNTDOWN_TZ" ] && [ -z "$COUNTDOWN_LABEL" ]; then
  echo "$0: no COUNTDOWN_* variables set, keeping built-in deadline"
  exit 0
fi

# Single quotes would break out of the JS string literals below.
for v in "$COUNTDOWN_TARGET" "$COUNTDOWN_TZ" "$COUNTDOWN_LABEL"; do
  case "$v" in
    *\'*|*\*) echo "$0: COUNTDOWN_* values may not contain quotes or backslashes" >&2; exit 1 ;;
  esac
done

cat > "$out" <<JS
// Generated at container start from COUNTDOWN_* environment variables.
window.COUNTDOWN = {
  target: '${COUNTDOWN_TARGET}',
  tz: '${COUNTDOWN_TZ}',
  label: '${COUNTDOWN_LABEL}'
};
JS

echo "$0: deadline set to '${COUNTDOWN_TARGET}' ${COUNTDOWN_TZ:+(${COUNTDOWN_TZ})}"
