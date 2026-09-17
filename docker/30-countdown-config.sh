#!/bin/sh
# Writes site config from environment variables before nginx starts.
# nginx:alpine runs everything in /docker-entrypoint.d/ at container start.
set -eu

out=/usr/share/nginx/html/config.js

: "${COUNTDOWN_TARGET:=}"
: "${COUNTDOWN_TZ:=}"
: "${COUNTDOWN_LABEL:=}"

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
