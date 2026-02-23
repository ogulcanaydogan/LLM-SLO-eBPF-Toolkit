#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: evaluate_v1_go.sh --since <ISO8601_UTC> [--repo <owner/repo>] [--sha-lock <sha>] [--out-json <path>] [--out-md <path>]

Examples:
  ./scripts/ci/evaluate_v1_go.sh --since 2026-02-23T00:00:00Z --repo ogulcanaydogan/LLM-SLO-eBPF-Toolkit
  ./scripts/ci/evaluate_v1_go.sh --since 2026-02-23T00:00:00Z --sha-lock 807d93494f2fa07ca0a899ec837f774802e79b63
  ./scripts/ci/evaluate_v1_go.sh --since 2026-02-23T00:00:00Z --fixtures-dir test/unit/fixtures/v1-go/all-pass

Notes:
  - Only scheduled workflow runs are counted (policy_mode=scheduled_only).
  - Manual runs are diagnostic only and excluded from GO counting.
  - Release criterion is non-blocking before v1.0.0 tag exists.
EOF
}

SINCE=""
REPO="${GITHUB_REPOSITORY:-}"
SHA_LOCK=""
OUT_JSON="artifacts/release-go/v1_go_status.json"
OUT_MD="artifacts/release-go/v1_go_status.md"
FIXTURES_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)
      SINCE="${2:-}"
      shift 2
      ;;
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --sha-lock)
      SHA_LOCK="${2:-}"
      shift 2
      ;;
    --out-json)
      OUT_JSON="${2:-}"
      shift 2
      ;;
    --out-md)
      OUT_MD="${2:-}"
      shift 2
      ;;
    --fixtures-dir)
      FIXTURES_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$SINCE" ]]; then
  echo "--since is required (example: 2026-02-23T00:00:00Z)" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 2
fi

if [[ -z "$FIXTURES_DIR" ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI is required" >&2
    exit 2
  fi
  if [[ -n "${GITHUB_TOKEN:-}" && -z "${GH_TOKEN:-}" ]]; then
    export GH_TOKEN="${GITHUB_TOKEN}"
  fi
  if [[ -n "${RUNNER_STATUS_TOKEN:-}" && -z "${GH_TOKEN:-}" ]]; then
    export GH_TOKEN="${RUNNER_STATUS_TOKEN}"
  fi
  if [[ -z "${GH_TOKEN:-}" ]] && ! gh auth status >/dev/null 2>&1; then
    echo "gh auth is required (run: gh auth login) or provide GITHUB_TOKEN/RUNNER_STATUS_TOKEN" >&2
    exit 2
  fi
else
  if [[ ! -d "$FIXTURES_DIR" ]]; then
    echo "fixtures directory not found: $FIXTURES_DIR" >&2
    exit 2
  fi
fi

if [[ -z "$REPO" ]]; then
  remote_url="$(git config --get remote.origin.url 2>/dev/null || true)"
  if [[ -n "$remote_url" ]]; then
    REPO="$(echo "$remote_url" | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')"
  fi
fi
if [[ -z "$REPO" ]]; then
  echo "repository could not be inferred; pass --repo owner/repo" >&2
  exit 2
fi

mkdir -p "$(dirname "$OUT_JSON")" "$(dirname "$OUT_MD")"

TMP_DIR="$(mktemp -d)"
RUNS_DIR="${TMP_DIR}/runs"
JOBS_DIR="${TMP_DIR}/jobs"
CRITERIA_FILE="${TMP_DIR}/criteria.json"
mkdir -p "$RUNS_DIR" "$JOBS_DIR"
echo '[]' > "$CRITERIA_FILE"
trap 'rm -rf "$TMP_DIR"' EXIT

date_utc_offset_day() {
  local offset="$1"
  if date -u -d "-${offset} day" +%F >/dev/null 2>&1; then
    date -u -d "-${offset} day" +%F
  else
    date -u -v-"${offset}"d +%F
  fi
}

append_criterion() {
  local name="$1"
  local required="$2"
  local observed="$3"
  local status="$4"
  local blocking="$5"
  local reason="$6"
  local run_ids_json="${7:-[]}"
  jq \
    --arg name "$name" \
    --arg required "$required" \
    --arg observed "$observed" \
    --arg status "$status" \
    --arg reason "$reason" \
    --argjson blocking "$blocking" \
    --argjson run_ids "$run_ids_json" \
    '. + [{
      name: $name,
      required: $required,
      observed: $observed,
      status: $status,
      blocking: $blocking,
      evidence_run_ids: $run_ids,
      reason: $reason
    }]' \
    "$CRITERIA_FILE" > "${CRITERIA_FILE}.tmp"
  mv "${CRITERIA_FILE}.tmp" "$CRITERIA_FILE"
}

fetch_workflow_runs() {
  local workflow_file="$1"
  local out_file="$2"
  if [[ -n "$FIXTURES_DIR" ]]; then
    local fixture_file="${FIXTURES_DIR}/${workflow_file%.yml}.json"
    if [[ -f "$fixture_file" ]]; then
      jq -e . "$fixture_file" > "$out_file"
    else
      echo "[]" > "$out_file"
    fi
    return
  fi
  local ndjson_file="${out_file}.ndjson"
  if ! gh api --paginate "repos/${REPO}/actions/workflows/${workflow_file}/runs?per_page=100" --jq '.workflow_runs[]' > "$ndjson_file"; then
    echo "[]" > "$out_file"
    return
  fi
  if [[ -s "$ndjson_file" ]]; then
    jq -s '.' "$ndjson_file" > "$out_file"
  else
    echo "[]" > "$out_file"
  fi
}

filter_scheduled_runs() {
  local in_file="$1"
  local out_file="$2"
  jq \
    --arg since "$SINCE" \
    --arg sha "$SHA_LOCK" \
    '[.[] | select(.event == "schedule") | select(.created_at >= $since) | select(($sha == "") or (.head_sha == $sha))]' \
    "$in_file" > "$out_file"
}

get_job_conclusion() {
  local run_id="$1"
  local job_name="$2"
  local cache_file="${JOBS_DIR}/${run_id}.json"
  if [[ -n "$FIXTURES_DIR" ]]; then
    local fixture_job_file="${FIXTURES_DIR}/jobs/${run_id}.json"
    if [[ -f "$fixture_job_file" ]]; then
      cache_file="$fixture_job_file"
    else
      echo "missing"
      return
    fi
  fi
  if [[ ! -f "$cache_file" ]]; then
    local ndjson_file="${cache_file}.ndjson"
    if ! gh api --paginate "repos/${REPO}/actions/runs/${run_id}/jobs?per_page=100" --jq '.jobs[]' > "$ndjson_file"; then
      echo "missing"
      return
    fi
    if [[ -s "$ndjson_file" ]]; then
      jq -s '.' "$ndjson_file" > "$cache_file"
    else
      echo '[]' > "$cache_file"
    fi
  fi
  jq -r --arg name "$job_name" '[.[] | select(.name == $name) | .conclusion] | if length == 0 then "missing" else .[0] end' "$cache_file"
}

evaluate_daily_success() {
  local criterion_name="$1"
  local required_desc="$2"
  local runs_file="$3"
  local required_days="$4"

  local pass_days=0
  local notes=()
  local run_ids='[]'

  for ((offset=0; offset<required_days; offset++)); do
    local day
    day="$(date_utc_offset_day "$offset")"
    local count
    count="$(jq -r --arg day "$day" '[.[] | select(.status == "completed") | select(.created_at[0:10] == $day)] | length' "$runs_file")"
    if [[ "$count" -eq 0 ]]; then
      notes+=("missing:${day}")
      continue
    fi
    local failures
    failures="$(jq -r --arg day "$day" '[.[] | select(.status == "completed") | select(.created_at[0:10] == $day) | select(.conclusion != "success")] | length' "$runs_file")"
    if [[ "$failures" -gt 0 ]]; then
      notes+=("fail:${day}")
      continue
    fi
    pass_days=$((pass_days + 1))
    local day_ids
    day_ids="$(jq -c --arg day "$day" '[.[] | select(.status == "completed") | select(.created_at[0:10] == $day) | .id] | unique' "$runs_file")"
    run_ids="$(jq -c -n --argjson a "$run_ids" --argjson b "$day_ids" '$a + $b | unique')"
  done

  local status="pass"
  local reason="all required days passed"
  local observed="${pass_days}/${required_days} days"
  if [[ ${#notes[@]} -gt 0 ]]; then
    observed="${observed} ($(IFS=,; echo "${notes[*]}"))"
  fi
  if [[ "$pass_days" -ne "$required_days" ]]; then
    status="fail"
    reason="daily success requirement not met"
  fi
  append_criterion "$criterion_name" "$required_desc" "$observed" "$status" true "$reason" "$run_ids"
}

evaluate_recent_runs_with_jobs() {
  local criterion_name="$1"
  local required_desc="$2"
  local runs_file="$3"
  local required_runs="$4"
  local job_a="$5"
  local expect_a="$6"
  local job_b="$7"
  local expect_b="$8"

  local recent_runs
  recent_runs="$(jq -c --argjson n "$required_runs" '[.[] | select(.status == "completed")] | sort_by(.created_at) | reverse | .[:$n]' "$runs_file")"
  local recent_count
  recent_count="$(jq -r 'length' <<<"$recent_runs")"
  local run_ids
  run_ids="$(jq -c 'map(.id)' <<<"$recent_runs")"

  if [[ "$recent_count" -lt "$required_runs" ]]; then
    append_criterion \
      "$criterion_name" \
      "$required_desc" \
      "${recent_count}/${required_runs} runs" \
      "fail" \
      true \
      "not enough scheduled completed runs since ${SINCE}" \
      "$run_ids"
    return
  fi

  local violations=()
  local pass_count=0
  while IFS= read -r run_row; do
    local run_id
    local run_conclusion
    run_id="$(jq -r '.id' <<<"$run_row")"
    run_conclusion="$(jq -r '.conclusion' <<<"$run_row")"
    local ok="true"
    if [[ "$run_conclusion" != "success" ]]; then
      ok="false"
      violations+=("run:${run_id}:conclusion=${run_conclusion}")
    fi

    local actual_a
    actual_a="$(get_job_conclusion "$run_id" "$job_a")"
    if [[ "$actual_a" != "$expect_a" ]]; then
      ok="false"
      violations+=("run:${run_id}:${job_a}=${actual_a} expected:${expect_a}")
    fi

    local actual_b
    actual_b="$(get_job_conclusion "$run_id" "$job_b")"
    if [[ "$actual_b" != "$expect_b" ]]; then
      ok="false"
      violations+=("run:${run_id}:${job_b}=${actual_b} expected:${expect_b}")
    fi

    if [[ "$ok" == "true" ]]; then
      pass_count=$((pass_count + 1))
    fi
  done < <(jq -c '.[]' <<<"$recent_runs")

  local status="pass"
  local reason="recent scheduled runs match required job pattern"
  local observed="${pass_count}/${required_runs} runs"
  if [[ "${#violations[@]}" -gt 0 ]]; then
    status="fail"
    reason="$(IFS='; '; echo "${violations[*]}")"
  fi
  append_criterion "$criterion_name" "$required_desc" "$observed" "$status" true "$reason" "$run_ids"
}

evaluate_no_scheduled_fallback() {
  local weekly_file="$1"
  local nightly_file="$2"

  local weekly_runs
  local nightly_runs
  weekly_runs="$(jq -c '[.[] | select(.status == "completed")] | sort_by(.created_at) | reverse' "$weekly_file")"
  nightly_runs="$(jq -c '[.[] | select(.status == "completed")] | sort_by(.created_at) | reverse' "$nightly_file")"

  local checked=0
  local violations=()
  local run_ids='[]'

  while IFS= read -r run_id; do
    [[ -z "$run_id" ]] && continue
    checked=$((checked + 1))
    run_ids="$(jq -c -n --argjson a "$run_ids" --argjson b "[$run_id]" '$a + $b | unique')"
    local fallback_conclusion
    fallback_conclusion="$(get_job_conclusion "$run_id" "synthetic-fallback-matrix")"
    if [[ "$fallback_conclusion" != "skipped" ]]; then
      violations+=("weekly:${run_id}:synthetic-fallback-matrix=${fallback_conclusion}")
    fi
  done < <(jq -r '.[].id' <<<"$weekly_runs")

  while IFS= read -r run_id; do
    [[ -z "$run_id" ]] && continue
    checked=$((checked + 1))
    run_ids="$(jq -c -n --argjson a "$run_ids" --argjson b "[$run_id]" '$a + $b | unique')"
    local fallback_conclusion
    fallback_conclusion="$(get_job_conclusion "$run_id" "synthetic-fallback-integration")"
    if [[ "$fallback_conclusion" != "skipped" ]]; then
      violations+=("nightly:${run_id}:synthetic-fallback-integration=${fallback_conclusion}")
    fi
  done < <(jq -r '.[].id' <<<"$nightly_runs")

  local status="pass"
  local reason="no scheduled fallback usage detected"
  local observed="checked=${checked} violations=0"
  if [[ "${#violations[@]}" -gt 0 ]]; then
    status="fail"
    observed="checked=${checked} violations=${#violations[@]}"
    reason="$(IFS='; '; echo "${violations[*]}")"
  fi

  append_criterion \
    "no_scheduled_fallback_usage" \
    "0 non-skipped fallback jobs in scheduled nightly/weekly runs" \
    "$observed" \
    "$status" \
    true \
    "$reason" \
    "$run_ids"
}

evaluate_release_artifacts() {
  local run_ids='[]'
  local status="pending"
  local observed="v1.0.0 tag not found"
  local reason="release artifacts check is pending until v1.0.0 is published"

  local release_json="${TMP_DIR}/release_v1_0_0.json"
  if [[ -n "$FIXTURES_DIR" && -f "${FIXTURES_DIR}/release-v1.0.0.json" ]]; then
    cp "${FIXTURES_DIR}/release-v1.0.0.json" "$release_json"
  fi

  if [[ -f "$release_json" ]] || gh release view v1.0.0 -R "$REPO" --json tagName,assets,url > "$release_json" 2>/dev/null; then
    local assets
    assets="$(jq -r '.assets[].name' "$release_json" || true)"
    local missing=()
    for required in checksums-sha256.txt sbom-spdx.json provenance.json release-artifacts.json; do
      if ! grep -qx "$required" <<<"$assets"; then
        missing+=("$required")
      fi
    done
    if ! grep -Eq '(^| )[^ ]+-linux-amd64($| )' <<<"$(tr '\n' ' ' <<<"$assets")"; then
      missing+=("*-linux-amd64")
    fi
    if ! grep -Eq '(^| )[^ ]+-darwin-arm64($| )' <<<"$(tr '\n' ' ' <<<"$assets")"; then
      missing+=("*-darwin-arm64")
    fi
    if ! grep -Eq '(^| )llm-slo-agent-.*\.tgz($| )' <<<"$(tr '\n' ' ' <<<"$assets")"; then
      missing+=("llm-slo-agent-*.tgz")
    fi

    if [[ "${#missing[@]}" -eq 0 ]]; then
      status="pass"
      observed="all required v1.0.0 artifacts present"
      reason="release assets complete"
    else
      status="fail"
      observed="missing assets: $(IFS=,; echo "${missing[*]}")"
      reason="release asset completeness check failed"
    fi
  fi

  append_criterion \
    "release_v1_0_0_artifacts" \
    "release.yml publishes binaries, checksums, SBOM, provenance, images, and Helm chart" \
    "$observed" \
    "$status" \
    false \
    "$reason" \
    "$run_ids"
}

RUNNER_HEALTH_RAW="${RUNS_DIR}/runner-health.raw.json"
RUNNER_CANARY_RAW="${RUNS_DIR}/runner-canary.raw.json"
NIGHTLY_RAW="${RUNS_DIR}/nightly.raw.json"
WEEKLY_RAW="${RUNS_DIR}/weekly.raw.json"
KERNEL_RAW="${RUNS_DIR}/kernel.raw.json"
E2E_RAW="${RUNS_DIR}/e2e.raw.json"

fetch_workflow_runs "runner-health.yml" "$RUNNER_HEALTH_RAW"
fetch_workflow_runs "runner-canary.yml" "$RUNNER_CANARY_RAW"
fetch_workflow_runs "nightly-ebpf-integration.yml" "$NIGHTLY_RAW"
fetch_workflow_runs "weekly-benchmark.yml" "$WEEKLY_RAW"
fetch_workflow_runs "kernel-compatibility-matrix.yml" "$KERNEL_RAW"
fetch_workflow_runs "e2e-evidence-report.yml" "$E2E_RAW"

RUNNER_HEALTH_FILTERED="${RUNS_DIR}/runner-health.filtered.json"
RUNNER_CANARY_FILTERED="${RUNS_DIR}/runner-canary.filtered.json"
NIGHTLY_FILTERED="${RUNS_DIR}/nightly.filtered.json"
WEEKLY_FILTERED="${RUNS_DIR}/weekly.filtered.json"
KERNEL_FILTERED="${RUNS_DIR}/kernel.filtered.json"
E2E_FILTERED="${RUNS_DIR}/e2e.filtered.json"

filter_scheduled_runs "$RUNNER_HEALTH_RAW" "$RUNNER_HEALTH_FILTERED"
filter_scheduled_runs "$RUNNER_CANARY_RAW" "$RUNNER_CANARY_FILTERED"
filter_scheduled_runs "$NIGHTLY_RAW" "$NIGHTLY_FILTERED"
filter_scheduled_runs "$WEEKLY_RAW" "$WEEKLY_FILTERED"
filter_scheduled_runs "$KERNEL_RAW" "$KERNEL_FILTERED"
filter_scheduled_runs "$E2E_RAW" "$E2E_FILTERED"

evaluate_daily_success \
  "runner_health_7d" \
  "7 consecutive UTC days with scheduled runner-health success" \
  "$RUNNER_HEALTH_FILTERED" \
  7

evaluate_daily_success \
  "runner_canary_7d" \
  "7 consecutive UTC days with scheduled runner-canary success" \
  "$RUNNER_CANARY_FILTERED" \
  7

evaluate_recent_runs_with_jobs \
  "nightly_privileged_2x" \
  "2 consecutive scheduled nightly runs with privileged-kind-integration=success and synthetic fallback=skipped" \
  "$NIGHTLY_FILTERED" \
  2 \
  "privileged-kind-integration" "success" \
  "synthetic-fallback-integration" "skipped"

evaluate_recent_runs_with_jobs \
  "weekly_privileged_2x" \
  "2 consecutive scheduled weekly runs with full-benchmark-matrix=success and synthetic fallback=skipped" \
  "$WEEKLY_FILTERED" \
  2 \
  "full-benchmark-matrix" "success" \
  "synthetic-fallback-matrix" "skipped"

evaluate_recent_runs_with_jobs \
  "kernel_compatibility_2x" \
  "2 consecutive scheduled kernel matrix runs with kernel-5-15 and kernel-6-8 strict checks passing" \
  "$KERNEL_FILTERED" \
  2 \
  "compat-kernel-5-15" "success" \
  "compat-kernel-6-8" "success"

evaluate_recent_runs_with_jobs \
  "e2e_evidence_2x" \
  "2 consecutive scheduled e2e evidence runs with evidence-e2e=success and runner-required=skipped" \
  "$E2E_FILTERED" \
  2 \
  "evidence-e2e" "success" \
  "evidence-runner-required" "skipped"

evaluate_no_scheduled_fallback "$WEEKLY_FILTERED" "$NIGHTLY_FILTERED"
evaluate_release_artifacts

EVAL_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
jq -n \
  --arg evaluation_timestamp_utc "$EVAL_TS" \
  --arg policy_mode "scheduled_only" \
  --arg repo "$REPO" \
  --arg since "$SINCE" \
  --arg sha_lock "$SHA_LOCK" \
  --slurpfile criteria "$CRITERIA_FILE" \
  '{
    evaluation_timestamp_utc: $evaluation_timestamp_utc,
    policy_mode: $policy_mode,
    repo: $repo,
    since: $since,
    sha_lock: $sha_lock,
    criteria: $criteria[0],
    overall_status: (if ([ $criteria[0][] | select(.blocking == true and .status != "pass") ] | length) == 0 then "pass" else "fail" end),
    failure_reasons: [ $criteria[0][] | select(.blocking == true and .status != "pass") | "\(.name): \(.reason)" ]
  }' > "$OUT_JSON"

{
  echo "# v1.0.0 GO Evaluator"
  echo
  echo "- Evaluation timestamp (UTC): \`${EVAL_TS}\`"
  echo "- Policy mode: \`scheduled_only\`"
  echo "- Repository: \`${REPO}\`"
  echo "- Since: \`${SINCE}\`"
  if [[ -n "$SHA_LOCK" ]]; then
    echo "- SHA lock: \`${SHA_LOCK}\`"
  else
    echo "- SHA lock: \`none\`"
  fi
  echo "- Overall status: **$(jq -r '.overall_status' "$OUT_JSON" | tr '[:lower:]' '[:upper:]')**"
  echo
  echo "| Criterion | Required | Observed | Status | Blocking | Evidence Runs |"
  echo "|---|---|---|---|---|---|"
  jq -r '.criteria[] | "| `\(.name)` | \(.required) | \(.observed) | \(.status) | \(.blocking) | \((.evidence_run_ids | map(tostring) | join(","))) |"' "$OUT_JSON"
  echo
  echo "## Failure Reasons"
  local_fail_count="$(jq -r '.failure_reasons | length' "$OUT_JSON")"
  if [[ "$local_fail_count" -eq 0 ]]; then
    echo "- none"
  else
    jq -r '.failure_reasons[] | "- " + .' "$OUT_JSON"
  fi
} > "$OUT_MD"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  cat "$OUT_MD" >> "$GITHUB_STEP_SUMMARY"
fi

if [[ "$(jq -r '.overall_status' "$OUT_JSON")" != "pass" ]]; then
  exit 1
fi
