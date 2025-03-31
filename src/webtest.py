#!/usr/bin/env python3
"""
A simple web application module using the Bottle framework.
Kubernetes-compatible with minimal footprint.
"""
import os
import sys
import platform
from bottle import Bottle, route, run, template, response
import logging

# Import Kubernetes utilities
from k8s_utils import K8sClient, get_env_var

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class WebTest:
    def __init__(self, host='0.0.0.0', port=8080):
        self.app = Bottle()
        self.host = host
        self.port = port
        self.app_name = get_env_var('APP_NAME', 'webtest')
        self.environment = get_env_var('ENVIRONMENT', 'development')

        # Initialize Kubernetes client if needed
        self.k8s_client = K8sClient()

        # Setup routes
        self._setup_routes()

    def _setup_routes(self):
        """Set up the web routes"""
        self.app.route('/', callback=self.index)
        self.app.route('/api/status', callback=self.status)
        self.app.route('/api/info', callback=self.info)
        self.app.route('/api/kubernetes', callback=self.kubernetes_info)
        self.app.route('/healthz', callback=self.health_check)
        self.app.route('/readyz', callback=self.readiness_check)

    def index(self):
        """Handle requests to the root path"""
        response.content_type = 'text/html'
        return f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>{self.app_name} - Secure Python Container</title>
            <style>
                body {{
                    font-family: Arial, sans-serif;
                    max-width: 800px;
                    margin: 0 auto;
                    padding: 20px;
                    line-height: 1.6;
                }}
                h1 {{
                    color: #2c3e50;
                }}
                .endpoints {{
                    background-color: #f8f9fa;
                    padding: 15px;
                    border-radius: 5px;
                    margin-top: 20px;
                }}
                .endpoint {{
                    margin-bottom: 10px;
                }}
                .environment {{
                    display: inline-block;
                    padding: 4px 8px;
                    border-radius: 4px;
                    background-color: #e4e7eb;
                    font-size: 14px;
                    font-weight: bold;
                }}
            </style>
        </head>
        <body>
            <h1>{self.app_name} - Secure Python Container</h1>
            <p>
                This is a simple web application running in a secure, minimal Python container.
                <span class="environment">{self.environment}</span>
            </p>

            <div class="endpoints">
                <h2>Available Endpoints:</h2>
                <div class="endpoint">
                    <strong>GET /</strong> - This page
                </div>
                <div class="endpoint">
                    <strong>GET /api/status</strong> - Server status
                </div>
                <div class="endpoint">
                    <strong>GET /api/info</strong> - Container information
                </div>
                <div class="endpoint">
                    <strong>GET /api/kubernetes</strong> - Kubernetes information (if running in K8s)
                </div>
                <div class="endpoint">
                    <strong>GET /healthz</strong> - Health check endpoint (for Kubernetes liveness probe)
                </div>
                <div class="endpoint">
                    <strong>GET /readyz</strong> - Readiness check endpoint (for Kubernetes readiness probe)
                </div>
            </div>
        </body>
        </html>
        """

    def status(self):
        """Return server status as JSON"""
        response.content_type = 'application/json'
        return {
            'status': 'running',
            'service': self.app_name,
            'environment': self.environment
        }

    def info(self):
        """Return information about the container"""
        import bottle

        response.content_type = 'application/json'
        return {
            'python_version': sys.version,
            'platform': platform.platform(),
            'implementation': platform.python_implementation(),
            'bottle_version': bottle.__version__,
            'app_name': self.app_name,
            'environment': self.environment,
            'env_variables': {
                key: value for key, value in os.environ.items()
                if not key.lower() in ('path', 'secret', 'token', 'password', 'key', 'cert')
            }
        }

    def kubernetes_info(self):
        """Return information about the Kubernetes environment"""
        response.content_type = 'application/json'

        result = {
            'running_in_kubernetes': self.k8s_client.running_in_k8s,
        }

        if self.k8s_client.running_in_k8s:
            result.update({
                'pod_info': self.k8s_client.get_pod_info(),
                'cluster_info': self.k8s_client.get_cluster_info()
            })

        return result

    def health_check(self):
        """Kubernetes liveness probe endpoint"""
        response.content_type = 'application/json'
        return {'status': 'healthy'}

    def readiness_check(self):
        """Kubernetes readiness probe endpoint"""
        response.content_type = 'application/json'
        return {'status': 'ready'}

    def run(self):
        """Run the web server"""
        logger.info(f"Starting {self.app_name} server in {self.environment} environment")
        logger.info(f"Listening on http://{self.host}:{self.port}/")
        logger.info("Running in Kubernetes: %s", self.k8s_client.running_in_k8s)

        # Log available endpoints
        logger.info("Available endpoints:")
        logger.info("  - GET /")
        logger.info("  - GET /api/status")
        logger.info("  - GET /api/info")
        logger.info("  - GET /api/kubernetes")
        logger.info("  - GET /healthz")
        logger.info("  - GET /readyz")

        self.app.run(host=self.host, port=self.port)

# Direct execution for testing
if __name__ == "__main__":
    web_test = WebTest()
    web_test.run()