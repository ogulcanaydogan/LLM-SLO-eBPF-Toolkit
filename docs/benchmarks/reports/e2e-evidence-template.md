# E2E Evidence Report (<date>)

## Environment
- Timestamp (UTC):
- Cluster profile:
- Agent mode:
- Backend mode: `stub|llama_cpp`
- Runner mode: `full-self-hosted-ebpf|fallback-synthetic-no-self-hosted-ebpf|unknown`
- Release grade: `true|false`

## DaemonSet and Pod Health
- `kubectl -n llm-slo-system get ds llm-slo-agent`
- `kubectl -n llm-slo-system get pods -l app=llm-slo-agent`

## Prometheus Queries
1. Hello tracer event rate
2. DNS p95
3. TTFT p95
4. Correlation confidence trend
5. Alert state (`LLMHighTTFTWithDNSKernelSignal`)

## Alert Timeline
- Fault start:
- Alert firing:
- Recovery start:
- Alert resolved:

## Evidence Artifacts
- Dashboard screenshot references:
- Raw query outputs:
- Command transcript:
