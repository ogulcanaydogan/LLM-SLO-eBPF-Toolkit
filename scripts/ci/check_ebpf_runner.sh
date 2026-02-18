#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "GITHUB_TOKEN is required" >&2
  exit 1
fi
if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
  echo "GITHUB_REPOSITORY is required" >&2
  exit 1
fi

api_url="https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/runners?per_page=100"
response="$(curl -fsSL \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "$api_url")"

runner_count="$(jq '[.runners[] | select(.status == "online") | select(any(.labels[]?; .name == "self-hosted") and any(.labels[]?; .name == "linux") and any(.labels[]?; .name == "ebpf"))] | length' <<<"$response")"
if [[ "$runner_count" =~ ^[0-9]+$ ]] && [[ "$runner_count" -gt 0 ]]; then
  has_ebpf_runner="true"
else
  has_ebpf_runner="false"
fi

echo "Detected online ebpf runners: $runner_count"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "has_ebpf_runner=$has_ebpf_runner"
    echo "runner_count=$runner_count"
  } >> "$GITHUB_OUTPUT"
fi
