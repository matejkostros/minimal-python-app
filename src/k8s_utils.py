#!/usr/bin/env python3
"""
Minimal Kubernetes utility functions for the web application.
Provides basic interaction with the Kubernetes API.
"""
import os
import logging
from kubernetes import client, config

logger = logging.getLogger(__name__)

class K8sClient:
    """Minimal Kubernetes client for basic cluster interaction"""

    def __init__(self):
        """Initialize the Kubernetes client"""
        self.in_cluster = self._is_in_cluster()
        self._initialize_client()

    def _is_in_cluster(self):
        """Detect if we're running inside a Kubernetes cluster"""
        return os.path.exists('/var/run/secrets/kubernetes.io/serviceaccount/token')

    def _initialize_client(self):
        """Initialize the appropriate Kubernetes client"""
        try:
            if self.in_cluster:
                logger.info("Running in Kubernetes cluster, loading in-cluster config")
                config.load_incluster_config()
            else:
                logger.info("Not running in Kubernetes cluster, using local kubeconfig")
                config.load_kube_config()

            self.core_api = client.CoreV1Api()
            self.running_in_k8s = True
        except Exception as e:
            logger.warning(f"Failed to initialize Kubernetes client: {e}")
            self.running_in_k8s = False

    def get_pod_info(self):
        """Get information about the current pod"""
        if not self.running_in_k8s:
            return {"error": "Not running in Kubernetes"}

        try:
            # Get pod information from environment variables
            namespace = os.environ.get('POD_NAMESPACE', 'default')
            pod_name = os.environ.get('POD_NAME', 'unknown')

            if pod_name != 'unknown':
                pod = self.core_api.read_namespaced_pod(name=pod_name, namespace=namespace)
                return {
                    "pod_name": pod.metadata.name,
                    "namespace": pod.metadata.namespace,
                    "node": pod.spec.node_name,
                    "pod_ip": pod.status.pod_ip,
                    "created": pod.metadata.creation_timestamp.strftime("%Y-%m-%d %H:%M:%S") if pod.metadata.creation_timestamp else None,
                }
            else:
                return {
                    "pod_name": pod_name,
                    "namespace": namespace,
                    "status": "Limited information available"
                }
        except Exception as e:
            logger.error(f"Error getting pod info: {e}")
            return {"error": str(e)}

    def get_cluster_info(self):
        """Get basic information about the Kubernetes cluster"""
        if not self.running_in_k8s:
            return {"error": "Not running in Kubernetes"}

        try:
            version_info = client.VersionApi().get_code()
            return {
                "kubernetes_version": version_info.git_version,
                "platform": version_info.platform,
                "go_version": version_info.go_version
            }
        except Exception as e:
            logger.error(f"Error getting cluster info: {e}")
            return {"error": str(e)}

# Helper function to get environment variables with defaults
def get_env_var(name, default=None):
    """Get environment variable with a default value"""
    return os.environ.get(name, default)