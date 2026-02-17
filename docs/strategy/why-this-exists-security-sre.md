# Why LLM SLO eBPF Toolkit Exists (Security and SRE Narrative)

LLM incidents routinely cross boundaries that teams monitor with separate tools: ingress, service runtime, retrieval backends, policy layers, and external model providers. When SLOs degrade, app-level telemetry alone often answers only part of the question. Teams can detect symptoms but still misidentify cause.

LLM SLO eBPF Toolkit exists to improve incident attribution quality by adding kernel-grounded evidence to the diagnosis path.

The operating model is practical: collect low-level runtime/network signals without requiring immediate code instrumentation changes, correlate those signals with OpenTelemetry spans and Kubernetes identity, then produce attribution outputs tied to SLO burn behavior.

For SRE teams, this reduces triage uncertainty. Instead of debating whether a latency spike came from app code, network behavior, retrieval backend, or provider throttling, responders get an explicit fault-domain hypothesis with confidence and supporting events.

For platform teams, this improves standardization across heterogeneous services where instrumentation quality varies. A kernel-grounded baseline reduces dependency on per-team tracing maturity before meaningful SLO diagnostics are possible.

For security-adjacent operations, it adds visibility into runtime egress and anomalous behavior that may materially affect reliability posture.

The project intentionally treats uncertainty as first-class. Attribution quality is reported with confusion matrix, precision/recall, and abstain rates when confidence is low. That avoids over-claiming certainty in multi-fault conditions.

This is not a claim that kernel data is universally sufficient. The value is in a combined model where kernel signals and app traces improve each other.

## What this does not claim
- It does not claim perfect attribution in concurrent multi-fault incidents.
- It does not claim zero overhead across all environments.
- It does not claim replacement of full APM/observability platforms.

The core claim is narrower and testable: improve detection speed and attribution fidelity for LLM SLO incidents with transparent overhead tradeoffs.
