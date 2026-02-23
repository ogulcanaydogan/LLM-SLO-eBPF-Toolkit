# Kernel Compatibility Matrix

This page tracks compatibility checks for privileged eBPF execution across supported runner kernel profiles.

- Generated at (UTC): 2026-02-23T22:17:28Z
- Source run: `22326028010`
- Report source directory: `artifacts/compatibility`

## Matrix

| Profile Label | Availability | Kernel Release | BTF | `sloctl prereq` | `agent --probe-smoke` | Validation | Privilege Path | Failure Reason |
|---|---|---|---|---|---|---|---|---|
| `kernel-5-15` | available | `5.15.0-1084-aws` | `true` | `pass` | `pass` | `strict` | `sudo` | n/a |
| `kernel-6-8` | available | `6.17.0-1007-aws` | `true` | `pass` | `pass` | `strict` | `sudo` | n/a |

## Interpretation

- `available`: matrix job ran on a runner matching the profile label.
- `unavailable`: no online runner with the requested label was detected in preflight.
- `prereq.status=pass`: strict prerequisite checks succeeded.
- `probe_smoke.status=pass`: probe loader smoke succeeded under privileged execution.
- `validation_mode`: `strict` for release-grade compatibility checks.
- `privilege_mode`: `root` (already root), `sudo` (passwordless sudo used), or `unavailable` (cannot run privileged checks).
- `failure_reason`: explicit reason when strict checks fail.

## Notes

- These checks are intended as compatibility signals, not full performance regressions.
- Full SLO/perf and incident reproducibility gates remain in weekly benchmark workflows.
