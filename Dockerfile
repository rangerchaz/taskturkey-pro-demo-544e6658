# Build stage
FROM node:18-alpine as builder

WORKDIR /app

# Copy package files (adjust path if package.json is in subdirectory)
COPY package*.json ./
# If package.json is in frontend-app/, use: COPY frontend-app/package*.json ./

# Install dependencies
RUN npm install

# Copy source code (adjust if React app is in subdirectory)
COPY . .
# If React app is in frontend-app/, use: COPY frontend-app/ ./

# Build the React app
RUN npm run build

# Production stage
FROM nginx:alpine

# Create a script to copy build files flexibly
RUN echo '#!/bin/sh' > /copy-build.sh && \
    echo 'if [ -d /tmp/builder/build ]; then' >> /copy-build.sh && \
    echo '  echo "Copying from build/ directory"' >> /copy-build.sh && \
    echo '  cp -r /tmp/builder/build/* /usr/share/nginx/html/' >> /copy-build.sh && \
    echo 'elif [ -d /tmp/builder/dist ]; then' >> /copy-build.sh && \
    echo '  echo "Copying from dist/ directory"' >> /copy-build.sh && \
    echo '  cp -r /tmp/builder/dist/* /usr/share/nginx/html/' >> /copy-build.sh && \
    echo 'else' >> /copy-build.sh && \
    echo '  echo "No build or dist directory found!"' >> /copy-build.sh && \
    echo 'fi' >> /copy-build.sh && \
    chmod +x /copy-build.sh

# Copy builder stage to temporary location
COPY --from=builder /app /tmp/builder

# Run the copy script
RUN /copy-build.sh

# Debug: Show what files we copied
RUN echo "Files in nginx html directory:" && ls -la /usr/share/nginx/html/

# Ensure we have an index.html file
RUN if [ ! -f /usr/share/nginx/html/index.html ]; then \
  echo "<!DOCTYPE html><html><head><title>React App</title></head><body><h1>Build Output Missing</h1><p>No React build files found. Check build process.</p><p>Available files:</p><pre>$(ls -la
/tmp/builder/ 2>/dev/null || echo 'No builder files')</pre></body></html>" > /usr/share/nginx/html/index.html; \
fi

# Clean up
RUN rm -rf /tmp/builder /copy-build.sh

# Custom nginx config for React SPA
RUN echo 'server { \
  listen 80; \
  server_name localhost; \
  root /usr/share/nginx/html; \
  index index.html; \
  \
  # Handle React Router \
  location / { \
    try_files $uri $uri/ /index.html; \
  } \
  \
  # Cache static assets \
  location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ { \
    expires 1y; \
    add_header Cache-Control "public, immutable"; \
  } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
