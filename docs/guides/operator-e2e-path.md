# Canonical Operator Path: Cluster Boot to Evidence Capture

This is the single canonical path for operators to prove end-to-end functionality in privileged mode.

## 1) Bring up the lab cluster and stack

```bash
make kind-up
kubectl apply -k deploy/observability
kubectl apply -k deploy/k8s
kubectl apply -k demo/rag-service/k8s
```

## 2) Enable evidence-grade agent mode

```bash
kubectl -n llm-slo-system set env daemonset/llm-slo-agent \
  EVENT_KIND=probe \
  ENABLE_HELLO_TRACER=true \
  ENABLE_REAL_PROBE_METRICS=true \
  HELLO_TARGET_COMM=rag-service,llama-server
kubectl -n llm-slo-system rollout status daemonset/llm-slo-agent --timeout=180s
```

## 3) Generate deterministic traffic

```bash
kubectl -n observability port-forward svc/rag-service 18080:8080 &
for i in $(seq 1 50); do
  curl -sS http://127.0.0.1:18080/chat \
    -H 'content-type: application/json' \
    -d '{"prompt":"operator e2e proof","profile":"rag_medium","seed":42,"max_tokens":24,"stream":false}' >/dev/null
done
```

## 4) Validate signal chain

Prometheus queries:
- `rate(llm_ebpf_hello_syscalls_total[5m])`
- `histogram_quantile(0.95, sum by (le)(rate(llm_ebpf_dns_latency_ms_bucket[5m])))`
- `histogram_quantile(0.95, sum by (le)(rate(llm_slo_ttft_ms_bucket[5m])))`
- `ALERTS{alertname="LLMHighTTFTWithDNSKernelSignal"}`

## 5) Capture report artifacts

```bash
RUNNER_MODE=full-self-hosted-ebpf \
RELEASE_GRADE=true \
CLUSTER_PROFILE=kind-3-node \
AGENT_MODE=probe \
BACKEND_MODE=stub \
./scripts/demo/capture_evidence.sh
```

Expected outputs:
- `artifacts/evidence/<timestamp>/...`
- `docs/benchmarks/reports/e2e-evidence-<date>.md`

## 6) Optional llama.cpp backend validation

```bash
kubectl apply -k demo/llama-cpp/k8s
kubectl -n observability set env deployment/rag-service \
  LLM_BACKEND=llama_cpp \
  LLAMA_CPP_URL=http://llama-cpp.default.svc.cluster.local:8080
kubectl -n observability rollout status deployment/rag-service --timeout=180s
```

Repeat steps 3–5 with `BACKEND_MODE=llama_cpp`.
