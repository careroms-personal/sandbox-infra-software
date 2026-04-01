# Cilium fails to start after host restart

## Problem

After restarting the host machine, Cilium agent pods are stuck in `Init:CrashLoopBackOff`.
Init container `config` log shows:

```
Unable to contact k8s api-server ipAddr=https://172.18.0.2:6443
error: dial tcp 172.18.0.2:6443: connect: connection refused
```

## Reason

Docker reassigns IP addresses to KIND node containers on every restart.
The control-plane container moved from `172.18.0.2` → `172.18.0.3` (or any other IP).

Cilium's `k8sServiceHost` was hardcoded to the old IP at install time via `--set k8sServiceHost=<IP>`.
It is stored in the `cilium-config` ConfigMap and injected as env vars into the DaemonSet pods.
After the IP changes, all Cilium agents fail the init step and cannot recover on their own.

## How to fix

### Permanent fix (already applied)

Set `k8sServiceHost` to the Docker container hostname instead of an IP.
Docker always resolves the container name regardless of what IP is assigned.

In `sandbox/helm-values/cilium-values.yaml`:

```yaml
k8sServiceHost: d2d-cilium-sandbox-control-plane
k8sServicePort: 6443
```

Apply via helm upgrade:

```bash
helm upgrade cilium cilium/cilium \
  --namespace kube-system \
  --values /home/careroms/Projects/sandbox-infra-software/sandbox/helm-values/cilium-values.yaml
```

### If it happens again before the permanent fix is applied

1. Find the new control-plane IP:
```bash
docker inspect d2d-cilium-sandbox-control-plane | grep IPAddress
```

2. Patch the ConfigMap:
```bash
kubectl patch configmap cilium-config -n kube-system \
  --type merge \
  -p '{"data":{"k8s-api-server":"https://<NEW_IP>:6443"}}'
```

3. Restart Cilium:
```bash
kubectl rollout restart daemonset/cilium -n kube-system
kubectl rollout restart deployment/cilium-operator -n kube-system
```
