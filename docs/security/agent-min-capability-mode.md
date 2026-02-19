# Agent Min-Capability Mode

This profile provides a non-privileged DaemonSet baseline intended for production hardening pilots where privileged pods are disallowed.

## Apply

```bash
kubectl apply -k deploy/k8s/min-capability
```

## What Changes

- `privileged: false`
- `allowPrivilegeEscalation: false`
- Linux capabilities reduced to:
  - `BPF`
  - `SYS_ADMIN`
  - `SYS_RESOURCE`
- `hostPID: false`
- `hostNetwork: false`
- Reduced default signal set in config:
  - enabled: DNS latency, TCP retransmits
  - disabled by default: runqueue, connect latency, TLS handshake, CPU steal
- Overhead guard reduced to `3%` target.

## Tradeoffs

- Better security posture than privileged mode.
- Lower attribution coverage and less per-process fidelity.
- Some kernels/runtimes may still require additional privileges for full CO-RE probe support.

## Intended Usage

- Use `deploy/k8s` (privileged) for deterministic incident lab and full-signal benchmarking.
- Use `deploy/k8s/min-capability` to evaluate production policy fit before broad rollout.
