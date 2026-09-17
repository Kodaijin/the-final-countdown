FROM nginx:alpine

# The whole app is static: one self-contained index.html, no build step.
COPY site/ /usr/share/nginx/html/

# Rewrites config.js from COUNTDOWN_* env vars each time the container starts.
COPY docker/30-countdown-config.sh /docker-entrypoint.d/30-countdown-config.sh
RUN chmod +x /docker-entrypoint.d/30-countdown-config.sh

EXPOSE 80
