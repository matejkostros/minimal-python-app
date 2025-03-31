# Stage 1: Build dependencies
FROM python:3.11-slim AS builder

WORKDIR /app

# Create and activate virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install dependencies with minimal dependencies
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt && \
    # Remove unnecessary files to reduce size
    find /opt/venv -name '__pycache__' -type d -exec rm -rf {} +; 2>/dev/null || true && \
    find /opt/venv -name '*.pyc' -delete && \
    find /opt/venv -name '*.pyo' -delete && \
    find /opt/venv -name '*.pyd' -delete && \
    find /opt/venv -name 'tests' -type d -exec rm -rf {} +; 2>/dev/null || true && \
    find /opt/venv -name '*.so' -type f -exec strip {} \; 2>/dev/null || true

# Stage 2: Final minimal image - switching to Alpine for better control
FROM python:3.11-alpine AS final

# Copy the virtual environment
COPY --from=builder /opt/venv /opt/venv

# Set working directory
WORKDIR /app

# Copy application code
COPY src/ /app/

# Setup environment
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONPATH="/opt/venv/lib/python3.11/site-packages:/app" \
    VIRTUAL_ENV="/opt/venv" \
    PORT="8080" \
    HOST="0.0.0.0" \
    APP_NAME="webtest" \
    ENVIRONMENT="production" \
    PYTHONDONTWRITEBYTECODE="1" \
    PYTHONUNBUFFERED="1"

# Expose port
EXPOSE 8080

# Run the application
ENTRYPOINT ["python", "/app/main.py"]