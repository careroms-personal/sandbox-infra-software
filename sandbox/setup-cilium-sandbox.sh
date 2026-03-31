#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="d2d-cilium-sandbox"
CONTEXT_NAME="kind-${CLUSTER_NAME}"

echo "=== Creating kind cluster with Cilium config: ${CLUSTER_NAME} ==="
kind create cluster --config "${SCRIPT_DIR}/kind-config/kind-cluster-cilium.yaml"

echo "Switching kubectl context to ${CONTEXT_NAME}"
kubectl config use-context "${CONTEXT_NAME}"

# Get control-plane internal IP for Cilium kube-proxy replacement
API_SERVER_IP="$(kubectl get nodes ${CLUSTER_NAME}-control-plane \
  -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
echo "Control-plane IP: ${API_SERVER_IP}"

echo "=== Installing Cilium ==="
helm repo add cilium https://helm.cilium.io
helm repo update

helm install cilium cilium/cilium \
  --namespace kube-system \
  --version 1.19.2 \
  --values "${SCRIPT_DIR}/helm-values/cilium-values.yaml" \
  --set k8sServiceHost="${API_SERVER_IP}" \
  --wait

echo "Waiting for Cilium to be ready..."
kubectl -n kube-system rollout status daemonset/cilium --timeout=120s

echo "=== Installing ArgoCD ==="
kubectl create namespace argocd

echo "Applying ArgoCD PVCs"
kubectl apply -f "${SCRIPT_DIR}/argocd/kind-pvc.yaml"

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd \
  --namespace argocd \
  --version 9.4.16 \
  --values "${SCRIPT_DIR}/argocd/sandbox-values.yaml" \
  --wait

echo ""
echo "✅ Cilium sandbox setup complete."
