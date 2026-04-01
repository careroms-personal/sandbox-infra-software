#!/bin/bash
set -e

CONTEXT="kind-d2d-cilium-sandbox"

usage() {
  echo "Usage: $0 -n <namespace>[,<namespace>...] [-c <context>]"
  echo "  -n  Comma-separated list of namespaces to forward"
  echo "  -c  kubectl context (default: ${CONTEXT})"
  echo ""
  echo "Example: $0 -n grafana-stack,prometheus-stack,argocd"
  exit 1
}

NAMESPACES=""

while getopts "n:c:" opt; do
  case "${opt}" in
    n) NAMESPACES="${OPTARG}" ;;
    c) CONTEXT="${OPTARG}" ;;
    *) usage ;;
  esac
done

if [[ -z "${NAMESPACES}" ]]; then
  usage
fi

# Build kubefwd args: one -n flag per namespace
KUBEFWD_ARGS=()
IFS=',' read -ra NS_LIST <<< "${NAMESPACES}"
for ns in "${NS_LIST[@]}"; do
  ns="$(echo "${ns}" | tr -d ' ')"
  KUBEFWD_ARGS+=(-n "${ns}")
done

echo "=== Starting kubefwd for namespaces: ${NAMESPACES} (context: ${CONTEXT}) ==="
sudo kubefwd svc --kubeconfig "${HOME}/.kube/config" --context "${CONTEXT}" "${KUBEFWD_ARGS[@]}"
