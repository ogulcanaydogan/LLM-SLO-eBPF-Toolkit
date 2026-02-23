# Operational Status Snapshot — 2026-02-23

Timestamp (UTC): 2026-02-23T19:55:00Z

## Baseline State
- Local branch: `main`
- Local HEAD before sync: `03173af` (`v0.3.0`)
- Remote main before sync: `00c217c` (`chore: add security policy`)
- Release line:
  - `v0.3.0` (GA)
  - `v0.3.0-rc.2` (pre-release)
  - `v0.3.0-rc.1`
- CI behavior before recovery:
  - `nightly-ebpf-integration`: fallback path active
  - `weekly-benchmark`: fallback path active
  - `kernel-compatibility-matrix`: profile unavailable stubs
  - `runner-health`: failing due zero online eBPF runners
  - `e2e-evidence-report`: failing (`evidence-runner-required`)

## Recovery Actions Executed
1. Fast-forwarded local `main` to `origin/main`.
2. Verified Terraform runner state:
   - `kernel_5_15` instance: `i-0545283dc4f1dd24c`
   - `kernel_6_8` instance: `i-0d7159c2053f4831a`
3. Started both stopped EC2 runner instances.
4. Verified systemd runner service health on both instances via SSM.
5. Verified GitHub runner registration and profile labels:
   - `self-hosted,linux,ebpf,kernel-5-15`
   - `self-hosted,linux,ebpf,kernel-6-8`

## Follow-up Work Included In This Change Set
- Added release-grade benchmark metadata (`runner_mode`, `release_grade`) to benchmark summaries, markdown reports, and provenance.
- Added fallback-release guard in weekly workflow (scheduled fallback is now non-release-grade and fails).
- Added runner canary workflow for profile-level discovery + smoke checks.
- Added runner outage playbook.
- Added explicit runner/release-grade fields to e2e evidence report output.

## Remaining Validation To Close
- Completed after recovery:
  - `runner-health` pass streak: `22322424736`, `22322424743`, `22322424768`, `22322536095`, `22322622524`, `22322687481` (all success).
  - `nightly-ebpf-integration` privileged path: `22322430436` success (`privileged-kind-integration` ran, fallback skipped).
  - `weekly-benchmark` full matrix: `22322430470` success (`full-benchmark-matrix` ran, fallback skipped).
  - `kernel-compatibility-matrix` profile jobs: `22322430375` success (real `kernel-5-15` and `kernel-6-8` jobs ran).
  - `e2e-evidence-report`: `22322430409` success (`evidence-e2e` ran, `evidence-runner-required` skipped).
