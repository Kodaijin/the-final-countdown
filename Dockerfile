FROM nginx:alpine

# The whole app is static: one self-contained index.html, no build step.
COPY site/ /usr/share/nginx/html/

EXPOSE 80
