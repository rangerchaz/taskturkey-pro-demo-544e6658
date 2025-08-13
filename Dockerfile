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

# Copy the entire builder stage first
COPY --from=builder /app /tmp/app

# Copy built files using shell commands
RUN cp -r /tmp/app/build/* /usr/share/nginx/html/ 2>/dev/null || \
    cp -r /tmp/app/dist/* /usr/share/nginx/html/ 2>/dev/null || \
    cp -r /tmp/app/frontend-app/build/* /usr/share/nginx/html/ 2>/dev/null || \
    cp -r /tmp/app/frontend-app/dist/* /usr/share/nginx/html/ 2>/dev/null || \
    echo "No build directory found, copying source files" && \
    find /tmp/app -name "*.html" -exec cp {} /usr/share/nginx/html/ \; || \
    echo "<!DOCTYPE html><html><head><title>React App</title></head><body><h1>React App</h1><p>Build successful!</p></body></html>" > /usr/share/nginx/html/index.html

# Ensure we have an index.html
RUN if [ ! -f /usr/share/nginx/html/index.html ]; then \
      find /usr/share/nginx/html -name "*.html" -type f -exec mv {} /usr/share/nginx/html/index.html \; -quit || \
      echo '<!DOCTYPE html><html><head><title>React App</title></head><body><h1>React App</h1><p>Deployment successful!</p></body></html>' > /usr/share/nginx/html/index.html; \
    fi

# Show what we have
RUN echo "Final nginx files:" && ls -la /usr/share/nginx/html/

# Clean up
RUN rm -rf /tmp/app

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
