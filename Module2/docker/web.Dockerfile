# ============================================================================
# SuryaLog Cloud -- Web Dashboard Dockerfile (Module 2)
# Lightweight Nginx static web server with digest pinning & non-root user
# ============================================================================

FROM nginx:1.25-alpine-slim@sha256:22414422d1ba07234d9b784f6453b4f150c0fa573ad0b62e163da12b68488ae1

# Copy static frontend assets
COPY app/web/ /usr/share/nginx/html/

# Create custom Nginx configuration proxying /api/ requests to api:8080
RUN echo 'server { \
    listen 80; \
    server_name localhost; \
    location / { \
        root /usr/share/nginx/html; \
        index index.html; \
    } \
    location /api/ { \
        proxy_pass http://api:8080/; \
        proxy_set_header Host $host; \
        proxy_set_header X-Real-IP $remote_addr; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:80/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
