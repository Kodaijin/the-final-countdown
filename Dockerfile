FROM nginx:alpine

# The whole app is static: one self-contained index.html, no build step.
COPY site/ /usr/share/nginx/html/

# Pristine copy the entrypoint renders from, so restarts are idempotent.
COPY site/index.html /usr/share/nginx/template/index.html

# Serves the page and config.js with Cache-Control: no-store.
COPY docker/default.conf /etc/nginx/conf.d/default.conf

# Inlines the deadline from COUNTDOWN_* env vars each time the container starts.
COPY docker/30-countdown-config.sh /docker-entrypoint.d/30-countdown-config.sh
RUN chmod +x /docker-entrypoint.d/30-countdown-config.sh

EXPOSE 80
