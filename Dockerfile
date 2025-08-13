# Build stage
FROM node:18-alpine as builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Build the React app
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built app from builder stage
COPY --from=builder /app/build /usr/share/nginx/html

# If build directory doesn't exist, try dist
RUN if [ ! -d /usr/share/nginx/html ] || [ -z "$(ls -A /usr/share/nginx/html)" ]; then \
      rm -rf /usr/share/nginx/html/* && \
      if [ -d /tmp/app/dist ]; then \
        cp -r /tmp/app/dist/* /usr/share/nginx/html/; \
      fi; \
    fi

# Create fallback index.html if needed
RUN if [ ! -f /usr/share/nginx/html/index.html ]; then \
      echo '<!DOCTYPE html><html><head><title>React App</title></head><body><h1>React App</h1><p>Build files not found</p></body></html>' > /usr/share/nginx/html/index.html; \
    fi

# Custom nginx config for React SPA
RUN echo 'server { \
  listen 80; \
  server_name localhost; \
  root /usr/share/nginx/html; \
  index index.html; \
  \
  location / { \
    try_files $uri $uri/ /index.html; \
  } \
  \
  location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ { \
    expires 1y; \
    add_header Cache-Control "public, immutable"; \
  } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
