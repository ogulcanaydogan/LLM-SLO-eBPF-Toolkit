#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/artifacts/benchmarks-matrix}"
COUNT="${COUNT:-24}"
REAL_INJECTORS="${REAL_INJECTORS:-false}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-llm-slo-lab}"
RAG_NAMESPACE="${RAG_NAMESPACE:-observability}"
RAG_SERVICE="${RAG_SERVICE:-rag-service}"
TRAFFIC_REQUESTS="${TRAFFIC_REQUESTS:-40}"
DNS_DELAY_MS="${DNS_DELAY_MS:-200}"
RETRANSMIT_LOSS_PCT="${RETRANSMIT_LOSS_PCT:-5}"
CPU_STRESS_SECONDS="${CPU_STRESS_SECONDS:-60}"
CPU_STRESS_IMAGE="${CPU_STRESS_IMAGE:-busybox:1.36}"

SCENARIOS=(provider_throttle dns_latency cpu_throttle memory_pressure network_partition mixed)

mkdir -p "$OUT_DIR"

RAG_PF_PID=""
cleanup() {
  if [[ -n "$RAG_PF_PID" ]]; then
    kill "$RAG_PF_PID" >/dev/null 2>&1 || true
  fi
  clear_kind_tc || true
}
trap cleanup EXIT

log() {
  printf '[chaos-matrix] %s\n' "$*"
}

kind_nodes() {
  kind get nodes --name "$KIND_CLUSTER_NAME" 2>/dev/null || true
}

clear_kind_tc() {
  local node
  while IFS= read -r node; do
    [[ -z "$node" ]] && continue
    docker exec "$node" tc qdisc del dev eth0 root >/dev/null 2>&1 || true
  done < <(kind_nodes)
}

apply_kind_tc() {
  local spec="$1"
  local node
  local applied=0
  while IFS= read -r node; do
    [[ -z "$node" ]] && continue
    docker exec "$node" tc qdisc replace dev eth0 root netem $spec
    applied=1
  done < <(kind_nodes)
  [[ "$applied" -eq 1 ]]
}

start_rag_port_forward() {
  if [[ -n "$RAG_PF_PID" ]]; then
    return 0
  fi
  if ! kubectl -n "$RAG_NAMESPACE" get svc "$RAG_SERVICE" >/dev/null 2>&1; then
    return 1
  fi
  kubectl -n "$RAG_NAMESPACE" port-forward "svc/${RAG_SERVICE}" 18080:8080 >/tmp/llm-slo-rag-pf.log 2>&1 &
  RAG_PF_PID=$!
  sleep 3
  return 0
}

run_rag_traffic() {
  local count="$1"
  local i
  start_rag_port_forward || return 1
  for i in $(seq 1 "$count"); do
    curl -fsS --max-time 20 http://127.0.0.1:18080/chat \
      -H 'content-type: application/json' \
      -d '{"prompt":"chaos matrix traffic","profile":"rag_medium","seed":42,"max_tokens":24,"stream":false}' >/dev/null || true
  done
}

run_cpu_stress() {
  local seconds="$1"
  local pod="llm-slo-cpu-stress-$(date +%s)"
  kubectl -n "$RAG_NAMESPACE" run "$pod" \
    --image "$CPU_STRESS_IMAGE" \
    --restart=Never \
    --requests='cpu=1000m,memory=64Mi' \
    --limits='cpu=2000m,memory=128Mi' \
    --command -- sh -c "end=\$((SECONDS+${seconds})); while [ \$SECONDS -lt \$end ]; do :; done"
  sleep "$seconds"
  kubectl -n "$RAG_NAMESPACE" logs "$pod" --tail=20 >/dev/null 2>&1 || true
  kubectl -n "$RAG_NAMESPACE" delete pod "$pod" --ignore-not-found=true --wait=false >/dev/null 2>&1 || true
}

supports_real_injectors() {
  command -v kubectl >/dev/null 2>&1 &&
    command -v docker >/dev/null 2>&1 &&
    command -v kind >/dev/null 2>&1
}

write_injector_metadata() {
  local out="$1"
  local mode="$2"
  local status="$3"
  local detail="$4"
  cat > "$out" <<EOF
{
  "mode": "${mode}",
  "status": "${status}",
  "detail": "${detail}",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

for scenario in "${SCENARIOS[@]}"; do
  scenario_dir="$OUT_DIR/$scenario"
  mkdir -p "$scenario_dir"

  injector_mode="synthetic"
  injector_status="skipped"
  injector_detail="REAL_INJECTORS=false"

  if [[ "$REAL_INJECTORS" == "true" ]]; then
    if supports_real_injectors; then
      case "$scenario" in
      dns_latency)
        log "real injector: dns delay ${DNS_DELAY_MS}ms"
        if apply_kind_tc "delay ${DNS_DELAY_MS}ms"; then
          run_rag_traffic "$TRAFFIC_REQUESTS" || true
          injector_mode="real"
          injector_status="applied"
          injector_detail="kind netem delay ${DNS_DELAY_MS}ms"
          clear_kind_tc || true
        else
          injector_detail="kind netem delay failed, fell back to synthetic"
        fi
        ;;
      network_partition)
        log "real injector: retransmit/loss ${RETRANSMIT_LOSS_PCT}%"
        if apply_kind_tc "loss ${RETRANSMIT_LOSS_PCT}%"; then
          run_rag_traffic "$TRAFFIC_REQUESTS" || true
          injector_mode="real"
          injector_status="applied"
          injector_detail="kind netem loss ${RETRANSMIT_LOSS_PCT}%"
          clear_kind_tc || true
        else
          injector_detail="kind netem loss failed, fell back to synthetic"
        fi
        ;;
      cpu_throttle)
        log "real injector: cpu stress ${CPU_STRESS_SECONDS}s"
        if run_cpu_stress "$CPU_STRESS_SECONDS"; then
          run_rag_traffic "$TRAFFIC_REQUESTS" || true
          injector_mode="real"
          injector_status="applied"
          injector_detail="busy-loop stress pod for ${CPU_STRESS_SECONDS}s"
        else
          injector_detail="cpu stress pod failed, fell back to synthetic"
        fi
        ;;
      *)
        injector_detail="no real injector configured for this scenario"
        ;;
      esac
    else
      injector_detail="required tooling unavailable (kind/docker/kubectl), fell back to synthetic"
    fi
  fi

  write_injector_metadata "$scenario_dir/injector_metadata.json" "$injector_mode" "$injector_status" "$injector_detail"

  log "scenario: $scenario (injector_mode=${injector_mode})"
  go run "$ROOT_DIR/cmd/faultinject" \
    --scenario "$scenario" \
    --count "$COUNT" \
    --out "$scenario_dir/raw_samples.jsonl"

  go run "$ROOT_DIR/cmd/collector" \
    --input "$scenario_dir/raw_samples.jsonl" \
    --output jsonl \
    --output-path "$scenario_dir/slo_events.jsonl"

  go run "$ROOT_DIR/cmd/faultreplay" \
    --scenario "$scenario" \
    --count "$COUNT" \
    --out "$scenario_dir/fault_samples.jsonl"

  bench_scenario="$scenario"
  if [[ "$scenario" == "mixed" ]]; then
    bench_scenario="mixed_faults"
  fi

  go run "$ROOT_DIR/cmd/benchgen" \
    --out "$scenario_dir" \
    --scenario "$bench_scenario" \
    --input "$scenario_dir/fault_samples.jsonl"

done

log "matrix artifacts created under $OUT_DIR"
