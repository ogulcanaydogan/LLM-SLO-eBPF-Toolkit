#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DATE="$(date -u +%Y-%m-%d)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${ROOT_DIR}/artifacts/evidence/${STAMP}"
REPORT_PATH="${ROOT_DIR}/docs/benchmarks/reports/e2e-evidence-${DATE}.md"
TEMPLATE_PATH="${EVIDENCE_TEMPLATE:-$ROOT_DIR/docs/benchmarks/reports/e2e-evidence-template.md}"
COMMAND_LOG="${OUT_DIR}/command-transcript.txt"
OUT_DIR_REL="artifacts/evidence/${STAMP}"
RUNBOOK_REL="docs/demos/e2e-evidence-runbook.md"
CHECKLIST_REL="docs/demos/e2e-proof-checklist.md"
CLUSTER_PROFILE="${CLUSTER_PROFILE:-kind-3-node}"
AGENT_MODE="${AGENT_MODE:-probe}"
BACKEND_MODE="${BACKEND_MODE:-stub}"
RUNNER_MODE="${RUNNER_MODE:-unknown}"
RELEASE_GRADE="${RELEASE_GRADE:-false}"
GENERATE_TRAFFIC="${GENERATE_TRAFFIC:-true}"
TRAFFIC_COUNT="${TRAFFIC_COUNT:-50}"

mkdir -p "$OUT_DIR"
: > "$COMMAND_LOG"

record_cmd() {
  printf '%s\n' "$*" >> "$COMMAND_LOG"
}

record_cmd "kubectl -n llm-slo-system get ds llm-slo-agent -o wide"
record_cmd "kubectl -n llm-slo-system get pods -l app=llm-slo-agent -o wide"
record_cmd "kubectl -n observability get pods -o wide"

kubectl -n llm-slo-system get ds llm-slo-agent -o wide > "$OUT_DIR/daemonset.txt"
kubectl -n llm-slo-system get pods -l app=llm-slo-agent -o wide > "$OUT_DIR/agent-pods.txt"
kubectl -n observability get pods -o wide > "$OUT_DIR/observability-pods.txt"

PROM_POD="$(kubectl -n observability get pods -l app=prometheus -o jsonpath='{.items[0].metadata.name}')"
if [[ -z "$PROM_POD" ]]; then
  echo "prometheus pod not found"
  exit 1
fi

if [[ "$GENERATE_TRAFFIC" == "true" ]]; then
  record_cmd "kubectl -n observability port-forward svc/rag-service 18080:8080"
  kubectl -n observability port-forward svc/rag-service 18080:8080 >/tmp/llm-slo-rag-pf.log 2>&1 &
  RAG_PF_PID=$!
  sleep 3
  for i in $(seq 1 "$TRAFFIC_COUNT"); do
    record_cmd "curl -sS --max-time 20 http://127.0.0.1:18080/chat -H content-type:application/json -d {prompt,profile,seed,max_tokens,stream}"
    curl -fsS --max-time 20 http://127.0.0.1:18080/chat \
      -H 'content-type: application/json' \
      -d '{"prompt":"e2e evidence capture","profile":"rag_medium","seed":42,"max_tokens":24,"stream":false}' >/dev/null
  done
  kill "$RAG_PF_PID" >/dev/null 2>&1 || true
fi

record_cmd "kubectl -n observability port-forward pod/${PROM_POD} 19090:9090"
kubectl -n observability port-forward "pod/${PROM_POD}" 19090:9090 >/tmp/llm-slo-prom-pf.log 2>&1 &
PF_PID=$!
cleanup() {
  kill "$PF_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT
sleep 3

query() {
  local q="$1"
  local out="$2"
  curl -fsS -G "http://127.0.0.1:19090/api/v1/query" --data-urlencode "query=${q}" > "$out"
}

query 'rate(llm_ebpf_hello_syscalls_total[5m])' "$OUT_DIR/query_hello_rate.json"
query 'histogram_quantile(0.95, sum by (le)(rate(llm_ebpf_dns_latency_ms_bucket[5m])))' "$OUT_DIR/query_dns_p95.json"
query 'histogram_quantile(0.95, sum by (le)(rate(llm_slo_ttft_ms_bucket[5m])))' "$OUT_DIR/query_ttft_p95.json"
query 'sum(rate(llm_slo_correlation_total{enriched="true"}[5m])) / sum(rate(llm_slo_correlation_total[5m]))' "$OUT_DIR/query_corr_conf.json"
query 'ALERTS{alertname="LLMHighTTFTWithDNSKernelSignal"}' "$OUT_DIR/query_alert.json"

if [[ -f "$TEMPLATE_PATH" ]]; then
  sed "s/<date>/${DATE}/g" "$TEMPLATE_PATH" > "$REPORT_PATH"
else
  cat > "$REPORT_PATH" <<EOF_BASE
# E2E Evidence Report (${DATE})
EOF_BASE
fi

cat >> "$REPORT_PATH" <<EOF_REPORT

## Environment
- Timestamp (UTC): ${STAMP}
- Cluster profile: ${CLUSTER_PROFILE}
- Agent mode: ${AGENT_MODE}
- Backend mode: ${BACKEND_MODE}
- Runner mode: ${RUNNER_MODE}
- Release grade: ${RELEASE_GRADE}
- Stack: Prometheus + Grafana + Tempo + OTel Collector

## DaemonSet Status
\`\`\`text
$(cat "$OUT_DIR/daemonset.txt")
\`\`\`

## Agent Pods
\`\`\`text
$(cat "$OUT_DIR/agent-pods.txt")
\`\`\`

## Query: Hello Tracer Rate
\`\`\`json
$(cat "$OUT_DIR/query_hello_rate.json")
\`\`\`

## Query: DNS p95
\`\`\`json
$(cat "$OUT_DIR/query_dns_p95.json")
\`\`\`

## Query: TTFT p95
\`\`\`json
$(cat "$OUT_DIR/query_ttft_p95.json")
\`\`\`

## Query: Correlation Signal
\`\`\`json
$(cat "$OUT_DIR/query_corr_conf.json")
\`\`\`

## Query: Alert State
\`\`\`json
$(cat "$OUT_DIR/query_alert.json")
\`\`\`

## Command Transcript
\`\`\`text
$(cat "$COMMAND_LOG")
\`\`\`

## Artifact Paths
- Raw outputs: ${OUT_DIR_REL}
- Runbook: ${RUNBOOK_REL}
- Checklist: ${CHECKLIST_REL}
EOF_REPORT

echo "evidence captured"
echo "report: $REPORT_PATH"
echo "artifacts: $OUT_DIR"
