# LLM SLO eBPF Toolkit Differentiation Strategy

Claim date: 2026-02-17  
Last revalidated: 2026-02-17

## Goal
Define a technically defensible differentiation stance for a Kubernetes-first toolkit that improves LLM reliability operations through kernel-grounded telemetry and attribution.

## Scope and Assumptions
- Primary buyer: SRE, platform engineering, and security teams operating LLM services.
- Integration posture: OpenTelemetry-compatible downstream exports.
- Product boundary: incident attribution and SLO diagnostics, not full APM replacement.

## Top 10 Competitor and Adjacent Tools

| Tool | What it does well | What it misses for this target |
|---|---|---|
| OpenTelemetry eBPF Instrumentation (OBI) | Zero-code signal collection and open standards alignment | Generic telemetry semantics; limited opinionated LLM SLO decomposition |
| Pixie | Fast Kubernetes troubleshooting with rich eBPF-derived data | Not centered on LLM-specific SLI attribution model and fault labeling workflow |
| Cilium + Hubble | Strong network identity and flow-level visibility | Network-centric lens does not fully explain user-facing LLM SLO burn paths |
| Tetragon | Runtime security event visibility and policy telemetry | Security-event focus, not LLM latency/error budget attribution pipeline |
| Parca | Low-overhead continuous profiling | Profiling depth without integrated LLM request/token SLO semantics |
| Coroot | Integrated eBPF observability platform with SLO capabilities | Broad platform scope; LLM-specific attribution model is not primary objective |
| Datadog Universal Service Monitoring | Production-grade service topology and traffic visibility | Closed-stack constraints and less transparent reproducible attribution methodology |
| Elastic Universal Profiling | Mature production profiling with eBPF coverage | Profiling-first posture, weaker direct incident fault-domain attribution for LLM SLOs |
| Inspektor Gadget | Practical eBPF tooling for Kubernetes runtime diagnostics | Toolkit-level diagnostics, not opinionated LLM SLO attribution and burn-rate model |
| Odigos (adjacent) | Quick OTel auto-instrumentation and pipeline integration | App/tracing emphasis; weaker kernel-grounded causality in isolation |

## Source Mapping
All competitor claims above map to primary references in `/Users/ogulcanaydogan/Desktop/Projects/YaPAY/eBPF + LLM Inference SLO Toolkit/docs/research/landscape-sources.md`.

## Honest Gap Assessment (Execution Risks)
- Kernel compatibility risk: portability varies by kernel version and distro defaults.
- Attribution confidence risk: multi-fault incidents can degrade precision.
- Overhead risk: event volume can become expensive without robust filtering/aggregation.
- Semantic extraction risk: TTFT/token metrics can vary across provider protocols.

## Unique Wedge (3 Pillars)
1. Kernel-grounded telemetry with no-code baseline coverage.
   - Captures network/runtime indicators even when app instrumentation is partial.
2. LLM-native SLI semantics.
   - Models TTFT, token throughput collapse, provider error classes, and retrieval contribution.
3. Causal attribution graph.
   - Correlates eBPF events with OTel spans and Kubernetes workload identity for incident diagnosis.

## Positioning by Buyer
- SRE: faster and more confident fault-domain localization during SLO burn.
- Platform: standardized telemetry posture across heterogeneous LLM services.
- Security: better visibility into runtime egress anomalies affecting reliability posture.

## Publishable Benchmark Angle
### Theme
LLM SLO Attribution Accuracy Under Controlled Fault Injection.

### Research Question
Can kernel-grounded telemetry reduce detection delay and improve fault attribution accuracy versus app-instrumentation-only baselines while staying within strict overhead budgets?

### Experimental Design
- Baseline: app instrumentation only.
- Treatment A: eBPF toolkit only.
- Treatment B: combined app instrumentation + eBPF toolkit.

### Publishability Requirements
- Publish confusion matrix and per-fault precision/recall/F1.
- Publish abstain/uncertainty rates when attribution confidence is below threshold.
- Publish raw event/metric/provenance artifacts and reproducible fault manifests.

## Non-Claims
- No claim that kernel telemetry alone resolves all attribution ambiguity.
- No claim that the toolkit replaces full observability/APM platforms.
- No claim of uniform behavior across all kernels without compatibility testing.
