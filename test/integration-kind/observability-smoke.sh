#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ "$(uname -s | tr '[:upper:]' '[:lower:]')" != "linux" ]]; then
  echo "kind observability smoke skipped: linux required"
  exit 0
fi

for tool in kind kubectl; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "kind observability smoke skipped: $tool not installed"
    exit 0
  fi
done

cd "$ROOT_DIR"

collector_log_records_sum() {
  awk '
    /^#/ { next }
    {
      metric=$1
      value=$NF
      if (metric ~ /^otelcol_receiver_(accepted|received)_log_records(_total)?\{/ && metric ~ /receiver="otlp"/) {
        sum += value
      } else if (metric ~ /^otelcol_receiver_(accepted|received)_logs(_total)?\{/ && metric ~ /receiver="otlp"/) {
        sum += value
      }
    }
    END { printf "%.6f", sum + 0 }
  '
}

agent_probe_events_sum() {
  awk '
    /^#/ { next }
    /^llm_ebpf_probe_events_total\{/ { sum += $NF }
    END { printf "%.6f", sum + 0 }
  '
}

agent_probe_kind_value() {
  awk '
    /^#/ { next }
    /^llm_slo_agent_event_kind\{.*kind="probe".*\}/ {
      print $NF
      found = 1
      exit
    }
    END {
      if (!found) {
        print "0"
      }
    }
  '
}

# If a kind cluster already exists (e.g. nightly CI pre-deploys), skip cluster
# creation and manifest application — go straight to the smoke assertions.
if kind get clusters 2>/dev/null | grep -q "llm-slo-lab"; then
  echo "kind cluster 'llm-slo-lab' already exists, skipping setup"
else
  make kind-up
  kubectl apply -k deploy/observability
  kubectl apply -k deploy/k8s
fi

if [[ -n "${AGENT_IMAGE:-}" ]]; then
  kubectl -n llm-slo-system set image daemonset/llm-slo-agent "agent=${AGENT_IMAGE}"
fi

kubectl -n observability rollout status deployment/otel-collector --timeout=180s
kubectl -n observability rollout status deployment/prometheus --timeout=180s
kubectl -n observability rollout status deployment/grafana --timeout=180s
kubectl -n llm-slo-system rollout status daemonset/llm-slo-agent --timeout=180s

./scripts/chaos/set_agent_mode.sh mixed otlp

# Wait for the rolling restart triggered by set_agent_mode.sh to complete,
# then give agents time to emit events to the OTel collector.
kubectl -n llm-slo-system rollout status daemonset/llm-slo-agent --timeout=180s
kubectl -n llm-slo-system get pods -l app=llm-slo-agent

AGENT_POD="$(kubectl -n llm-slo-system get pods -l app=llm-slo-agent -o jsonpath='{.items[0].metadata.name}')"
if [[ -z "$AGENT_POD" ]]; then
  echo "failed to resolve agent pod"
  exit 1
fi

COLLECTOR_POD="$(kubectl -n observability get pods -l app=otel-collector -o jsonpath='{.items[0].metadata.name}')"
if [[ -z "$COLLECTOR_POD" ]]; then
  echo "failed to resolve otel-collector pod"
  exit 1
fi

METRICS_PATH="/api/v1/namespaces/llm-slo-system/pods/${AGENT_POD}:2112/proxy/metrics"
COLLECTOR_METRICS_PATH="/api/v1/namespaces/observability/pods/${COLLECTOR_POD}:8888/proxy/metrics"
METRICS_RAW="$(kubectl get --raw "$METRICS_PATH")"
echo "$METRICS_RAW" | grep -q "llm_slo_agent_signal_enabled" || {
  echo "missing llm_slo_agent_signal_enabled metric"
  exit 1
}
echo "$METRICS_RAW" | grep -q "llm_slo_agent_capability_mode" || {
  echo "missing llm_slo_agent_capability_mode metric"
  exit 1
}

collector_ingested="0"
agent_probe_total="0"
agent_probe_kind="0"
collector_metrics=""
agent_metrics=""

deadline=$((SECONDS + 90))
while ((SECONDS < deadline)); do
  collector_metrics="$(kubectl get --raw "$COLLECTOR_METRICS_PATH" 2>/dev/null || true)"
  agent_metrics="$(kubectl get --raw "$METRICS_PATH" 2>/dev/null || true)"

  collector_ingested="$(printf '%s\n' "$collector_metrics" | collector_log_records_sum)"
  agent_probe_total="$(printf '%s\n' "$agent_metrics" | agent_probe_events_sum)"
  agent_probe_kind="$(printf '%s\n' "$agent_metrics" | agent_probe_kind_value)"

  if awk -v c="$collector_ingested" -v a="$agent_probe_total" -v k="$agent_probe_kind" 'BEGIN { exit !(c > 0 && a > 0 && k == 1) }'; then
    break
  fi
  sleep 5
done

if ! awk -v c="$collector_ingested" -v a="$agent_probe_total" -v k="$agent_probe_kind" 'BEGIN { exit !(c > 0 && a > 0 && k == 1) }'; then
  echo "otlp metric gate failed"
  echo "collector_otlp_log_records=${collector_ingested}"
  echo "agent_probe_events_total=${agent_probe_total}"
  echo "agent_probe_kind=${agent_probe_kind}"
  echo "--- collector log receiver metric lines ---"
  printf '%s\n' "$collector_metrics" | grep -E '^otelcol_receiver_(accepted|received)_(log_records|logs)' || true
  echo "--- agent probe metric lines ---"
  printf '%s\n' "$agent_metrics" | grep -E '^llm_ebpf_probe_events_total|^llm_slo_agent_event_kind' || true
  echo "--- collector logs (last 40 lines) ---"
  kubectl -n observability logs deployment/otel-collector --tail=40 || true
  echo "--- agent logs (first pod, last 20 lines) ---"
  kubectl -n llm-slo-system logs "$AGENT_POD" --tail=20 || true
  exit 1
fi

echo "kind observability smoke passed"
