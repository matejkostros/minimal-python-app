#!/bin/bash
set -eox
docker build -t minimal-python-app:latest .
docker save minimal-python-app:latest -o minimal-python-app_latest.tar
sudo k3s ctr images import minimal-python-app.tar
kubectl apply -f kubernetes/deployment.yaml