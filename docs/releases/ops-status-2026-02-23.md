# Operational Status Snapshot — 2026-02-23

Timestamp (UTC): 2026-02-23T21:00:00Z

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
- Added fallback-release guard in nightly workflow (scheduled fallback now fails as non-release-grade).
- Added runner canary workflow for profile-level discovery + smoke checks.
- Added runner outage playbook.
- Added explicit runner/release-grade fields to e2e evidence report output.

## Operational Validation Base SHA
- Base SHA: `31089bf` (`ci: improve kernel compatibility probe diagnostics and strict gating`)

## Full-Path Validation (Base SHA `31089bf`)
- `ci`: `22324023413` success.
- `nightly-ebpf-integration`: `22324024825` success (`privileged-kind-integration` ran, fallback skipped).
- `weekly-benchmark`: `22324025630` success (`full-benchmark-matrix` ran, fallback skipped).
- `e2e-evidence-report`: `22324026363` success (`evidence-e2e` ran, `evidence-runner-required` skipped).
- `kernel-compatibility-matrix` first rerun: `22324018288` failed on `kernel-5-15`.
- `kernel-compatibility-matrix` post-remediation rerun: `22324433398` success (`kernel-5-15` and `kernel-6-8` both pass strict prereq + probe smoke).
- `runner-canary`: `22324545871` success (both kernel profile labels available).
- `runner-health`: `22324188223` and `22324546724` success.

## Host Remediation Applied (Runner Fleet)
- Applied passwordless sudo for `runner` user on both EC2 profile instances via `/etc/sudoers.d/90-gh-runner-nopasswd`.
- Installed missing toolchain on `kernel-5-15` host: `clang` and linux-tools (`bpftool` path).
- Updated bootstrap IaC to enforce these on future reprovision:
  - `/Users/ogulcanaydogan/Desktop/Projects/YaPAY/eBPF + LLM Inference SLO Toolkit/infra/runner/aws/cloud-init.yaml`
  - `/Users/ogulcanaydogan/Desktop/Projects/YaPAY/eBPF + LLM Inference SLO Toolkit/infra/runner/aws/README.md`

## Remaining Validation
- Continue 7-day burn-in tracking for runner stability (`runner-health` + `runner-canary`).
- Maintain 2 consecutive weekly full-matrix privileged passes for v1.0 GO record.

## Latest Head Re-Validation (SHA `1881b22`)
- `ci`: `22324612780` success.
- `runner-health`: `22325236557` success.
- `runner-canary`: `22325492702` success.
- `nightly-ebpf-integration`: `22325673589` success (`privileged-kind-integration` ran, `synthetic-fallback-integration` skipped).
- `weekly-benchmark`: `22325673588` success (`full-benchmark-matrix` ran, `synthetic-fallback-matrix` skipped).
- `kernel-compatibility-matrix`: `22325673716` success (`compat-kernel-5-15` and `compat-kernel-6-8` passed; unavailable stubs skipped).
- `e2e-evidence-report`: `22325674476` success (`evidence-e2e` ran, `evidence-runner-required` skipped).

## Release-Grade Routing Check (Current)
- Scheduled privileged paths are active on `self-hosted,linux,ebpf` runners.
- Synthetic fallback jobs were skipped on latest scheduled validation set above.
- Release-grade evidence should continue to reference privileged runs only (`runner_mode=full-self-hosted-ebpf`, `release_grade=true`).
- Burn-in evaluator automation added:
  - `/Users/ogulcanaydogan/Desktop/Projects/YaPAY/eBPF + LLM Inference SLO Toolkit/scripts/ci/evaluate_v1_go.sh`
  - `/Users/ogulcanaydogan/Desktop/Projects/YaPAY/eBPF + LLM Inference SLO Toolkit/.github/workflows/v1-go-evaluator.yml`

## Latest Head Re-Validation (SHA `807d934`)
- GO policy for v1.0.0 is **scheduled-only evidence**. Manual runs are diagnostic only and excluded from GO counting.
- `ci`: `22326010977` success.
- `runner-health`: `22326198080` success.
- `runner-canary`: `22326342491` success.
- `nightly-ebpf-integration`: `22326027877` success (`privileged-kind-integration` ran, `synthetic-fallback-integration` skipped).
- `weekly-benchmark`: `22326027900` success (`full-benchmark-matrix` ran, `synthetic-fallback-matrix` skipped).
- `kernel-compatibility-matrix`: `22326028010` success (`compat-kernel-5-15` and `compat-kernel-6-8` passed strict checks; unavailable stubs skipped).
- `e2e-evidence-report`: `22326027927` success (`evidence-e2e` ran, `evidence-runner-required` skipped).

## Burn-in Baseline Reset and Runner Hardening (2026-03-06)
- Current implementation SHA: `044b641`.
- Burn-in evaluator baseline reset:
  - `since_utc`: `2026-03-06T00:00:00Z`
  - `sha_lock`: `044b641e4586011731fa6f8d83a3f84032f7ad0e` (repository variable `BURNIN_SHA_LOCK`)
- Runner fleet remediation:
  - Started runner profile instances `i-0d7159c2053f4831a` and `i-0545283dc4f1dd24c`.
  - Enabled EC2 stop protection (`disable-api-stop=true`) on both instances.
  - Enabled EC2 termination protection (`disable-api-termination=true`) on both instances.
  - Verified profile discovery: `total_online_ebpf_runners=2`, `kernel-5-15=available`, `kernel-6-8=available`.

## Manual Validation Sweep (Diagnostic, Non-GO)
- `nightly-ebpf-integration`: `22756943368` success (`privileged-kind-integration` success, `synthetic-fallback-integration` skipped).
- `weekly-benchmark`: `22756944159` success (`full-benchmark-matrix` success, `synthetic-fallback-matrix` skipped).
- `kernel-compatibility-matrix`: `22756945076` success (`compat-kernel-5-15` and `compat-kernel-6-8` success; unavailable stubs skipped).
- `e2e-evidence-report`: `22756945915` success (`evidence-e2e` success, `evidence-runner-required` skipped).
- `runner-health`: `22756946604` success.
- `runner-canary`: `22756947391` success.

## Evaluator Check After Reset
- `v1-go-evaluator`: `22757281236` fail is expected at this stage.
- Failure reasons now indicate only burn-in accumulation gaps (7-day and 2x scheduled windows), not stale pre-reset history.
- Next GO-relevant signal is scheduled windows on/after Monday, March 9, 2026.
