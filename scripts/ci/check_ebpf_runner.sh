#!/usr/bin/env bash
set -euo pipefail

api_token="${RUNNER_STATUS_TOKEN:-${GITHUB_TOKEN:-}}"

if [[ -z "$api_token" ]]; then
  echo "RUNNER_STATUS_TOKEN or GITHUB_TOKEN is required" >&2
  exit 1
fi
if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
  echo "GITHUB_REPOSITORY is required" >&2
  exit 1
fi

api_url="https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/runners?per_page=100"
tmp_body="$(mktemp)"
http_code="$(curl -sS -o "$tmp_body" -w "%{http_code}" \
  -H "Authorization: Bearer ${api_token}" \
  -H "Accept: application/vnd.github+json" \
  "$api_url" || true)"

runner_count="0"
has_ebpf_runner="false"
reason="fallback_default"
if [[ "$http_code" == "200" ]]; then
  response="$(cat "$tmp_body")"
  runner_count="$(jq '[.runners[] | select(.status == "online") | select(any(.labels[]?; (.name | ascii_downcase) == "self-hosted") and any(.labels[]?; (.name | ascii_downcase) == "linux") and any(.labels[]?; (.name | ascii_downcase) == "ebpf"))] | length' <<<"$response")"
  if [[ "$runner_count" =~ ^[0-9]+$ ]] && [[ "$runner_count" -gt 0 ]]; then
    has_ebpf_runner="true"
  fi
  reason="api_success"
else
  reason="api_http_${http_code:-error}"
fi
rm -f "$tmp_body"

echo "Detected online ebpf runners: $runner_count (reason: $reason)"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "has_ebpf_runner=$has_ebpf_runner"
    echo "runner_count=$runner_count"
    echo "reason=$reason"
  } >> "$GITHUB_OUTPUT"
fi
