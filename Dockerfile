FROM ruby:3.2-alpine

# Install system dependencies
RUN apk add --no-cache \
    build-base \
    curl \
    git

# Set working directory
WORKDIR /app

# Copy Gemfile and install dependencies
COPY Gemfile ./
RUN bundle install --without development test

# Copy application code
COPY rtm-mcp.rb ./
COPY README.md ./

# Create non-root user for security
RUN addgroup -g 1001 rtm && \
    adduser -D -u 1001 -G rtm rtm

# Set ownership
RUN chown -R rtm:rtm /app
USER rtm

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Expose port
EXPOSE 8080

# Start command
CMD ["ruby", "rtm-mcp.rb", "--transport=http", "--port=8080"]
