# Kubernetes Agent Deployment

Apply agent manifests:

```bash
kubectl apply -k deploy/k8s
```

Apply reduced-risk min-capability profile (non-privileged, reduced signal set):

```bash
kubectl apply -k deploy/k8s/min-capability
```

Delete agent manifests:

```bash
kubectl delete -k deploy/k8s
```

Notes:
- The DaemonSet uses a privileged security context for eBPF access.
- `deploy/k8s/min-capability` removes `privileged: true`, drops all Linux capabilities by default, and enables a reduced capability/signal profile intended for production hardening pilots.
- Update the container image in `deploy/k8s/daemonset.yaml` for your release.
- Default agent args run synthetic stream mode (`--count=0`) in `probe` mode and expose `/metrics` on port `2112`.
- Evidence metrics include:
  - `llm_ebpf_hello_syscalls_total`
  - `llm_ebpf_dns_latency_ms_bucket`
  - `llm_ebpf_probe_events_total`
- Manifests are intended as a baseline and should be adapted to your cluster hardening policy.

Tradeoffs for min-capability profile:
- Improved security posture for production environments that disallow privileged pods.
- Reduced attribution coverage: only DNS and TCP retransmit signals are enabled by default.
- Some kernels/container runtimes may still require additional capabilities or privileged mode for full CO-RE probe coverage.

Check emitted SLO events:

```bash
kubectl -n llm-slo-system logs -l app=llm-slo-agent --tail=20
```

Switch to OTLP output mode:

```bash
./scripts/chaos/set_agent_mode.sh mixed otlp
```
