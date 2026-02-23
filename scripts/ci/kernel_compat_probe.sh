#!/usr/bin/env bash
set -euo pipefail

PROFILE=""
OUT=""
STRICT="${STRICT:-false}"

usage() {
  cat <<EOF
Usage: $0 --profile <label> --out <path>
Env:
  STRICT=true|false   Fail non-zero when prereq/probe checks fail (default: false)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --out)
      OUT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$PROFILE" || -z "$OUT" ]]; then
  usage
  exit 2
fi

mkdir -p "$(dirname "$OUT")"
WORK_DIR="$(mktemp -d)"
PREREQ_ERR_FILE="${WORK_DIR}/kernel-prereq.err"
PROBE_ERR_FILE="${WORK_DIR}/kernel-probe.err"
PROBE_OUT_FILE="${WORK_DIR}/kernel-probe.out"
trap 'rm -rf "$WORK_DIR"' EXIT

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
kernel_release="$(uname -r)"
host_os="$(uname -s)"
host_arch="$(uname -m)"
btf_available="false"
if [[ -f /sys/kernel/btf/vmlinux ]]; then
  btf_available="true"
fi

executed_as_root="false"
if [[ "$(id -u)" -eq 0 ]]; then
  executed_as_root="true"
fi

sudo_available="false"
if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
  sudo_available="true"
fi

validation_mode="best_effort"
if [[ "$STRICT" == "true" ]]; then
  validation_mode="strict"
fi

privilege_mode="unavailable"
if [[ "$executed_as_root" == "true" ]]; then
  privilege_mode="root"
elif [[ "$sudo_available" == "true" ]]; then
  privilege_mode="sudo"
fi

run_privileged() {
  if [[ "$executed_as_root" == "true" ]]; then
    "$@"
    return $?
  fi
  if [[ "$sudo_available" == "true" ]]; then
    sudo -n -- "$@"
    return $?
  fi
  return 125
}

BINDIR="${WORK_DIR}/bin"
mkdir -p "$BINDIR"
go build -o "${BINDIR}/sloctl" ./cmd/sloctl
go build -o "${BINDIR}/agent" ./cmd/agent

prereq_status="fail"
prereq_detail=""
prereq_json_path="$(dirname "$OUT")/${PROFILE}-prereq.json"
if run_privileged "${BINDIR}/sloctl" prereq check --output json --strict > "$prereq_json_path" 2>"$PREREQ_ERR_FILE"; then
  prereq_status="pass"
else
  prereq_status="fail"
fi
if [[ -s "$PREREQ_ERR_FILE" ]]; then
  prereq_detail="$(tr '\n' ' ' <"$PREREQ_ERR_FILE")"
fi

probe_status="fail"
probe_detail=""
if run_privileged "${BINDIR}/agent" --probe-smoke >"$PROBE_OUT_FILE" 2>"$PROBE_ERR_FILE"; then
  probe_status="pass"
  if [[ -s "$PROBE_OUT_FILE" ]]; then
    probe_detail="$(tr '\n' ' ' <"$PROBE_OUT_FILE")"
  fi
else
  probe_status="fail"
  if [[ -s "$PROBE_ERR_FILE" ]]; then
    probe_detail="$(tr '\n' ' ' <"$PROBE_ERR_FILE")"
  fi
fi

failure_reason=""
if [[ "$privilege_mode" == "unavailable" ]]; then
  failure_reason="privileged execution unavailable (runner user must be root or have passwordless sudo)"
fi
if [[ "$prereq_status" != "pass" ]]; then
  if [[ -n "$failure_reason" ]]; then
    failure_reason="${failure_reason}; "
  fi
  failure_reason="${failure_reason}prereq strict checks failed"
fi
if [[ "$probe_status" != "pass" ]]; then
  if [[ -n "$failure_reason" ]]; then
    failure_reason="${failure_reason}; "
  fi
  failure_reason="${failure_reason}probe smoke failed"
fi

jq -n \
  --arg profile "$PROFILE" \
  --arg status "available" \
  --arg timestamp "$timestamp" \
  --arg host_os "$host_os" \
  --arg host_arch "$host_arch" \
  --arg kernel_release "$kernel_release" \
  --argjson btf_available "$btf_available" \
  --arg prereq_status "$prereq_status" \
  --arg prereq_detail "$prereq_detail" \
  --arg prereq_json_path "$(basename "$prereq_json_path")" \
  --arg probe_status "$probe_status" \
  --arg probe_detail "$probe_detail" \
  --argjson executed_as_root "$executed_as_root" \
  --argjson sudo_available "$sudo_available" \
  --arg validation_mode "$validation_mode" \
  --arg privilege_mode "$privilege_mode" \
  --arg failure_reason "$failure_reason" \
  '{
    profile: $profile,
    status: $status,
    timestamp_utc: $timestamp,
    host_os: $host_os,
    host_arch: $host_arch,
    kernel_release: $kernel_release,
    btf_available: $btf_available,
    execution: {
      executed_as_root: $executed_as_root,
      sudo_available: $sudo_available,
      validation_mode: $validation_mode,
      privilege_mode: $privilege_mode,
      failure_reason: $failure_reason
    },
    prereq: {
      status: $prereq_status,
      detail: $prereq_detail,
      json_path: $prereq_json_path
    },
    probe_smoke: {
      status: $probe_status,
      detail: $probe_detail
    }
  }' > "$OUT"

if [[ "$STRICT" == "true" ]]; then
  [[ "$prereq_status" == "pass" ]] || exit 1
  [[ "$probe_status" == "pass" ]] || exit 1
fi
