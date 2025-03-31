# Kubernetes-Ready Secure Python Web Application

A minimalist, secure Python web application container with Kubernetes support, featuring:
- No shell in the final image
- No pip in the final image
- No unnecessary binaries
- Kubernetes-ready with health checks
- Environment variable configuration

## Project Structure

```
kubernetes-python-app/
├── Dockerfile           # Multi-stage build Dockerfile
├── requirements.txt     # Minimal Python dependencies
├── kubernetes/          # Kubernetes manifests
│   └── deployment.yaml  # Deployment and Service definition
└── src/                 # Source code directory
    ├── main.py          # Main application entry point
    ├── webtest.py       # Web application using Bottle
    └── k8s_utils.py     # Minimal Kubernetes client utilities
```

## Features

- Based on Google's distroless Python image
- No shell or command-line utilities in the final image
- No package managers (pip) in final image
- Minimal Kubernetes client for cluster interaction
- Optimized for running in Kubernetes
- Kubernetes probes for health and readiness checks
- Environment variable configuration
- Minimal container size

## Building the Container

```bash
docker build -t minimal-k8s-python .
```

## Running Locally

```bash
docker run -p 8080:8080 minimal-k8s-python
```

Then visit `http://localhost:8080` in your browser.

## Deploying to Kubernetes

```bash
# Update the image name in kubernetes/deployment.yaml first
kubectl apply -f kubernetes/deployment.yaml
```

## API Endpoints

- `GET /` - Main page
- `GET /api/status` - Server status (JSON)
- `GET /api/info` - Container information (JSON)
- `GET /api/kubernetes` - Kubernetes information (when running in K8s)
- `GET /healthz` - Health check for Kubernetes liveness probe
- `GET /readyz` - Readiness check for Kubernetes readiness probe

## Environment Variables

| Variable      | Description                  | Default       |
|---------------|------------------------------|---------------|
| `PORT`        | Web server port              | 8080          |
| `HOST`        | Web server host              | 0.0.0.0       |
| `APP_NAME`    | Application name             | webtest       |
| `ENVIRONMENT` | Deployment environment       | development   |
| `POD_NAME`    | Pod name (set by K8s)        | -             |
| `POD_NAMESPACE` | Pod namespace (set by K8s) | -             |

## Security Features

The final container:
- Has NO shell (/bin/sh, /bin/bash, etc.)
- Has NO package managers
- Has NO utilities like curl, wget, nc, etc.
- Contains only the Python runtime and your code
- Runs as a non-root user in Kubernetes
- Drops all Linux capabilities
- No privilege escalation

## Size Optimization

The container is optimized for minimal size:
- Removed Python bytecode and cache files
- Removed test directories
- Stripped binary files
- Only essential dependencies