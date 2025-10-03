# Railway-optimized Dockerfile with security hardening
# syntax=docker/dockerfile:1
FROM python:3.12-slim

# Set environment variables for security and optimization
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONHTTPSVERIFY=1 \
    PORT=8000

# Install minimal system dependencies (Railway optimized)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    build-essential \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create non-root user for security
RUN groupadd -r appuser && \
    useradd -r -g appuser -d /app -s /bin/false appuser

WORKDIR /app

# Copy requirements first for better Docker layer caching
COPY --chown=appuser:appuser requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir wheel && \
    pip install --no-cache-dir -r requirements.txt && \
    # Clean up build dependencies for smaller image
    apt-get remove -y build-essential libffi-dev && \
    apt-get autoremove -y --purge && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy application code with proper ownership
COPY --chown=appuser:appuser . .

# Switch to non-root user for security
USER appuser

# Expose the port (Railway will inject PORT env var at runtime)
EXPOSE $PORT

# Railway-optimized startup command
# Railway injects $PORT dynamically; defaults to 8000 for local development
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000} --workers 1"]
