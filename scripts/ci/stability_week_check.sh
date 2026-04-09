#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: stability_week_check.sh [options]

Options:
  --repo <owner/repo>       GitHub repository (default: infer from env/git remote)
  --sha-lock <sha>          Baseline SHA lock (default: 9ec8c88)
  --window-date <YYYY-MM-DD>Weekly closure date (default: 2026-04-13)
  --strict                  Exit non-zero unless overall_status=pass
  --out-json <path>         JSON output path (default: artifacts/stability-week/status.json)
  --out-md <path>           Markdown output path (default: artifacts/stability-week/status.md)
  -h, --help                Show help
USAGE
}

REPO="${GITHUB_REPOSITORY:-}"
SHA_LOCK="9ec8c88"
WINDOW_DATE="2026-04-13"
STRICT=false
OUT_JSON="artifacts/stability-week/status.json"
OUT_MD="artifacts/stability-week/status.md"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --sha-lock)
      SHA_LOCK="${2:-}"
      shift 2
      ;;
    --window-date)
      WINDOW_DATE="${2:-}"
      shift 2
      ;;
    --strict)
      STRICT=true
      shift 1
      ;;
    --out-json)
      OUT_JSON="${2:-}"
      shift 2
      ;;
    --out-md)
      OUT_MD="${2:-}"
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

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 2
fi

if [[ -z "$REPO" ]]; then
  remote_url="$(git config --get remote.origin.url 2>/dev/null || true)"
  if [[ -n "$remote_url" ]]; then
    REPO="$(echo "$remote_url" | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')"
  fi
fi
if [[ -z "$REPO" ]]; then
  echo "--repo is required when repository cannot be inferred" >&2
  exit 2
fi

if [[ -n "${GITHUB_TOKEN:-}" && -z "${GH_TOKEN:-}" ]]; then
  export GH_TOKEN="${GITHUB_TOKEN}"
fi
if [[ -n "${RUNNER_STATUS_TOKEN:-}" && -z "${GH_TOKEN:-}" ]]; then
  export GH_TOKEN="${RUNNER_STATUS_TOKEN}"
fi
if [[ -z "${GH_TOKEN:-}" ]] && ! gh auth status >/dev/null 2>&1; then
  echo "warning: gh auth not configured; attempting unauthenticated API access" >&2
fi

mkdir -p "$(dirname "$OUT_JSON")" "$(dirname "$OUT_MD")"

NOW_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TODAY_UTC="$(date -u +%Y-%m-%d)"
WINDOW_REACHED=false
if [[ "$TODAY_UTC" > "$WINDOW_DATE" || "$TODAY_UTC" == "$WINDOW_DATE" ]]; then
  WINDOW_REACHED=true
fi

criteria='[]'

add_criterion() {
  local name="$1"
  local status="$2"
  local detail="$3"
  criteria="$(jq --arg n "$name" --arg s "$status" --arg d "$detail" '. + [{name:$n,status:$s,detail:$d}]' <<<"$criteria")"
}

load_run() {
  local workflow_file="$1"
  local prefix="$2"
  local run_json
  run_json="$({
    gh run list \
      --repo "$REPO" \
      --event schedule \
      --workflow "$workflow_file" \
      --limit 1 \
      --json databaseId,createdAt,status,conclusion,headSha,url \
      --jq '.[0] // {}'
  } 2>/dev/null || echo '{}')"

  local run_id created_at status conclusion head_sha url
  run_id="$(jq -r '.databaseId // ""' <<<"$run_json")"
  created_at="$(jq -r '.createdAt // ""' <<<"$run_json")"
  status="$(jq -r '.status // ""' <<<"$run_json")"
  conclusion="$(jq -r '.conclusion // ""' <<<"$run_json")"
  head_sha="$(jq -r '.headSha // ""' <<<"$run_json")"
  url="$(jq -r '.url // ""' <<<"$run_json")"

  printf -v "${prefix}_id" '%s' "$run_id"
  printf -v "${prefix}_created_at" '%s' "$created_at"
  printf -v "${prefix}_status" '%s' "$status"
  printf -v "${prefix}_conclusion" '%s' "$conclusion"
  printf -v "${prefix}_head_sha" '%s' "$head_sha"
  printf -v "${prefix}_url" '%s' "$url"

  local jobs_json='[]'
  if [[ -n "$run_id" ]]; then
    jobs_json="$(gh run view --repo "$REPO" "$run_id" --json jobs --jq '.jobs // []' 2>/dev/null || echo '[]')"
  fi
  printf -v "${prefix}_jobs" '%s' "$jobs_json"
}

job_conclusion() {
  local jobs_json="$1"
  local job_name="$2"
  jq -r --arg name "$job_name" '[.[] | select(.name == $name) | .conclusion][0] // "missing"' <<<"$jobs_json"
}

starts_with_sha_lock() {
  local sha="$1"
  [[ -n "$sha" && "$sha" == "$SHA_LOCK"* ]]
}

load_run "runner-health.yml" "rh"
load_run "runner-canary.yml" "rc"
load_run "nightly-ebpf-integration.yml" "ng"
load_run "e2e-evidence-report.yml" "e2e"
load_run "kernel-compatibility-matrix.yml" "kc"
load_run "weekly-benchmark.yml" "wb"

if [[ "$rh_conclusion" == "success" ]]; then
  add_criterion "runner_health_latest_success" "pass" "run=${rh_id}"
else
  add_criterion "runner_health_latest_success" "fail" "run=${rh_id} conclusion=${rh_conclusion:-missing}"
fi

if [[ "$rc_conclusion" == "success" ]]; then
  add_criterion "runner_canary_latest_success" "pass" "run=${rc_id}"
else
  add_criterion "runner_canary_latest_success" "fail" "run=${rc_id} conclusion=${rc_conclusion:-missing}"
fi

ng_priv="$(job_conclusion "$ng_jobs" "privileged-kind-integration")"
ng_fallback="$(job_conclusion "$ng_jobs" "synthetic-fallback-integration")"
if [[ "$ng_conclusion" == "success" && "$ng_priv" == "success" && "$ng_fallback" == "skipped" ]]; then
  add_criterion "nightly_privileged_pattern" "pass" "run=${ng_id} privileged=${ng_priv} fallback=${ng_fallback}"
else
  add_criterion "nightly_privileged_pattern" "fail" "run=${ng_id} privileged=${ng_priv} fallback=${ng_fallback} conclusion=${ng_conclusion}"
fi

sha_lock_ok=true
for sha in "$rh_head_sha" "$rc_head_sha" "$ng_head_sha"; do
  if ! starts_with_sha_lock "$sha"; then
    sha_lock_ok=false
    break
  fi
done
if [[ "$sha_lock_ok" == true ]]; then
  add_criterion "baseline_sha_lock_active" "pass" "sha_lock=${SHA_LOCK}"
else
  add_criterion "baseline_sha_lock_active" "fail" "sha_lock=${SHA_LOCK} runner-health=${rh_head_sha} runner-canary=${rc_head_sha} nightly=${ng_head_sha}"
fi

evaluate_weekly_pattern() {
  local prefix="$1"
  local name="$2"
  local expect_a="$3"
  local expect_b="$4"
  local job_a="$5"
  local job_b="$6"

  local run_id run_date conclusion jobs_json
  eval "run_id=\${${prefix}_id}"
  eval "run_date=\${${prefix}_created_at}"
  eval "conclusion=\${${prefix}_conclusion}"
  eval "jobs_json=\${${prefix}_jobs}"
  run_date="${run_date:0:10}"

  if [[ "$WINDOW_REACHED" != true ]]; then
    add_criterion "$name" "pending" "window_date=${WINDOW_DATE} latest_run=${run_id:-none} latest_date=${run_date:-none}"
    return
  fi

  local c1 c2
  c1="$(job_conclusion "$jobs_json" "$job_a")"
  c2="$(job_conclusion "$jobs_json" "$job_b")"
  if [[ "$run_date" > "$WINDOW_DATE" || "$run_date" == "$WINDOW_DATE" ]] && [[ "$conclusion" == "success" && "$c1" == "$expect_a" && "$c2" == "$expect_b" ]]; then
    add_criterion "$name" "pass" "run=${run_id} ${job_a}=${c1} ${job_b}=${c2}"
  else
    add_criterion "$name" "fail" "run=${run_id} date=${run_date} conclusion=${conclusion} ${job_a}=${c1} ${job_b}=${c2}"
  fi
}

evaluate_weekly_pattern "e2e" "weekly_e2e_pattern" "success" "skipped" "evidence-e2e" "evidence-runner-required"
evaluate_weekly_pattern "kc" "weekly_kernel_pattern" "success" "success" "compat-kernel-5-15" "compat-kernel-6-8"
evaluate_weekly_pattern "wb" "weekly_benchmark_pattern" "success" "skipped" "full-benchmark-matrix" "synthetic-fallback-matrix"

overall_status="pass"
if jq -e '.[] | select(.status == "fail")' <<<"$criteria" >/dev/null; then
  overall_status="fail"
elif jq -e '.[] | select(.status == "pending")' <<<"$criteria" >/dev/null; then
  overall_status="pending"
fi

jq -n \
  --arg generated_at_utc "$NOW_UTC" \
  --arg repository "$REPO" \
  --arg sha_lock "$SHA_LOCK" \
  --arg window_date "$WINDOW_DATE" \
  --argjson window_reached "$WINDOW_REACHED" \
  --arg overall_status "$overall_status" \
  --argjson criteria "$criteria" \
  --arg rh_id "$rh_id" --arg rh_created_at "$rh_created_at" --arg rh_head_sha "$rh_head_sha" --arg rh_conclusion "$rh_conclusion" --arg rh_url "$rh_url" \
  --arg rc_id "$rc_id" --arg rc_created_at "$rc_created_at" --arg rc_head_sha "$rc_head_sha" --arg rc_conclusion "$rc_conclusion" --arg rc_url "$rc_url" \
  --arg ng_id "$ng_id" --arg ng_created_at "$ng_created_at" --arg ng_head_sha "$ng_head_sha" --arg ng_conclusion "$ng_conclusion" --arg ng_url "$ng_url" \
  --arg e2e_id "$e2e_id" --arg e2e_created_at "$e2e_created_at" --arg e2e_head_sha "$e2e_head_sha" --arg e2e_conclusion "$e2e_conclusion" --arg e2e_url "$e2e_url" \
  --arg kc_id "$kc_id" --arg kc_created_at "$kc_created_at" --arg kc_head_sha "$kc_head_sha" --arg kc_conclusion "$kc_conclusion" --arg kc_url "$kc_url" \
  --arg wb_id "$wb_id" --arg wb_created_at "$wb_created_at" --arg wb_head_sha "$wb_head_sha" --arg wb_conclusion "$wb_conclusion" --arg wb_url "$wb_url" \
  '{
    generated_at_utc: $generated_at_utc,
    repository: $repository,
    sha_lock: $sha_lock,
    window_date: $window_date,
    window_reached: $window_reached,
    overall_status: $overall_status,
    criteria: $criteria,
    runs: {
      runner_health: {run_id: $rh_id, created_at: $rh_created_at, head_sha: $rh_head_sha, conclusion: $rh_conclusion, url: $rh_url},
      runner_canary: {run_id: $rc_id, created_at: $rc_created_at, head_sha: $rc_head_sha, conclusion: $rc_conclusion, url: $rc_url},
      nightly: {run_id: $ng_id, created_at: $ng_created_at, head_sha: $ng_head_sha, conclusion: $ng_conclusion, url: $ng_url},
      e2e_evidence: {run_id: $e2e_id, created_at: $e2e_created_at, head_sha: $e2e_head_sha, conclusion: $e2e_conclusion, url: $e2e_url},
      kernel_compatibility: {run_id: $kc_id, created_at: $kc_created_at, head_sha: $kc_head_sha, conclusion: $kc_conclusion, url: $kc_url},
      weekly_benchmark: {run_id: $wb_id, created_at: $wb_created_at, head_sha: $wb_head_sha, conclusion: $wb_conclusion, url: $wb_url}
    }
  }' > "$OUT_JSON"

{
  echo "# Stability Week Check"
  echo
  echo "- generated_at_utc: \`$NOW_UTC\`"
  echo "- repository: \`$REPO\`"
  echo "- sha_lock: \`$SHA_LOCK\`"
  echo "- window_date: \`$WINDOW_DATE\` (reached: \`$WINDOW_REACHED\`)"
  echo "- overall_status: \`$overall_status\`"
  echo
  echo "## Criteria"
  jq -r '.criteria[] | "- \(.name): **\(.status)** — \(.detail)"' "$OUT_JSON"
  echo
  echo "## Latest Scheduled Runs"
  jq -r '.runs | to_entries[] | "- \(.key): run=\(.value.run_id) conclusion=\(.value.conclusion) sha=\(.value.head_sha[0:7]) [link](\(.value.url))"' "$OUT_JSON"
} > "$OUT_MD"

echo "wrote $OUT_JSON"
echo "wrote $OUT_MD"

if [[ "$STRICT" == true && "$overall_status" != "pass" ]]; then
  echo "stability week check failed in strict mode (overall_status=$overall_status)" >&2
  exit 1
fi
