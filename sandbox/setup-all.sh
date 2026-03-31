#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- 1. Docker ---
if ! command -v docker &>/dev/null; then
  echo "=== Installing Docker ==="
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "${USER}"
  sudo systemctl enable docker
  sudo systemctl start docker
  sudo chown root:docker /var/run/docker.sock
  sudo chmod 660 /var/run/docker.sock
  echo "Docker installed: $(docker --version)"
else
  echo "=== Docker already installed: $(docker --version) ==="
fi

# Ensure current shell has docker group
if ! groups | grep -q docker; then
  echo "Activating docker group for current session..."
  exec sg docker "$0"
fi

# --- 2. Host setup (inotify limits) ---
echo "=== Applying inotify limits ==="
sudo sysctl fs.inotify.max_user_watches=524288
sudo sysctl fs.inotify.max_user_instances=512
if ! grep -q "fs.inotify.max_user_watches" /etc/sysctl.conf; then
  echo "fs.inotify.max_user_watches = 524288" | sudo tee -a /etc/sysctl.conf
fi
if ! grep -q "fs.inotify.max_user_instances" /etc/sysctl.conf; then
  echo "fs.inotify.max_user_instances = 512" | sudo tee -a /etc/sysctl.conf
fi

# --- 3. kubectl + Helm ---
if ! command -v kubectl &>/dev/null; then
  echo "=== Installing kubectl ==="
  ARCH="$(uname -m)"
  case "${ARCH}" in
    x86_64)  KUBE_ARCH="amd64" ;;
    aarch64) KUBE_ARCH="arm64" ;;
    *)
      echo "❌ Unsupported architecture: ${ARCH}"
      exit 1
      ;;
  esac
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  KUBECTL_VERSION="$(curl -Ls https://dl.k8s.io/release/stable.txt)"
  curl -Lo /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS}/${KUBE_ARCH}/kubectl"
  chmod +x /tmp/kubectl
  sudo mv /tmp/kubectl /usr/local/bin/kubectl
  echo "kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
  echo "=== kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client) ==="
fi

if ! command -v helm &>/dev/null; then
  echo "=== Installing Helm ==="
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  echo "Helm installed: $(helm version --short)"
else
  echo "=== Helm already installed: $(helm version --short) ==="
fi

# --- 4. KIND ---
if ! command -v kind &>/dev/null; then
  echo "=== Installing KIND ==="
  KIND_VERSION="v0.31.0"
  ARCH="$(uname -m)"
  case "${ARCH}" in
    x86_64)  KIND_ARCH="amd64" ;;
    aarch64) KIND_ARCH="arm64" ;;
    *)
      echo "❌ Unsupported architecture: ${ARCH}"
      exit 1
      ;;
  esac
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  curl -Lo /tmp/kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-${OS}-${KIND_ARCH}"
  chmod +x /tmp/kind
  sudo mv /tmp/kind /usr/local/bin/kind
  echo "KIND installed: $(kind version)"
else
  echo "=== KIND already installed: $(kind version) ==="
fi

# --- 5. kubefwd ---
if ! command -v kubefwd &>/dev/null; then
  echo "=== Installing kubefwd ==="
  ARCH="$(uname -m)"
  case "${ARCH}" in
    x86_64)  KUBEFWD_ARCH="amd64" ;;
    aarch64) KUBEFWD_ARCH="arm64" ;;
    *)
      echo "❌ Unsupported architecture: ${ARCH}"
      exit 1
      ;;
  esac
  KUBEFWD_VERSION="v1.25.13"
  curl -Lo /tmp/kubefwd.deb "https://github.com/txn2/kubefwd/releases/download/${KUBEFWD_VERSION}/kubefwd_${KUBEFWD_ARCH}.deb"
  sudo dpkg -i /tmp/kubefwd.deb
  rm /tmp/kubefwd.deb
  echo "kubefwd installed: $(kubefwd version 2>&1 | head -1)"
else
  echo "=== kubefwd already installed: $(kubefwd version 2>&1 | head -1) ==="
fi

echo ""
echo "✅ Tool installation complete."
echo "   Run ./setup-sandbox.sh        for normal sandbox"
echo "   Run ./setup-cilium-sandbox.sh for Cilium sandbox"
