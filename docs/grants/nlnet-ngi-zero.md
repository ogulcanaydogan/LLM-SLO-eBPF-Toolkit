# NLnet NGI Zero Commons Fund Application

| Field | Value |
|-------|-------|
| **Fund** | NGI Zero Commons Fund |
| **URL** | https://nlnet.nl/propose/ |
| **Deadline** | 2026-04-01 |
| **Requested Amount** | EUR 45,000 |
| **Project** | LLM-SLO-eBPF-Toolkit |
| **License** | MIT |
| **Repository** | https://github.com/ogulcanaydogan/LLM-SLO-eBPF-Toolkit |
| **Applicant** | Ogulcan Aydogan |
| **Language/Stack** | Go 1.23, eBPF/C, Kubernetes |

---

## 1. Abstract

LLM-SLO-eBPF-Toolkit is a Kubernetes-native observability tool that captures 9 kernel-level signals through eBPF probes and correlates them with OpenTelemetry traces to pinpoint why LLM services miss their SLO targets. When a retrieval-augmented generation service violates its time-to-first-token objective, the root cause often lives below the application layer: DNS resolution stalls, TCP retransmits, CPU scheduling contention, or memory reclaim pressure. Application tracing can't see these. The toolkit fuses kernel telemetry with request-level context through a three-stage pipeline: signal collection (libbpf CO-RE with BCC fallback for older kernels), a tiered confidence correlation engine that joins signals to OTel spans, and Bayesian multi-fault attribution across 8 fault domains. It runs as a DaemonSet with a safety governor capping overhead at 3% CPU. The project already ships 11 eBPF C programs, 12,771 lines of Go, 27 test files, 11 CI workflows, and 37 documentation pages across 7 releases. Benchmark results show 100% attribution accuracy with 2.50s detection delay and 2.20% CPU overhead. This grant would fund hardening the attribution engine, adding kernel compatibility across distributions, and building a public validation dataset so others can reproduce and extend the work.

---

## 2. Description of Work

### Background

Production LLM systems fail in ways application instrumentation alone can't explain. A single latency spike can originate from DNS delays, noisy-neighbor CPU contention, network packet loss, or memory pressure. These causes live in the kernel, invisible to standard tracing. Operators resort to guesswork, SSH-ing into nodes and running ad-hoc commands during incidents.

Existing eBPF-based tools solve adjacent problems. Cilium/Hubble handles network policy enforcement and flow visibility. Pixie captures protocol-level traffic for debugging. Parca does continuous profiling. None of them correlate kernel signals with LLM-specific SLI semantics or produce causal attribution over multiple fault domains simultaneously.

The gap is specific: no open-source tool connects kernel-grounded evidence (what actually happened at the OS level) to LLM reliability targets (did we miss our P99 TTFT SLO, and which infrastructure layer caused it?).

### Current State

The toolkit is functional and publicly available. Here's what exists today:

- **9 kernel probes**: DNS latency (kprobe/udp_sendmsg), TCP retransmits (tracepoint/tcp_retransmit_skb), runqueue delay (tracepoint/sched_switch), connection latency (kprobe/tcp_v4_connect), TLS handshake time (kprobe/ssl_do_handshake), CPU steal (/proc/stat polling), memory reclaim latency (tp/vmscan), disk I/O latency (tp/block), syscall latency (kprobe/ksys_read|write)
- **Correlation engine**: 4-tier join strategy using trace IDs, process identity, connection tuples, and service locality, with confidence scores at each tier
- **Bayesian attribution**: Posterior probability computation over 8 fault domains (DNS, network, compute, memory, disk, TLS, provider, retrieval) with confusion matrix tracking
- **Safety governor**: Real-time overhead monitoring that disables probes if CPU usage exceeds 3%
- **CI pipeline**: 11 workflows covering unit tests, privileged eBPF smoke tests, nightly integration, weekly benchmarks, kernel compatibility matrix, and release automation
- **Quality gates**: Precision >= 0.90, recall >= 0.85, overhead <= 3%

The codebase is well-tested (27 test files) and well-documented (37 pages), but several areas need work before the toolkit is ready for adoption beyond the original development environment.

### Trade-offs and Limitations

The design has real constraints worth acknowledging:

- **Privileged containers required.** eBPF probe attachment needs `CAP_SYS_ADMIN` or `CAP_BPF` + `CAP_PERFMON`. This is a hard security trade-off: kernel visibility requires kernel access. The DaemonSet runs with the minimum capability set, but it's still more privilege than most monitoring agents need.
- **Kernel 5.8+ for CO-RE.** BTF (BPF Type Format) support shipped in kernel 5.8. Older kernels fall back to BCC-compiled probes, which require kernel headers at build time and are slower to load. Some enterprise distributions (RHEL 8, older Ubuntu LTS) ship kernels below this threshold.
- **Single-node attribution boundary.** The current Bayesian engine operates per-node. Cross-node correlation (e.g., distinguishing upstream DNS failure from local network congestion) requires an aggregation layer that doesn't exist yet.

### Proposed Work

This grant would fund four milestones that move the project from "works in a controlled environment" to "others can deploy and validate it independently."

---

## 3. Budget

| Milestone | Description | Amount (EUR) |
|-----------|-------------|--------------|
| M1 | Attribution engine hardening and multi-node correlation | 12,000 |
| M2 | Kernel compatibility expansion and BCC fallback testing | 10,000 |
| M3 | Public validation dataset and reproducibility framework | 13,000 |
| M4 | Documentation, packaging, and community onboarding | 10,000 |
| **Total** | | **45,000** |

---

## 4. Milestones and Timeline

### M1: Attribution Engine Hardening (Months 1-3, EUR 12,000)

**Goal:** Make the Bayesian attribution engine work across node boundaries and handle concurrent multi-fault scenarios reliably.

Deliverables:
- Cross-node correlation aggregator that combines per-node posteriors into cluster-wide attribution
- Multi-fault disambiguation for overlapping failure modes (e.g., DNS delay + CPU contention hitting the same request)
- Adaptive prior tuning based on historical incident patterns per cluster
- Confusion matrix validation against synthetic fault injection (Chaos Mesh integration)
- At least 15 new test cases covering multi-node and multi-fault scenarios

**Exit criteria:** Attribution accuracy >= 95% on 3+ simultaneous fault injections across 2+ nodes, validated by CI.

### M2: Kernel Compatibility Expansion (Months 2-4, EUR 10,000)

**Goal:** Ensure the toolkit runs on the kernel versions that production Kubernetes clusters actually use, not just the latest upstream.

Deliverables:
- Automated kernel compatibility matrix expanded from current coverage to include: Ubuntu 20.04/22.04/24.04, RHEL 8/9, Amazon Linux 2/2023, Flatcar, Bottlerocket, Talos Linux
- BCC fallback path validated on kernels 4.18-5.7 (pre-BTF era)
- Graceful degradation when specific probes aren't supported (e.g., no BTF, no kprobe for a renamed symbol)
- Per-distribution CI test jobs using actual distribution kernels in QEMU
- Compatibility documentation showing which probes work on which kernel versions

**Exit criteria:** All 9 probes pass on at least 8 distribution kernels. BCC fallback works on kernel 4.18+. Degradation is documented and tested for each unsupported probe.

### M3: Public Validation Dataset (Months 3-5, EUR 13,000)

**Goal:** Build an open dataset of kernel signals paired with known fault injections, so anyone can validate attribution accuracy independently.

Deliverables:
- Fault injection framework using Chaos Mesh, tc netem, and stress-ng to produce reproducible failure scenarios
- 50+ labeled scenarios spanning all 8 fault domains, each with raw kernel signals, OTel traces, and ground truth labels
- Dataset published under CC-BY-4.0 on a public repository
- Benchmark harness that anyone can run to reproduce the published accuracy numbers (100% attribution, 2.50s detection delay)
- Comparison methodology for evaluating alternative attribution approaches against the same dataset

**Exit criteria:** Dataset publicly available. At least 3 independent reviewers can reproduce benchmark results within 5% tolerance using only published artifacts.

### M4: Documentation, Packaging, and Community Onboarding (Months 4-6, EUR 10,000)

**Goal:** Lower the barrier to adoption from "you need to understand eBPF internals" to "helm install and configure your SLOs."

Deliverables:
- Helm chart with sensible defaults for common Kubernetes distributions (EKS, GKE, AKS, bare-metal kubeadm)
- Operator that manages probe lifecycle, kernel compatibility detection, and automatic fallback selection
- Getting-started guide tested by someone who hasn't seen the codebase before
- Architecture decision records (ADRs) for key design choices
- Contributor guide with local development setup (including eBPF development without root on the host)
- Video walkthrough of deployment and incident attribution workflow

**Exit criteria:** A new user can go from `helm install` to seeing their first attribution result in under 15 minutes, verified by user testing.

---

## 5. NGI Relevance

### How does this project contribute to the Next Generation Internet?

LLM services are becoming infrastructure. Search engines, customer support, document processing, and code assistance increasingly depend on LLM inference. When these services degrade, the impact cascades to millions of users. But the observability tools available today were built for traditional request-response applications, not for the multi-layer failure modes that LLM systems exhibit.

This toolkit addresses a specific gap in the open internet's infrastructure stack: the ability to attribute LLM reliability failures to their actual infrastructure causes, using kernel-level evidence rather than application-level guesswork.

Three aspects align with NGI Zero Commons Fund priorities:

**Open infrastructure tooling.** The MIT license ensures anyone can use, modify, and redistribute the toolkit. The eBPF programs, attribution algorithms, and validation datasets are all open. There's no "enterprise edition" or proprietary component behind a paywall.

**Democratizing production monitoring.** Today, only large organizations with dedicated kernel engineering teams can build this kind of observability. This toolkit packages that capability into a standard Kubernetes DaemonSet that an SRE team can deploy without writing eBPF code.

**Reproducible science.** The public validation dataset (M3) lets researchers and practitioners verify attribution claims independently. Most observability tools publish benchmarks that can't be reproduced outside the vendor's environment. We're building the dataset and harness so anyone can check our work and build on it.

### How does this project relate to the open internet?

LLM reliability directly affects open internet services. Non-profit organizations, academic institutions, and small companies running open-source LLM deployments (vLLM, TGI, Ollama) face the same infrastructure failure modes as large cloud providers but lack the engineering resources to diagnose them. Kernel-level attribution shouldn't require a dedicated observability team. This project makes that capability freely available to anyone running Kubernetes.

---

## 6. Comparable Projects

| Project | What it does | How this toolkit differs |
|---------|-------------|------------------------|
| **Cilium/Hubble** | eBPF-based network policy and flow visibility for Kubernetes | Focuses on network layer only. No SLO correlation, no attribution across non-network fault domains. |
| **Pixie (CNCF)** | Auto-instrumented protocol tracing via eBPF | Captures application protocol data. Doesn't correlate with kernel scheduling, memory, or disk signals. No Bayesian attribution. |
| **Parca** | Continuous profiling using eBPF | Profiles CPU and memory usage. Doesn't link profiles to specific SLO violations or produce causal attribution. |
| **Inspektor Gadget** | eBPF-based debugging tools for Kubernetes | Collection of individual gadgets for ad-hoc debugging. Not designed for continuous SLO monitoring or automated attribution. |
| **bpftrace** | High-level tracing language for eBPF | Scripting tool for manual investigation. No correlation engine, no attribution, no Kubernetes integration. |
| **OpenTelemetry** | Observability framework (traces, metrics, logs) | The standard we build on. OTel collects application telemetry but doesn't capture kernel signals or perform fault attribution. |

The key distinction: these tools each cover one layer of the observability stack. This toolkit is the bridge between kernel telemetry and LLM-specific reliability targets. It consumes OTel data and produces attribution results; it doesn't replace any of these projects.

---

## 7. Supporting Materials Checklist

Before submitting, confirm these are ready:

- [ ] Repository is public: https://github.com/ogulcanaydogan/LLM-SLO-eBPF-Toolkit
- [ ] MIT license file present in repository root
- [ ] README describes the project, its purpose, and how to use it
- [ ] CI passing (11 workflows green)
- [ ] Architecture documentation: `docs/ARCHITECTURE.md`
- [ ] Benchmark results available in CI artifacts
- [ ] CHANGELOG.md with release history (v0.2.0-rc.1 through v0.3.0)
- [ ] SECURITY.md with vulnerability reporting process
- [ ] CONTRIBUTING.md (or equivalent contributor guidance)
- [ ] At least one tagged release on GitHub

### Optional but recommended:
- [ ] OpenSSF Best Practices badge (see `docs/grants/openssf-badge-guide.md`)
- [ ] Demo video or GIF showing the toolkit in action
- [ ] Blog post or write-up explaining the approach

---

## 8. Submission Steps

### Step 1: Prepare answers for the NLnet form

The form at https://nlnet.nl/propose/ asks for these fields. Draft your answers using the content above.

**General project information:**
- Project name: `LLM-SLO-eBPF-Toolkit`
- Website / wiki: `https://github.com/ogulcanaydogan/LLM-SLO-eBPF-Toolkit`

**Abstract:** Use Section 1 above (200 words).

**Have you been involved with projects or organizations relevant to this project before?**
> Yes. I've been building this toolkit as an open-source project since early 2026. The repository has 7 releases, 11 CI workflows, and 37 documentation pages. I've worked on LLM training and deployment infrastructure, including distributed training on A100 and V100 clusters, and have hands-on experience with the kernel-level failure modes this toolkit detects.

**Requested amount:** EUR 45,000

**Explain what the requested budget will be used for:**
> Four milestones over 6 months: (1) attribution engine hardening with cross-node correlation (EUR 12,000), (2) kernel compatibility expansion across 8+ distribution kernels (EUR 10,000), (3) public validation dataset with 50+ labeled fault scenarios under CC-BY-4.0 (EUR 13,000), (4) documentation, Helm packaging, and community onboarding (EUR 10,000). Budget covers development time exclusively; no hardware or travel costs.

**Compare your own project with existing or historical efforts:**
> Use Section 6 (Comparable Projects) above. Key point: existing eBPF tools (Cilium, Pixie, Parca) each address one observability layer. This toolkit bridges kernel telemetry with LLM-specific SLI decomposition and Bayesian causal attribution. No open-source tool currently combines all three stages.

**What are significant technical challenges you expect to solve during the project?**
> Three main challenges: (1) Cross-node Bayesian aggregation, where per-node posteriors must be combined without a centralized state store, likely using gossip-based probability propagation. (2) Kernel compatibility across 10+ distribution kernels, where symbol names, tracepoint availability, and BTF support vary significantly. The fallback from CO-RE to BCC introduces a separate code path that doubles the test matrix. (3) Building a reproducible validation dataset, since fault injection at the kernel level is inherently noisy, and getting consistent ground truth labels requires careful experiment design.

**Describe the ecosystem of the project:**
> The toolkit sits in the Kubernetes observability space, between kernel-level eBPF tools and application-level tracing (OpenTelemetry). Users are SRE teams running LLM inference workloads on Kubernetes. It exports to Prometheus and Grafana, integrates with OTel Collector, and uses standard Kubernetes deployment primitives (DaemonSet, RBAC, Helm).

### Step 2: Submit

1. Go to https://nlnet.nl/propose/
2. Select **NGI Zero Commons Fund**
3. Fill in each field using the prepared answers
4. Submit before **2026-04-01**

### Step 3: After submission

- NLnet reviews take 4-8 weeks
- If selected, you'll discuss milestones and payment schedule with an NLnet advisor
- Payments are milestone-based (you get paid when you deliver, not upfront)
- All funded work must remain open source under the declared license
