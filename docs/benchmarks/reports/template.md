# LLM SLO eBPF Benchmark Report Template

## Run Metadata
- Run ID:
- Scenario:
- Workload Profile:
- Cluster/Kernel Profile:
- Commit:
- Collector Image Digest:

## Experimental Conditions
- Baseline:
- Treatment(s):
- Fault Injection Matrix Covered:
- Sample Size:
- Confidence Level:

## Key Results
- Detection delay median (with CI95):
- Attribution macro-F1 (with CI95):
- Per-fault precision/recall/F1:
- False positive / false negative rates:
- Abstain rate:
- Burn-rate prediction error:
- Collector overhead (CPU/memory/events/drops):

## Failure and Drift Checks
- Artifact completeness check:
- Summary vs raw recomputation check:
- Environment drift from baseline:

## Raw Artifacts
- `artifacts/events/*.jsonl`
- `artifacts/metrics/incident_predictions.csv`
- `artifacts/metrics/confusion_matrix.csv`
- `artifacts/metrics/class_metrics.csv`
- `artifacts/metrics/collector_overhead.csv`
- `artifacts/summary/attribution_summary.json`
- `artifacts/environment-manifest.yaml`

## Notes
- Multi-fault behavior observations:
- Known limitations:
- Failed scenarios and why:
- Reproduction command:
