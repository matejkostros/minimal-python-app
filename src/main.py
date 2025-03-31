#!/usr/bin/env python3
"""
Main entry point for the secure Python container.
Starts the WebTest web application with Kubernetes support.
"""
import os
import sys
import logging
from webtest import WebTest
from k8s_utils import get_env_var

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def main():
    """Main entry point for the application"""
    logger.info("Starting secure Python web application with Kubernetes support...")

    # Get configuration from environment variables
    port = int(get_env_var('PORT', 8080))
    host = get_env_var('HOST', '0.0.0.0')

    # Load any additional environment variables that might be needed
    app_name = get_env_var('APP_NAME', 'webtest')
    environment = get_env_var('ENVIRONMENT', 'development')

    # Check if Bottle is available
    try:
        import bottle
        logger.info(f"Bottle version: {bottle.__version__}")
    except ImportError as e:
        logger.error(f"Error importing Bottle: {e}")
        sys.exit(1)

    # Check if Kubernetes client is available
    try:
        import kubernetes
        logger.info(f"Kubernetes client version: {kubernetes.__version__}")
    except ImportError as e:
        logger.warning(f"Kubernetes client not available: {e}")

    # Log environment variables (excluding sensitive ones)
    env_vars = {
        key: value for key, value in os.environ.items()
        if not any(sensitive in key.lower() for sensitive in
                  ['secret', 'password', 'token', 'key', 'cert'])
    }
    logger.info(f"Environment variables: {env_vars}")

    # Start the web application
    try:
        logger.info(f"Starting {app_name} in {environment} environment on {host}:{port}")
        web_app = WebTest(host=host, port=port)
        web_app.run()
    except Exception as e:
        logger.error(f"Error starting web application: {e}", exc_info=True)
        sys.exit(1)

if __name__ == "__main__":
    main()