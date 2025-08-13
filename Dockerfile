# Build stage
FROM node:18-alpine as builder

WORKDIR /app

# Copy all files
COPY . .

# Find package.json and install if exists
RUN if [ -f package.json ]; then \
      npm install && npm run build; \
    elif [ -f frontend-app/package.json ]; then \
      cd frontend-app && npm install && npm run build; \
    else \
      echo "No package.json found - treating as static files"; \
    fi

# Production stage
FROM nginx:alpine

# Remove default nginx files
RUN rm -rf /usr/share/nginx/html/*

# Copy the entire app to nginx
COPY --from=builder /app /tmp/app

# Copy all files to nginx html directory
RUN cp -r /tmp/app/* /usr/share/nginx/html/ 2>/dev/null || true && \
    cp -r /tmp/app/build/* /usr/share/nginx/html/ 2>/dev/null || true && \
    cp -r /tmp/app/dist/* /usr/share/nginx/html/ 2>/dev/null || true && \
    cp -r /tmp/app/frontend-app/build/* /usr/share/nginx/html/ 2>/dev/null || true

# Set your HTML file as the main index
RUN if [ -f /usr/share/nginx/html/mockup-1.html ]; then \
      cp /usr/share/nginx/html/mockup-1.html /usr/share/nginx/html/index.html; \
    fi

# Copy all CSS, JS, and asset files
RUN find /tmp/app -type f \( -name "*.css" -o -name "*.js" -o -name "*.png" -o -name "*.jpg" -o -name "*.svg" -o -name "*.ico" \) -exec cp {} /usr/share/nginx/html/ \; 2>/dev/null || true

# Show what files we have
RUN echo "Files in nginx directory:" && ls -la /usr/share/nginx/html/

# Clean up
RUN rm -rf /tmp/app

# Custom nginx config
RUN echo 'server { \
  listen 80; \
  root /usr/share/nginx/html; \
  index index.html; \
  location / { \
    try_files $uri $uri/ /index.html; \
  } \
  location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ { \
    expires 1y; \
    add_header Cache-Control "public, immutable"; \
  } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
