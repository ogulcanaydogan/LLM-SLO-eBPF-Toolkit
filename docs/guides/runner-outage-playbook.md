# Runner Outage Playbook (self-hosted, linux, ebpf)

This runbook restores privileged CI capacity when workflows fall back to synthetic mode.

## Scope
- Applies to AWS EC2 runners provisioned via `infra/runner/aws`.
- Target labels:
  - `self-hosted,linux,ebpf`
  - `kernel-5-15`
  - `kernel-6-8`

## Symptoms
- `runner-health` fails with `total_online_ebpf_runners=0`.
- `weekly-benchmark` runs `synthetic-fallback-matrix` and skips `full-benchmark-matrix`.
- `nightly-ebpf-integration` runs `synthetic-fallback-integration` and skips `privileged-kind-integration`.
- `e2e-evidence-report` fails on `evidence-runner-required`.

## Recovery Procedure

1. Verify Terraform state and runner IDs:
```bash
terraform -chdir=infra/runner/aws output
```

2. Check EC2 instance state:
```bash
aws ec2 describe-instances \
  --instance-ids <k515-instance-id> <k68-instance-id> \
  --region us-east-1 \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,PrivateIp:PrivateIpAddress}' \
  --output table
```

3. Start instances if stopped:
```bash
aws ec2 start-instances --instance-ids <k515-instance-id> <k68-instance-id> --region us-east-1
aws ec2 wait instance-running --instance-ids <k515-instance-id> <k68-instance-id> --region us-east-1
```

4. Verify runner service via SSM:
```bash
aws ssm send-command \
  --instance-ids <k515-instance-id> <k68-instance-id> \
  --region us-east-1 \
  --document-name AWS-RunShellScript \
  --parameters '{"commands":["sudo systemctl is-active gha-ephemeral-runner.service","sudo journalctl -u gha-ephemeral-runner.service --since \"-10 min\" --no-pager -n 80"]}'
```

5. Verify GitHub runner registration:
```bash
gh api repos/ogulcanaydogan/LLM-SLO-eBPF-Toolkit/actions/runners \
  --jq '.runners[] | {name,status,labels:[.labels[].name]}'
```

6. Verify profile discovery:
```bash
RUNNER_STATUS_TOKEN="$(gh auth token)" \
GITHUB_REPOSITORY=ogulcanaydogan/LLM-SLO-eBPF-Toolkit \
./scripts/ci/check_runner_profiles.sh --profiles kernel-5-15,kernel-6-8 --out /tmp/runner-profiles.json
jq . /tmp/runner-profiles.json
```

## Post-Recovery Validation

Run and confirm privileged paths:
```bash
gh workflow run runner-health.yml
gh workflow run nightly-ebpf-integration.yml
gh workflow run weekly-benchmark.yml
gh workflow run kernel-compatibility-matrix.yml
gh workflow run e2e-evidence-report.yml
```

Expected:
- `runner-health` passes
- `nightly-ebpf-integration` uses `privileged-kind-integration`
- `weekly-benchmark` uses `full-benchmark-matrix`
- `kernel-compatibility-matrix` runs profile jobs (not `*-unavailable`)
- `e2e-evidence-report` runs `evidence-e2e`

## Preventive Action
- Keep EC2 runner instances in `running` state.
- Keep `RUNNER_STATUS_TOKEN` valid.
- Monitor `runner-canary` workflow failures and treat as paging signal.
