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

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
kernel_release="$(uname -r)"
host_os="$(uname -s)"
host_arch="$(uname -m)"
btf_available="false"
if [[ -f /sys/kernel/btf/vmlinux ]]; then
  btf_available="true"
fi

prereq_status="fail"
prereq_detail=""
prereq_json_path="$(dirname "$OUT")/${PROFILE}-prereq.json"
if go run ./cmd/sloctl prereq check --output json > "$prereq_json_path" 2>/tmp/kernel-prereq.err; then
  prereq_status="pass"
else
  prereq_status="fail"
fi
if [[ -s /tmp/kernel-prereq.err ]]; then
  prereq_detail="$(tr '\n' ' ' </tmp/kernel-prereq.err | sed 's/"/\\"/g')"
fi

probe_status="skipped"
probe_detail="agent probe smoke skipped (non-root)"
if [[ "$(id -u)" -eq 0 ]]; then
  probe_status="fail"
  probe_detail=""
  if go run ./cmd/agent --probe-smoke >/tmp/kernel-probe.out 2>/tmp/kernel-probe.err; then
    probe_status="pass"
    probe_detail="$(tr '\n' ' ' </tmp/kernel-probe.out | sed 's/"/\\"/g')"
  else
    probe_status="fail"
    probe_detail="$(tr '\n' ' ' </tmp/kernel-probe.err | sed 's/"/\\"/g')"
  fi
fi

cat > "$OUT" <<EOF
{
  "profile": "${PROFILE}",
  "timestamp_utc": "${timestamp}",
  "host_os": "${host_os}",
  "host_arch": "${host_arch}",
  "kernel_release": "${kernel_release}",
  "btf_available": ${btf_available},
  "prereq": {
    "status": "${prereq_status}",
    "detail": "${prereq_detail}",
    "json_path": "$(basename "$prereq_json_path")"
  },
  "probe_smoke": {
    "status": "${probe_status}",
    "detail": "${probe_detail}"
  }
}
EOF

if [[ "$STRICT" == "true" ]]; then
  [[ "$prereq_status" == "pass" ]] || exit 1
  [[ "$probe_status" == "pass" || "$probe_status" == "skipped" ]] || exit 1
fi
