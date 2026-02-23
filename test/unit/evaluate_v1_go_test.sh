#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVAL_SCRIPT="${ROOT_DIR}/scripts/ci/evaluate_v1_go.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

date_utc_offset_day() {
  local offset="$1"
  if date -u -d "-${offset} day" +%F >/dev/null 2>&1; then
    date -u -d "-${offset} day" +%F
  else
    date -u -v-"${offset}"d +%F
  fi
}

mk_case_dirs() {
  local case_dir="$1"
  mkdir -p "${case_dir}/jobs"
}

write_daily_success_runs() {
  local out_file="$1"
  local id_start="$2"
  local sha="$3"
  : > "${out_file}.ndjson"
  for offset in 0 1 2 3 4 5 6; do
    local day
    day="$(date_utc_offset_day "$offset")"
    local id
    id=$((id_start + offset))
    cat >> "${out_file}.ndjson" <<EOF
{"id":${id},"event":"schedule","status":"completed","conclusion":"success","created_at":"${day}T08:00:00Z","head_sha":"${sha}"}
EOF
  done
  jq -s '.' "${out_file}.ndjson" > "$out_file"
}

write_two_scheduled_success_runs() {
  local out_file="$1"
  local id_a="$2"
  local id_b="$3"
  local sha="$4"
  local day0 day1
  day0="$(date_utc_offset_day 0)"
  day1="$(date_utc_offset_day 1)"
  cat > "$out_file" <<EOF
[
  {"id":${id_a},"event":"schedule","status":"completed","conclusion":"success","created_at":"${day0}T06:00:00Z","head_sha":"${sha}"},
  {"id":${id_b},"event":"schedule","status":"completed","conclusion":"success","created_at":"${day1}T06:00:00Z","head_sha":"${sha}"}
]
EOF
}

write_job_fixture() {
  local out_file="$1"
  local job_a="$2"
  local concl_a="$3"
  local job_b="$4"
  local concl_b="$5"
  cat > "$out_file" <<EOF
[
  {"name":"${job_a}","conclusion":"${concl_a}"},
  {"name":"${job_b}","conclusion":"${concl_b}"}
]
EOF
}

setup_all_pass_fixture() {
  local case_dir="$1"
  local sha="$2"
  mk_case_dirs "$case_dir"

  write_daily_success_runs "${case_dir}/runner-health.json" 1000 "$sha"
  write_daily_success_runs "${case_dir}/runner-canary.json" 2000 "$sha"
  write_two_scheduled_success_runs "${case_dir}/nightly-ebpf-integration.json" 3001 3002 "$sha"
  write_two_scheduled_success_runs "${case_dir}/weekly-benchmark.json" 4001 4002 "$sha"
  write_two_scheduled_success_runs "${case_dir}/kernel-compatibility-matrix.json" 5001 5002 "$sha"
  write_two_scheduled_success_runs "${case_dir}/e2e-evidence-report.json" 6001 6002 "$sha"

  write_job_fixture "${case_dir}/jobs/3001.json" "privileged-kind-integration" "success" "synthetic-fallback-integration" "skipped"
  write_job_fixture "${case_dir}/jobs/3002.json" "privileged-kind-integration" "success" "synthetic-fallback-integration" "skipped"

  write_job_fixture "${case_dir}/jobs/4001.json" "full-benchmark-matrix" "success" "synthetic-fallback-matrix" "skipped"
  write_job_fixture "${case_dir}/jobs/4002.json" "full-benchmark-matrix" "success" "synthetic-fallback-matrix" "skipped"

  write_job_fixture "${case_dir}/jobs/5001.json" "compat-kernel-5-15" "success" "compat-kernel-6-8" "success"
  write_job_fixture "${case_dir}/jobs/5002.json" "compat-kernel-5-15" "success" "compat-kernel-6-8" "success"

  write_job_fixture "${case_dir}/jobs/6001.json" "evidence-e2e" "success" "evidence-runner-required" "skipped"
  write_job_fixture "${case_dir}/jobs/6002.json" "evidence-e2e" "success" "evidence-runner-required" "skipped"
}

run_eval() {
  local fixture_dir="$1"
  local out_dir="$2"
  local sha="$3"
  mkdir -p "$out_dir"
  "${EVAL_SCRIPT}" \
    --since "2026-02-01T00:00:00Z" \
    --repo "example/repo" \
    --sha-lock "$sha" \
    --fixtures-dir "$fixture_dir" \
    --out-json "${out_dir}/status.json" \
    --out-md "${out_dir}/status.md"
}

SHA_LOCK="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

CASE_PASS="${TMP_DIR}/all-pass"
setup_all_pass_fixture "$CASE_PASS" "$SHA_LOCK"
if ! run_eval "$CASE_PASS" "${TMP_DIR}/out-pass" "$SHA_LOCK"; then
  echo "FAIL: all-pass fixture should return success"
  exit 1
fi
if [[ "$(jq -r '.overall_status' "${TMP_DIR}/out-pass/status.json")" != "pass" ]]; then
  echo "FAIL: all-pass fixture should have overall_status=pass"
  exit 1
fi

CASE_MANUAL="${TMP_DIR}/mixed-manual"
cp -R "$CASE_PASS" "$CASE_MANUAL"
day0="$(date_utc_offset_day 0)"
day1="$(date_utc_offset_day 1)"
cat > "${CASE_MANUAL}/weekly-benchmark.json" <<EOF
[
  {"id":4101,"event":"workflow_dispatch","status":"completed","conclusion":"success","created_at":"${day0}T06:00:00Z","head_sha":"${SHA_LOCK}"},
  {"id":4102,"event":"workflow_dispatch","status":"completed","conclusion":"success","created_at":"${day1}T06:00:00Z","head_sha":"${SHA_LOCK}"}
]
EOF
set +e
run_eval "$CASE_MANUAL" "${TMP_DIR}/out-manual" "$SHA_LOCK"
rc=$?
set -e
if [[ "$rc" -eq 0 ]]; then
  echo "FAIL: mixed-manual fixture should fail because scheduled weekly runs are missing"
  exit 1
fi
if ! jq -e '.failure_reasons[] | contains("weekly_privileged_2x")' "${TMP_DIR}/out-manual/status.json" >/dev/null; then
  echo "FAIL: mixed-manual fixture should fail weekly_privileged_2x criterion"
  exit 1
fi

CASE_FALLBACK="${TMP_DIR}/fallback-violation"
cp -R "$CASE_PASS" "$CASE_FALLBACK"
write_job_fixture "${CASE_FALLBACK}/jobs/4001.json" "full-benchmark-matrix" "success" "synthetic-fallback-matrix" "success"
set +e
run_eval "$CASE_FALLBACK" "${TMP_DIR}/out-fallback" "$SHA_LOCK"
rc=$?
set -e
if [[ "$rc" -eq 0 ]]; then
  echo "FAIL: fallback-violation fixture should fail"
  exit 1
fi
if ! jq -e '.failure_reasons[] | contains("no_scheduled_fallback_usage")' "${TMP_DIR}/out-fallback/status.json" >/dev/null; then
  echo "FAIL: fallback-violation fixture should fail no_scheduled_fallback_usage criterion"
  exit 1
fi

echo "PASS: evaluate_v1_go fixtures"
