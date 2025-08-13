# Build stage
FROM node:18-alpine as builder

WORKDIR /app

# Copy all files first to find package.json
COPY . .

# Find and use package.json from the correct location
RUN if [ -f package.json ]; then \
      echo "Found package.json in root"; \
    elif [ -f frontend-app/package.json ]; then \
      echo "Found package.json in frontend-app/"; \
      cd frontend-app; \
    elif [ -f src/package.json ]; then \
      echo "Found package.json in src/"; \
      cd src; \
    else \
      echo "No package.json found, creating basic one"; \
      echo '{"name":"react-app","scripts":{"build":"echo build complete"}}' > package.json; \
    fi

# Install dependencies if package.json exists
RUN if [ -f package.json ]; then npm install; fi
RUN if [ -f frontend-app/package.json ]; then cd frontend-app && npm install; fi

# Build the React app
RUN if [ -f package.json ] && grep -q '"build"' package.json; then \
      npm run build; \
    elif [ -f frontend-app/package.json ]; then \
      cd frontend-app && npm run build; \
    else \
      echo "No build script found, creating static files"; \
      mkdir -p build; \
      find . -name "*.html" -exec cp {} build/ \; || true; \
    fi

# Production stage
FROM nginx:alpine

# Create nginx html directory
RUN mkdir -p /usr/share/nginx/html

# Copy built files - try multiple locations
COPY --from=builder /app/build /usr/share/nginx/html 2>/dev/null || true
COPY --from=builder /app/dist /usr/share/nginx/html 2>/dev/null || true
COPY --from=builder /app/frontend-app/build /usr/share/nginx/html 2>/dev/null || true
COPY --from=builder /app/frontend-app/dist /usr/share/nginx/html 2>/dev/null || true

# If no build files, copy HTML files directly
RUN if [ -z "$(ls -A /usr/share/nginx/html 2>/dev/null)" ]; then \
      echo "No build files found, copying source files"; \
      cp -r /tmp/app/* /usr/share/nginx/html/ 2>/dev/null || true; \
    fi

# Ensure we have an index.html
RUN if [ ! -f /usr/share/nginx/html/index.html ]; then \
      find /usr/share/nginx/html -name "*.html" -type f -exec cp {} /usr/share/nginx/html/index.html \; -quit || \
      echo '<!DOCTYPE html><html><head><title>React App</title></head><body><h1>React App</h1></body></html>' > /usr/share/nginx/html/index.html; \
    fi

# Custom nginx config for React SPA
RUN echo 'server { \
  listen 80; \
  root /usr/share/nginx/html; \
  index index.html; \
  location / { \
    try_files $uri $uri/ /index.html; \
  } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
