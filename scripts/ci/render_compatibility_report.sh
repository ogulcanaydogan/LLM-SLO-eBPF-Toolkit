#!/usr/bin/env bash
set -euo pipefail

INPUT_DIR="${1:-artifacts/compatibility}"
OUT_FILE="${2:-docs/compatibility.md}"
RUN_ID="${RUN_ID:-manual}"

mkdir -p "$(dirname "$OUT_FILE")"

read_field() {
  local file="$1"
  local expr="$2"
  local value
  if [[ ! -f "$file" ]]; then
    echo "n/a"
    return 0
  fi
  value="$(jq -r "$expr" "$file" 2>/dev/null || true)"
  if [[ -z "$value" || "$value" == "null" ]]; then
    echo "n/a"
    return 0
  fi
  echo "$value"
}

render_row() {
  local label="$1"
  local status="$2"
  local kernel="$3"
  local btf="$4"
  local prereq="$5"
  local probe="$6"
  local validation="$7"
  local privilege="$8"
  local failure="$9"
  printf '| `%s` | %s | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | %s |\n' "$label" "$status" "$kernel" "$btf" "$prereq" "$probe" "$validation" "$privilege" "$failure"
}

K515="$INPUT_DIR/kernel-5-15.json"
K68="$INPUT_DIR/kernel-6-8.json"

K515_STATUS="$(read_field "$K515" '.status // "available"')"
K515_KERNEL="$(read_field "$K515" '.kernel_release')"
K515_BTF="$(read_field "$K515" '.btf_available')"
K515_PREREQ="$(read_field "$K515" '.prereq.status')"
K515_PROBE="$(read_field "$K515" '.probe_smoke.status')"
K515_VALIDATION="$(read_field "$K515" '.execution.validation_mode')"
K515_PRIVILEGE="$(read_field "$K515" '.execution.privilege_mode')"
K515_FAILURE="$(read_field "$K515" '.execution.failure_reason')"

K68_STATUS="$(read_field "$K68" '.status // "available"')"
K68_KERNEL="$(read_field "$K68" '.kernel_release')"
K68_BTF="$(read_field "$K68" '.btf_available')"
K68_PREREQ="$(read_field "$K68" '.prereq.status')"
K68_PROBE="$(read_field "$K68" '.probe_smoke.status')"
K68_VALIDATION="$(read_field "$K68" '.execution.validation_mode')"
K68_PRIVILEGE="$(read_field "$K68" '.execution.privilege_mode')"
K68_FAILURE="$(read_field "$K68" '.execution.failure_reason')"

GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "$OUT_FILE" <<EOF
# Kernel Compatibility Matrix

This page tracks compatibility checks for privileged eBPF execution across supported runner kernel profiles.

- Generated at (UTC): ${GENERATED_AT}
- Source run: \`${RUN_ID}\`
- Report source directory: \`${INPUT_DIR}\`

## Matrix

| Profile Label | Availability | Kernel Release | BTF | \`sloctl prereq\` | \`agent --probe-smoke\` | Validation | Privilege Path | Failure Reason |
|---|---|---|---|---|---|---|---|---|
EOF

render_row "kernel-5-15" "$K515_STATUS" "$K515_KERNEL" "$K515_BTF" "$K515_PREREQ" "$K515_PROBE" "$K515_VALIDATION" "$K515_PRIVILEGE" "$K515_FAILURE" >> "$OUT_FILE"
render_row "kernel-6-8" "$K68_STATUS" "$K68_KERNEL" "$K68_BTF" "$K68_PREREQ" "$K68_PROBE" "$K68_VALIDATION" "$K68_PRIVILEGE" "$K68_FAILURE" >> "$OUT_FILE"

cat >> "$OUT_FILE" <<'EOF'

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
EOF
