# E2E Evidence Report (2026-02-18)

## Environment
- Timestamp (UTC): 20260218T222639Z
- Cluster: kind
- Stack: Prometheus + Grafana + Tempo + OTel Collector

## DaemonSet Status
```text
NAME            DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE   CONTAINERS   IMAGES                SELECTOR
llm-slo-agent   3         3         3       3            3           <none>          10m   agent        llm-slo-agent:local   app=llm-slo-agent
```

## Agent Pods
```text
NAME                  READY   STATUS    RESTARTS   AGE     IP           NODE                        NOMINATED NODE   READINESS GATES
llm-slo-agent-84rpd   1/1     Running   0          2m40s   172.20.0.2   llm-slo-lab-worker          <none>           <none>
llm-slo-agent-m727k   1/1     Running   0          2m41s   172.20.0.4   llm-slo-lab-worker2         <none>           <none>
llm-slo-agent-msrzq   1/1     Running   0          2m41s   172.20.0.3   llm-slo-lab-control-plane   <none>           <none>
```

## Query: Hello Tracer Rate
```json
{"status":"success","data":{"resultType":"vector","result":[{"metric":{"comm":"llama-server","instance":"llm-slo-agent-metrics.llm-slo-system.svc.cluster.local:2112","job":"llm-slo-agent","node":"llm-slo-lab-worker","pod":"llm-slo-agent-84rpd"},"value":[1771453602.193,"0.2546481153632688"]},{"metric":{"comm":"rag-service","instance":"llm-slo-agent-metrics.llm-slo-system.svc.cluster.local:2112","job":"llm-slo-agent","node":"llm-slo-lab-worker","pod":"llm-slo-agent-84rpd"},"value":[1771453602.193,"0.2546481153632688"]}]}}
```

## Query: DNS p95
```json
{"status":"success","data":{"resultType":"vector","result":[{"metric":{},"value":[1771453602.204,"350"]}]}}
```

## Query: TTFT p95
```json
{"status":"success","data":{"resultType":"vector","result":[{"metric":{},"value":[1771453602.215,"390"]}]}}
```

## Query: Correlation Signal
```json
{"status":"success","data":{"resultType":"vector","result":[{"metric":{},"value":[1771453602.227,"1"]}]}}
```

## Query: Alert State
```json
{"status":"success","data":{"resultType":"vector","result":[]}}
```

## Artifact Paths
- Raw outputs: artifacts/evidence/20260218T222639Z
- Runbook: docs/demos/e2e-evidence-runbook.md
- Checklist: docs/demos/e2e-proof-checklist.md
