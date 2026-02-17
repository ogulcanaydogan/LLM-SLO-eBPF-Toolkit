# LLM SLO eBPF Toolkit Killer Demo Stories

## Demo 1: 5-Minute Install to First LLM SLO Baseline
### Setup
- Deploy collector DaemonSet in a sample Kubernetes cluster.
- Run synthetic LLM traffic in two namespaces.

### What to show
- Service map and baseline SLO dashboard appear without app code changes.
- TTFT and error-rate time series are visible per namespace.

### Measurable win condition
- First usable dashboard in <= 5 minutes from deploy.
- >= 95% of requests represented in baseline event stream.

## Demo 2: TTFT Spike Root-Cause in Minutes
### Setup
- Inject controlled DNS/egress latency fault on one workload path.

### What to show
- SLO burn alert fires with detection timestamp.
- Attribution points to network fault domain and affected workloads.
- Confidence score and evidence chain are visible.

### Measurable win condition
- Detection delay improves by >= 30% versus app-only baseline.
- Correct fault-domain attribution in >= 85% of single-fault runs.

## Demo 3: Noisy Neighbor Throughput Collapse Attribution
### Setup
- Apply CPU throttling to one tenant workload under concurrent traffic.

### What to show
- Token throughput degradation in neighboring workload is detected.
- Attribution links culprit workload/resource pressure to impacted service.

### Measurable win condition
- Culprit workload identified in <= 3 minutes.
- False-positive culprit attribution <= 10% across repeated runs.

## Demo 4: Provider 429 Storm vs Cluster Bottleneck Separation
### Setup
- Inject upstream provider 429/5xx bursts while cluster remains healthy.

### What to show
- Incident classification distinguishes upstream provider failure from in-cluster bottlenecks.
- Burn-rate impact is segmented by fault domain.

### Measurable win condition
- Misclassification rate between provider and cluster domains <= 10%.
- Runbook recommendation points to upstream mitigation path.

## Demo 5: Canary SLO Gate with Attribution Evidence
### Setup
- Execute stable vs canary rollout under identical synthetic profile.
- Introduce controlled canary regression in latency/error profile.

### What to show
- Gate blocks promotion based on SLO threshold breach.
- Attribution report identifies dominant fault contributors.

### Measurable win condition
- 100% regression cases blocked when thresholds are exceeded.
- Promotion allowed for non-regressed canary runs in >= 95% of trials.
