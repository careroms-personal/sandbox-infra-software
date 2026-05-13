#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_MANIFEST_DIR="${SCRIPT_DIR}/../argocd/application-settings"

# --- 1. List all ArgoCD application manifests ---
echo "=== ArgoCD Application Manifests ==="
MANIFEST_FILE_LIST=()
while read -r app_manifest; do
  echo "- $(basename "${app_manifest}")"
  MANIFEST_FILE_LIST+=("${app_manifest}")
done < <(find "${APP_MANIFEST_DIR}" -type f -name "*.yaml")

# --- 2. Apply manifests to ArgoCD ---
for manifest in "${MANIFEST_FILE_LIST[@]}"; do
  echo "Processing manifest: ${manifest}"
  kubectl apply -f "${manifest}" --namespace argocd
done
