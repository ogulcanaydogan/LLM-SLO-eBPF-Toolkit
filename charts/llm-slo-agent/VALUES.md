# Helm values reference

<!-- markdownlint-disable MD013 -->

This chart deploys the `llm-slo-agent` DaemonSet and its supporting
ConfigMap, Service, RBAC, namespace, and service account resources.
Use this reference with `values.yaml` when overriding chart defaults.

## Value reference

| Key | Default | Description | Notes |
| --- | ---: | --- | --- |
| `image.repository` | `ghcr.io/ogulcanaydogan/llm-slo-ebpf-toolkit-agent` | Agent image repository. | Change when using a private registry or a locally built image. |
| `image.tag` | `latest` | Agent image tag. | Pin this to a released version for repeatable deployments. |
| `image.pullPolicy` | `IfNotPresent` | Kubernetes image pull policy for the agent container. | Use `Always` while testing mutable tags. |
| `nameOverride` | `""` | Overrides the chart name used by helper templates. | Leave empty for the chart default. |
| `fullnameOverride` | `""` | Overrides the full resource name. | Useful when multiple releases share a namespace. |
| `namespace` | `llm-slo-system` | Namespace rendered into chart resources. | Keep this aligned with `--namespace` during install. |
| `serviceAccount.create` | `true` | Creates a service account for the DaemonSet. | Set to `false` to reuse an existing account. |
| `serviceAccount.name` | `""` | Existing service account name or explicit generated name. | Empty uses the chart fullname when creation is enabled. |
| `rbac.create` | `true` | Creates ClusterRole and ClusterRoleBinding resources. | Disable only when equivalent RBAC already exists. |
| `agent.scenario` | `mixed` | Fault scenario name passed to the agent. | Used by synthetic and demo paths. |
| `agent.outputMode` | `otlp` | Agent output mode. | Keep `otlp` for OpenTelemetry export. |
| `agent.eventKind` | `probe` | Event kind written into agent output. | Usually does not need changing. |
| `agent.capabilityMode` | `auto` | Probe capability selection mode. | `auto` lets the agent choose the supported signal profile. |
| `agent.sampleCount` | `"0"` | Number of samples to emit. | `0` means continuous collection. |
| `agent.sampleIntervalMS` | `"1000"` | Sampling interval in milliseconds. | Lower values increase event volume. |
| `agent.disableSignals` | `""` | Comma-separated signal names to disable. | Use for reduced-risk or troubleshooting installs. |
| `agent.disableOverheadGuard` | `"false"` | Disables the overhead guard when set to `"true"`. | Keep enabled for normal deployments. |
| `agent.enableHelloTracer` | `"true"` | Enables the hello tracer helper. | Useful for demo and smoke paths. |
| `agent.helloTargetComm` | `rag-service,llama-server` | Comma-separated process names matched by the hello tracer. | Tune to local workload process names. |
| `agent.enableRealProbeMetrics` | `"true"` | Exposes real probe metrics from the agent. | Disable only for synthetic-only testing. |
| `agent.cluster` | `local` | Cluster name attached to emitted metadata. | Set to a stable cluster identifier in shared observability backends. |
| `agent.defaultNamespace` | `default` | Workload namespace metadata fallback. | Override when observing a primary application namespace. |
| `agent.workload` | `llm-slo-agent` | Workload metadata fallback. | Override for demo or synthetic workload attribution. |
| `agent.service` | `agent` | Service metadata fallback. | Override to match service-level observability naming. |
| `otlp.endpoint` | `http://otel-collector.observability.svc.cluster.local:4318/v1/logs` | OTLP/HTTP logs endpoint. | Point this at your OpenTelemetry Collector. |
| `otlp.timeoutMS` | `"5000"` | OTLP export timeout in milliseconds. | Increase for slow or remote collectors. |
| `metrics.port` | `2112` | Metrics container and Service port. | Probes and Service target this named port. |
| `metrics.bindAddress` | `":2112"` | Address passed to the agent metrics listener. | Use a host/port only when a custom bind is required. |
| `toolkit.signalSet` | See `values.yaml` | Signals written into the mounted toolkit config. | Remove entries to narrow the signal set. |
| `toolkit.sampling.eventsPerSecondLimit` | `10000` | Steady-state event rate limit. | Lower this to reduce agent and backend load. |
| `toolkit.sampling.burstLimit` | `20000` | Burst event rate limit. | Keep this at or above the steady-state limit. |
| `toolkit.correlation.windowMS` | `2000` | Signal-to-span correlation window in milliseconds. | Larger windows can increase matches and noise. |
| `toolkit.safety.maxOverheadPct` | `5` | Maximum allowed collector CPU overhead percent. | The production target is commonly lower, for example `3`. |
| `webhook.enabled` | `false` | Enables incident webhook delivery. | Requires `webhook.url`. |
| `webhook.url` | `""` | Webhook endpoint URL. | Supports generic, PagerDuty, and Opsgenie formats. |
| `webhook.secret` | `""` | HMAC signing secret for webhook payloads. | Store real secrets outside committed values files. |
| `webhook.format` | `generic` | Webhook payload format. | Supported values are `generic`, `pagerduty`, and `opsgenie`. |
| `webhook.timeoutMS` | `5000` | Webhook request timeout in milliseconds. | Increase for slower receivers. |
| `cdgate.enabled` | `false` | Enables CD gate configuration in toolkit config. | Used by SLO validation workflows. |
| `cdgate.prometheusURL` | `http://prometheus:9090` | Prometheus base URL for gate checks. | Point this to the metrics backend used by deployment gates. |
| `cdgate.ttftP95MS` | `800` | TTFT p95 threshold in milliseconds. | Tune to the service SLO. |
| `cdgate.errorRate` | `0.05` | Error-rate threshold. | Expressed as a fraction, so `0.05` is 5%. |
| `cdgate.burnRate` | `2.0` | Error-budget burn-rate threshold. | Higher values tolerate faster budget burn. |
| `cdgate.failOpen` | `true` | Allows the gate to pass when Prometheus is unavailable. | Set to `false` for strict production gates. |
| `resources.requests.cpu` | `100m` | Requested CPU for the agent container. | Increase for high event rates or full signal sets. |
| `resources.requests.memory` | `128Mi` | Requested memory for the agent container. | Increase if buffers or exporters are constrained. |
| `resources.limits.cpu` | `500m` | CPU limit for the agent container. | Keep enough headroom for probe and exporter bursts. |
| `resources.limits.memory` | `512Mi` | Memory limit for the agent container. | Increase for larger buffers or high-cardinality metrics. |
| `securityContext.privileged` | `true` | Runs the agent container in privileged mode. | Required for full eBPF probe coverage on many clusters. |
| `securityContext.capabilities.add` | `BPF`, `SYS_ADMIN`, `SYS_RESOURCE`, `NET_ADMIN` | Linux capabilities added to the agent container. | Reduce only after validating probe support on your runtime. |
| `tolerations` | `[{ operator: Exists }]` | Pod tolerations for DaemonSet scheduling. | Default schedules on tainted nodes too. |
| `nodeSelector` | `{}` | Node selector for the DaemonSet. | Use to target eBPF-capable nodes. |
| `affinity` | `{}` | Pod affinity and anti-affinity rules. | Use for advanced scheduling constraints. |

## Common configurations

### Default install

Use the defaults when testing the full privileged signal set with the bundled
OTLP collector endpoint:

```bash
helm install llm-slo-agent charts/llm-slo-agent \
  --namespace llm-slo-system \
  --create-namespace
```

### Reduced-capability install

Use a smaller signal set and remove privileged mode when piloting clusters that
do not allow privileged workloads. Probe support depends on the kernel and
runtime policy, so validate this mode before relying on it for coverage.

```yaml
securityContext:
  privileged: false
  capabilities:
    add:
      - BPF
      - SYS_ADMIN
      - SYS_RESOURCE

toolkit:
  signalSet:
    - dns_latency_ms
    - tcp_retransmits_total
  safety:
    maxOverheadPct: 3

agent:
  capabilityMode: "auto"
  disableSignals: "runqueue_delay_ms,connect_latency_ms,tls_handshake_ms,cpu_steal_pct,mem_reclaim_latency_ms,disk_io_latency_ms,syscall_latency_ms"
```

Install with:

```bash
helm install llm-slo-agent charts/llm-slo-agent \
  --namespace llm-slo-system \
  --create-namespace \
  -f reduced-capability-values.yaml
```

### Webhook enabled

Enable webhook delivery when incident attribution should be forwarded to an
external responder. Use a Kubernetes secret workflow for real signing secrets
rather than committing the secret in a values file.

```yaml
webhook:
  enabled: true
  url: "https://events.pagerduty.com/v2/enqueue"
  secret: "replace-with-secret"
  format: "pagerduty"
  timeoutMS: 5000
```

Install with:

```bash
helm upgrade --install llm-slo-agent charts/llm-slo-agent \
  --namespace llm-slo-system \
  --create-namespace \
  -f webhook-values.yaml
```
