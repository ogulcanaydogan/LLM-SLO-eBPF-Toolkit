# E2E Proof Checklist

## Chain Completeness
- [ ] `kubectl -n llm-slo-system get ds llm-slo-agent` shows desired/current pods healthy
- [ ] `/metrics` includes `llm_ebpf_hello_syscalls_total`
- [ ] `/metrics` includes `llm_ebpf_dns_latency_ms_bucket`
- [ ] Prometheus query returns non-empty for hello tracer rate
- [ ] Prometheus query returns non-empty for DNS p95
- [ ] Grafana `Evidence E2E` dashboard loads without query errors
- [ ] `LLMHighTTFTWithDNSKernelSignal` can be observed firing during DNS fault
- [ ] Alert resolves after returning to baseline

## Command Evidence
- [ ] daemonset and pod listings captured
- [ ] Prometheus query JSON responses captured
- [ ] alert firing/resolution timestamps captured
- [ ] report markdown generated with paths to artifacts

## Optional llama.cpp Proof
- [ ] rag-service started with `llm.backend=llama_cpp`
- [ ] at least one successful `/chat` response in llama.cpp mode
- [ ] TTFT and tokens/sec metrics continue to populate
