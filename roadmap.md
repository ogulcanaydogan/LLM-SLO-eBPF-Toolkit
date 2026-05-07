# Roadmap

## v1.1.0 — Extended Kernel Probes (target: 2026-06-30)

- Add GPU memory bandwidth probe via NVIDIA NVML integration alongside existing CPU/network probes
- CUDA kernel launch latency tracking for inference workloads on DGX Spark and A100 targets
- New `fault-domain: gpu` classification in Bayesian attribution engine
- `ebpf/probes/gpu_bandwidth.go` — new probe with CO-RE portability for kernel 5.15+

## v1.2.0 — Grafana Integration Pack (target: 2026-08-31)

- Pre-built Grafana dashboard bundle (JSON provisioning) covering all fault domains
- Prometheus `remote_write` sink alongside existing OTel exporter
- Alert rules for SLO burn rate, DNS P99 breach, and TCP retransmit spike
- Helm chart update with Grafana sidecar support

## v2.0.0 — Multi-Cluster Attribution (target: 2026-Q4)

- Cross-cluster trace correlation for federated LLM deployments
- eBPF CO-RE build target for kernel 5.10–6.8 compatibility matrix
- Pluggable attribution backend (replace Bayesian engine with custom scorer)
- GA hardening: FIPS-compliant builds, SBOM attestation, signed release artifacts
