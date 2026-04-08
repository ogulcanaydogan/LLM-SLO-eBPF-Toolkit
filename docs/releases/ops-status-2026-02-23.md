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
- Current implementation SHA: `a8ebd45`.
- Burn-in evaluator baseline reset:
  - `since_utc`: `2026-03-06T00:00:00Z`
  - `sha_lock`: `a8ebd458f267051fc986c718b6e77b7166ca4f13` (repository variable `BURNIN_SHA_LOCK`)
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

## v1.0.0 GA Cut Evidence (2026-03-30)
- Burn-in lock alignment:
  - `main` SHA at cut: `1e01324e8815c77c7198e632d187e8227d47ca33`
  - `BURNIN_SHA_LOCK`: `1e01324e8815c77c7198e632d187e8227d47ca33`
- Scheduled GO gate:
  - `v1-go-evaluator`: `23734418843` success (`evaluate-go` success, event=`schedule`).
- Scheduled privileged evidence set (all success, fallback skipped where applicable):
  - `weekly-benchmark`: `23731451140` (`full-benchmark-matrix` success, `synthetic-fallback-matrix` skipped).
  - `kernel-compatibility-matrix`: `23730165792` (`compat-kernel-5-15` and `compat-kernel-6-8` success).
  - `e2e-evidence-report`: `23729546132` (`evidence-e2e` success, `evidence-runner-required` skipped).
  - `nightly-ebpf-integration`: `23727932128` (`privileged-kind-integration` success, `synthetic-fallback-integration` skipped).
- GA release publication:
  - Tag: `v1.0.0`
  - Release workflow: `23740998931` success.
  - Release URL: https://github.com/ogulcanaydogan/LLM-SLO-eBPF-Toolkit/releases/tag/v1.0.0
- Release artifact integrity:
  - Required assets published: binaries, `checksums-sha256.txt`, `sbom-spdx.json`, `provenance.json`, `release-artifacts.json`, `llm-slo-agent-1.0.0.tgz`.
  - `release-artifacts.json` digests verified:
    - agent: `sha256:3f66e372ec241695379c697b5e6cdfbc001d1f9fb213e74cde554a6d7ad164f3`
    - rag_service: `sha256:c5b160390155513b7157e30113088d9c132815a2bcbb0d8feffd8e97f753e0f6`
    - helm_chart: `sha256:db1a2e8f63d8d0dd578217852dda00b70194e967674cfa0976c9b7ed612f679c`
- Evidence policy statement:
  - Release-grade claim sources remain scheduled + privileged paths only; fallback artifacts are excluded from GA evidence.

## Final Closure
- v1.0.0 GA complete, GO gate closed on 2026-03-30.

## v1.0.1 Post-GA Hardening Closure (2026-03-30)
- `main` SHA (hardening final): `75962836e35552650fc622ff43b4484af0ecdd4a`
- CI validation on final SHA:
  - `ci`: `23745033173` success.
- Post-GA monitoring validations on final SHA:
  - `v1-go-evaluator` (workflow_dispatch, default `post_ga_monitoring`): `23745253586` success.
  - `runner-health` (workflow_dispatch): `23745255471` success.
- v1.0.1 GA release publication:
  - Tag: `v1.0.1`
  - Release workflow: `23745046189` success.
  - Release URL: https://github.com/ogulcanaydogan/LLM-SLO-eBPF-Toolkit/releases/tag/v1.0.1
- v1.0.1 release artifact integrity:
  - Required assets present: binaries, `checksums-sha256.txt`, `sbom-spdx.json`, `provenance.json`, `release-artifacts.json`, `llm-slo-agent-1.0.1.tgz`.
  - `release-artifacts.json` digests verified non-empty:
    - agent: `sha256:270a7a374226c54a4f6a8b979590004ead2e0b09f4a5fbac2f02cbc8c9b2380e`
    - rag_service: `sha256:6380bcab6ccbdabd609d4b29198c3fa4b15c086218f63bd49944988e8cba4018`
    - helm_chart: `sha256:5245927ac2a934da7da49da073483da5b8616fe15f2c856041923b408b2122c6`
- Scheduled release-grade evidence policy remains unchanged:
  - release-grade evidence = scheduled + privileged paths only.
  - latest scheduled reference set remains 2026-03-30 windows (`weekly-benchmark` `23731451140`, `nightly-ebpf-integration` `23727932128`) with fallback jobs skipped.

## Runner Outage Recovery (2026-04-02, Work AWS Account)
- Outage signal:
  - `runner-health` scheduled failures: `23887613724`, `23889450509`, `23891381726`, `23892302136`, `23893645764`.
  - `runner-canary` scheduled failures: `23887657097`, `23889661343`, `23891630201`, `23893894809`.
  - GitHub issue opened by guardrail automation: `#25`.
- Root cause:
  - Previous runner EC2 instances were terminated and runner inventory dropped to zero online `self-hosted,linux,ebpf` capacity.
- Recovery execution:
  - Switched provisioning to work AWS account `736242394405` (no further changes on personal account).
  - Reprovisioned runner fleet with Terraform in `infra/runner/aws` on work account default VPC `vpc-0a909261ff33af5a2`.
  - New instances:
    - `kernel_5_15`: `i-044105e8a98ef0878`
    - `kernel_6_8`: `i-0b1e838d5daccef95`
  - Verified protection attributes on both instances:
    - `disableApiStop=true`
    - `disableApiTermination=true`
  - Removed stale offline GitHub runner records `id=213` and `id=214`.
- Post-recovery dispatch validation (privileged path):
  - `runner-health`: `23896502110` success.
  - `runner-canary`: `23896502824` success.
  - `nightly-ebpf-integration`: `23896503799` success (`privileged-kind-integration` success, `synthetic-fallback-integration` skipped).
  - `weekly-benchmark`: `23896504960` success (`full-benchmark-matrix` success, `synthetic-fallback-matrix` skipped).
  - `kernel-compatibility-matrix`: `23896506126` success (`compat-kernel-5-15` + `compat-kernel-6-8` success, unavailable jobs skipped).
  - `e2e-evidence-report`: `23896507000` success (`evidence-e2e` success, `evidence-runner-required` skipped).
- Incident closure:
  - Added recovery note to issue `#25` and closed it after capacity restoration.
- Evidence policy remains unchanged:
  - release-grade evidence = scheduled + privileged paths only; fallback artifacts remain excluded from release claims.

## Dual-Kernel Truth Fix (2026-04-04)
- Objective:
  - Enforce real dual-kernel runner profiles (5.15 + 6.8), not label-only profile claims.
- Work AWS account scope:
  - Account: `736242394405`.
  - Region: `us-east-1`.
- Terraform profile AMI pinning applied in `/Users/ogulcanaydogan/Desktop/Projects/AI-Portfolio/first_badge/LLM-SLO-eBPF-Toolkit/infra/runner/aws/terraform.tfvars`:
  - `kernel_5_15.ami_id = ami-0fb0b230890ccd1e6`.
  - `kernel_6_8.ami_id = ami-00de3875b03809ec5`.
- Targeted reprovision:
  - Recreated only `aws_instance.runner["kernel_5_15"]` via Terraform replace.
  - New instance IDs after apply:
    - `kernel_5_15`: `i-0cc0e4bbf310221bb` (AMI `ami-0fb0b230890ccd1e6`)
    - `kernel_6_8`: `i-0b1e838d5daccef95` (AMI `ami-00de3875b03809ec5`)
- EC2 protection re-validated on both instances:
  - `disableApiStop=true`
  - `disableApiTermination=true`
- Kernel truth (SSM `uname -r`) evidence:
  - `i-0cc0e4bbf310221bb` -> `5.15.0-1084-aws`
  - `i-0b1e838d5daccef95` -> `6.8.0-1050-aws`
- Runner inventory cleanup:
  - Removed stale offline runner `id=224`.
  - Online runners after fix:
    - `id=225` labels: `self-hosted,linux,ebpf,kernel-5-15`
    - `id=219` labels: `self-hosted,linux,ebpf,kernel-6-8`
- Profile discovery check:
  - `total_online_ebpf_runners=2`
  - `kernel-5-15.available=true`
  - `kernel-6-8.available=true`

### Manual Privileged Smoke Sweep (Diagnostic, Non-GO)
- `runner-health`: `23973775501` success.
- `runner-canary`: `23973776501` success.
- `nightly-ebpf-integration`: `23973777508` success:
  - `privileged-kind-integration=success`
  - `synthetic-fallback-integration=skipped`
- `weekly-benchmark`: `23973778499` success:
  - `full-benchmark-matrix=success`
  - `synthetic-fallback-matrix=skipped`
- `kernel-compatibility-matrix`: `23973779559` success:
  - `compat-kernel-5-15=success`
  - `compat-kernel-6-8=success`
  - `compat-kernel-5-15-unavailable=skipped`
  - `compat-kernel-6-8-unavailable=skipped`
- `e2e-evidence-report`: `23973780574` success:
  - `evidence-e2e=success`
  - `evidence-runner-required=skipped`

### Scheduled Evidence Policy (Unchanged)
- Release-grade evidence = scheduled + privileged paths only.
- Manual workflow_dispatch runs above are diagnostic validation only and are not counted toward release-grade GO criteria.
- Next scheduled evidence window to record after this fix:
  - Nightly: 2026-04-05
  - Weekly set (`e2e-evidence-report`, `kernel-compatibility-matrix`, `weekly-benchmark`): 2026-04-06

## Scheduled Evidence Window Closure (2026-04-06)
- Scope:
  - This block records scheduled-only, privileged-path evidence after the dual-kernel truth fix.
  - All referenced runs are on SHA `c99452c5baebbc94a67b8b7628711e68f0c2420b`.
- Scheduled run set (2026-04-05 / 2026-04-06):
  - `nightly-ebpf-integration`: `24018666508` (success)
    - URL: https://github.com/ogulcanaydogan/LLM-SLO-eBPF-Toolkit/actions/runs/24018666508
    - Jobs: `privileged-kind-integration=success`, `synthetic-fallback-integration=skipped`.
  - `weekly-benchmark`: `24021854240` (success)
    - URL: https://github.com/ogulcanaydogan/LLM-SLO-eBPF-Toolkit/actions/runs/24021854240
    - Jobs: `full-benchmark-matrix=success`, `synthetic-fallback-matrix=skipped`.
  - `kernel-compatibility-matrix`: `24020715292` (success)
    - URL: https://github.com/ogulcanaydogan/LLM-SLO-eBPF-Toolkit/actions/runs/24020715292
    - Jobs: `compat-kernel-5-15=success`, `compat-kernel-6-8=success`, unavailable stubs skipped.
  - `e2e-evidence-report`: `24020160673` (success)
    - URL: https://github.com/ogulcanaydogan/LLM-SLO-eBPF-Toolkit/actions/runs/24020160673
    - Jobs: `evidence-e2e=success`, `evidence-runner-required=skipped`.
  - `runner-health`: `24024182353` (success)
    - URL: https://github.com/ogulcanaydogan/LLM-SLO-eBPF-Toolkit/actions/runs/24024182353
  - `runner-canary`: `24025263432` (success)
    - URL: https://github.com/ogulcanaydogan/LLM-SLO-eBPF-Toolkit/actions/runs/24025263432

### Final Operational Checkpoint
- 2026-04-06 scheduled window complete.
- Dual-kernel truth (`5.15.x` + `6.8.x`) now aligns with runner profile labels and scheduled privileged CI evidence.
- release-grade evidence = scheduled + privileged paths only; fallback artifacts remain non-release-grade.


## Node24 Workflow Runtime Maintenance (2026-04-07)
- Scope:
  - GitHub Actions maintenance only; no product API/schema changes.
  - Migrated workflow action versions to Node24-compatible releases in CI/release/nightly/weekly and related operational workflows.
- Tracking:
  - Implementation PR: https://github.com/ogulcanaydogan/LLM-SLO-eBPF-Toolkit/pull/27
  - Related issue: https://github.com/ogulcanaydogan/LLM-SLO-eBPF-Toolkit/issues/26
- Policy:
  - release-grade evidence policy is unchanged: scheduled + privileged paths only.

## Stability Week Kickoff (2026-04-08 to 2026-04-13)
- Scope:
  - Stability-only operational window on `main` SHA `8f48aef88f7670ec01a3667221723a5c283dca2f`.
  - No feature scope added; release-grade evidence remains scheduled + privileged only.
- Main freeze discipline:
  - Non-critical merges are frozen through the 2026-04-13 scheduled weekly window.
  - If a forced merge occurs, baseline reset must be recorded with new SHA.

### Scheduled Snapshot (as of 2026-04-08)
- `runner-health` scheduled cadence on SHA `8f48aef`:
  - 10 successful runs on 2026-04-08 so far.
  - Latest: `24126849459` (success)
    - URL: https://github.com/ogulcanaydogan/LLM-SLO-eBPF-Toolkit/actions/runs/24126849459
- `runner-canary` scheduled cadence on SHA `8f48aef`:
  - 8 successful runs on 2026-04-08 so far.
  - Latest: `24126086956` (success)
    - URL: https://github.com/ogulcanaydogan/LLM-SLO-eBPF-Toolkit/actions/runs/24126086956
- `nightly-ebpf-integration` scheduled on SHA `8f48aef`:
  - Run `24117524206` (success)
    - URL: https://github.com/ogulcanaydogan/LLM-SLO-eBPF-Toolkit/actions/runs/24117524206
    - Jobs: `privileged-kind-integration=success`, `synthetic-fallback-integration=skipped`.

### Latest Scheduled Weekly Set (pre-window baseline)
- `weekly-benchmark`: `24021854240` (success, SHA `c99452c`)
  - URL: https://github.com/ogulcanaydogan/LLM-SLO-eBPF-Toolkit/actions/runs/24021854240
  - Jobs: `full-benchmark-matrix=success`, `synthetic-fallback-matrix=skipped`.
- `kernel-compatibility-matrix`: `24020715292` (success, SHA `c99452c`)
  - URL: https://github.com/ogulcanaydogan/LLM-SLO-eBPF-Toolkit/actions/runs/24020715292
  - Jobs: `compat-kernel-5-15=success`, `compat-kernel-6-8=success`, unavailable stubs skipped.
- `e2e-evidence-report`: `24020160673` (success, SHA `c99452c`)
  - URL: https://github.com/ogulcanaydogan/LLM-SLO-eBPF-Toolkit/actions/runs/24020160673
  - Jobs: `evidence-e2e=success`, `evidence-runner-required=skipped`.

### Maintenance Backlog
- Created non-blocker maintenance issue for post-Node24 runtime warning hygiene:
  - Issue `#28`: https://github.com/ogulcanaydogan/LLM-SLO-eBPF-Toolkit/issues/28
- This issue does not change release-grade criteria and is tracked as operational sustainability work.

### Policy (Unchanged)
- release-grade evidence = scheduled + privileged only.
- workflow_dispatch runs are diagnostic and excluded from release-grade claims.
