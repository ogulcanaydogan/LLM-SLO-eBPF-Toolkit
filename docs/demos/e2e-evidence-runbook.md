# E2E Evidence Runbook (DaemonSet -> Prometheus -> Grafana -> Alert)

## Goal
Prove a full technical chain with one deterministic flow:
1. eBPF agent DaemonSet is running.
2. Hello tracer and DNS probe metrics are present.
3. Metrics are scraped by Prometheus.
4. Grafana dashboard renders the evidence panels.
5. Correlated TTFT + DNS alert fires and then resolves.

## Prerequisites
- kind cluster up (`make kind-up`)
- observability deployed (`kubectl apply -k deploy/observability`)
- agent deployed (`kubectl apply -k deploy/k8s`)
- demo app deployed (`kubectl apply -k demo/rag-service/k8s`)

Optional llama.cpp path:

```bash
kubectl apply -k demo/llama-cpp/k8s
```

## Enable Agent Evidence Path

```bash
kubectl -n llm-slo-system set env daemonset/llm-slo-agent \
  EVENT_KIND=probe \
  ENABLE_HELLO_TRACER=true \
  HELLO_TARGET_COMM=rag-service,llama-server \
  ENABLE_REAL_PROBE_METRICS=true
kubectl -n llm-slo-system rollout status daemonset/llm-slo-agent --timeout=180s
```

## Generate Traffic

```bash
kubectl -n default port-forward svc/rag-service 18080:8080 &
for i in $(seq 1 50); do
  curl -sS http://localhost:18080/chat \
    -H 'content-type: application/json' \
    -d '{"prompt":"show dns impact","profile":"rag_medium","seed":42,"max_tokens":32,"stream":false}' >/dev/null
done
```

For llama.cpp path:

```bash
kubectl -n default set env deployment/rag-service \
  LLM_BACKEND=llama_cpp \
  LLAMA_CPP_URL=http://llama-cpp.default.svc.cluster.local:8080
kubectl -n default rollout status deployment/rag-service --timeout=180s
```

## Trigger DNS Fault (for alert)

```bash
go run ./cmd/faultinject --scenario dns_latency --count 40 --out artifacts/evidence/dns_fault_samples.jsonl
```

## Verify Metrics in Prometheus
Queries:
- `rate(llm_ebpf_hello_syscalls_total[5m])`
- `histogram_quantile(0.95, sum by (le)(rate(llm_ebpf_dns_latency_ms_bucket[5m])))`
- `histogram_quantile(0.95, sum by (le)(rate(llm_slo_ttft_ms_bucket[5m])))`
- `ALERTS{alertname="LLMHighTTFTWithDNSKernelSignal"}`

## Verify Grafana
Import/verify dashboard: `Evidence E2E`.
Panels:
- hello tracer event rate
- DNS p95
- TTFT p95
- correlation confidence trend

## Capture Evidence Bundle

```bash
./scripts/demo/capture_evidence.sh
```

Outputs:
- `artifacts/evidence/<timestamp>/` raw command/query outputs
- `docs/benchmarks/reports/e2e-evidence-<date>.md` summary report
