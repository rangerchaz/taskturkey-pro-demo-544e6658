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

# Copy the entire app maintaining directory structure
COPY --from=builder /app /usr/share/nginx/html/

# Also try copying from build directories if they exist
RUN cp -r /usr/share/nginx/html/build/* /usr/share/nginx/html/ 2>/dev/null || true && \
    cp -r /usr/share/nginx/html/dist/* /usr/share/nginx/html/ 2>/dev/null || true && \
    cp -r /usr/share/nginx/html/frontend-app/build/* /usr/share/nginx/html/ 2>/dev/null || true

# Set your HTML file as the main index
RUN if [ -f /usr/share/nginx/html/mockup-1.html ]; then \
      cp /usr/share/nginx/html/mockup-1.html /usr/share/nginx/html/index.html; \
    fi

# Create system directory and move CSS files there if needed
RUN mkdir -p /usr/share/nginx/html/system && \
    find /usr/share/nginx/html -maxdepth 1 -name "*.css" -exec cp {} /usr/share/nginx/html/system/ \; 2>/dev/null || true

# Show what files we have
RUN echo "Files in nginx directory:" && find /usr/share/nginx/html -type f -name "*.css" -o -name "*.html" | head -20

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
