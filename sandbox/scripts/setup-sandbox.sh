#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="d2d-sandbox"
CONTEXT_NAME="kind-${CLUSTER_NAME}"

echo "=== Creating kind cluster: ${CLUSTER_NAME} ==="
kind create cluster --config "${SCRIPT_DIR}/../kind-config/kind-cluster.yaml"

echo "Switching kubectl context to ${CONTEXT_NAME}"
kubectl config use-context "${CONTEXT_NAME}"

echo "=== Installing ArgoCD ==="
kubectl create namespace argocd

echo "Applying ArgoCD PVCs"
kubectl apply -f "${SCRIPT_DIR}/../argocd/kind-pvc.yaml"

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd \
  --namespace argocd \
  --version 9.4.16 \
  --values "${SCRIPT_DIR}/../argocd/sandbox-values.yaml" \
  --wait

echo ""
echo "✅ Sandbox setup complete."
