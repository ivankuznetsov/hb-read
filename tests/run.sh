#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cli="$root/skills/badgerpeek/scripts/badgerpeek"
test_count=0

pass() {
  test_count=$((test_count + 1))
  printf 'ok %d - %s\n' "$test_count" "$1"
}

fail() {
  printf 'not ok %d - %s\n' "$((test_count + 1))" "$1" >&2
  exit 1
}

expect_status() {
  expected=$1
  shift
  set +e
  "$@" >/dev/null 2>/dev/null
  actual=$?
  set -e
  if [[ "$actual" -ne "$expected" ]]; then
    "$@" || true
    fail "expected status $expected, got $actual: $*"
  fi
}

run_cli_with_api() {
  local token=$1 api_url=$2
  shift 2
  HONEYBADGER_PERSONAL_AUTH_TOKEN="$token" \
    HONEYBADGER_AUTH_TOKEN='' \
    HONEYBADGER_API_URL="$api_url" \
    HONEYBADGER_ENDPOINT='' \
    "$cli" "$@"
}

[[ -x "$cli" ]] || fail "CLI exists and is executable"
bash -n "$cli"
pass "CLI has valid Bash syntax"

python3 "$root/tests/validate_skill.py" >/dev/null
pass "portable Agent Skill metadata is valid"

[[ $("$cli" version) == "badgerpeek 1.1.0" ]] || fail "version output"
[[ $(env PATH=/nonexistent /bin/bash "$cli" version) == "badgerpeek 1.1.0" ]] || fail "version without API dependencies"
"$cli" help | grep -q "Read Honeybadger errors without MCP or Docker."
pass "help and version work"

expect_status 64 run_cli_with_api "" "" projects
expect_status 64 "$cli" faults 1 --limit 26
expect_status 64 "$cli" faults 1 --created-after yesterday
expect_status 64 run_cli_with_api test-token http://example.com projects
expect_status 64 run_cli_with_api test-token http://localhost:@example.com projects
pass "invalid credentials, limits, timestamps, and URLs are rejected"

state_dir=$(mktemp -d)
server_pid=""
cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf -- "$state_dir"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

python3 "$root/tests/mock_server.py" "$state_dir/port" &
server_pid=$!
attempt=0
while [[ ! -s "$state_dir/port" && "$attempt" -lt 100 ]]; do
  if ! kill -0 "$server_pid" >/dev/null 2>&1; then
    wait "$server_pid" || true
    fail "mock server exited before becoming ready"
  fi
  sleep 0.1
  attempt=$((attempt + 1))
done
[[ -s "$state_dir/port" ]] || fail "mock server started"
read -r port <"$state_dir/port"
api_url="http://127.0.0.1:$port"

projects=$(HONEYBADGER_PERSONAL_AUTH_TOKEN=test-token HONEYBADGER_API_URL="$api_url" "$cli" --compact projects --account-id 7)
[[ $(jq -r '.results[0].token' <<<"$projects") == "[REDACTED]" ]] || fail "project token redacted"
[[ $(jq -r '.results[0].nested.api_key' <<<"$projects") == "[REDACTED]" ]] || fail "nested API key redacted"
[[ $(jq -r '.results[0].nested.cookie' <<<"$projects") == "[REDACTED]" ]] || fail "nested cookie redacted"
! grep -qE 'project-token|nested-key|session' <<<"$projects" || fail "sensitive values absent"
pass "projects are fetched and recursively redacted"

fallback_projects=$(HONEYBADGER_PERSONAL_AUTH_TOKEN='' HONEYBADGER_API_URL='' HONEYBADGER_AUTH_TOKEN=test-token HONEYBADGER_ENDPOINT="$api_url" "$cli" --compact projects)
[[ $(jq -r '.results[0].id' <<<"$fallback_projects") == "1" ]] || fail "fallback auth and endpoint variables"
pass "official fallback environment variables work"

faults=$(HONEYBADGER_PERSONAL_AUTH_TOKEN=test-token HONEYBADGER_API_URL="$api_url" "$cli" --compact faults 1 --query Timeout --order frequent --limit 3 --page 2 --occurred-after 1700000000)
[[ $(jq -r '.results[0].id' <<<"$faults") == "2" ]] || fail "fault list response"
[[ $(jq -r '.results[0].secret' <<<"$faults") == "[REDACTED]" ]] || fail "fault secret redacted"
pass "fault filters are encoded and fetched"

fault=$(HONEYBADGER_PERSONAL_AUTH_TOKEN=test-token HONEYBADGER_API_URL="$api_url" "$cli" --compact fault 1 2)
[[ $(jq -r '.password' <<<"$fault") == "[REDACTED]" ]] || fail "fault password redacted"

notices=$(HONEYBADGER_PERSONAL_AUTH_TOKEN=test-token HONEYBADGER_API_URL="$api_url" "$cli" --compact notices 1 2 --limit 2)
[[ $(jq -r '.results | length' <<<"$notices") == "2" ]] || fail "notice count"
[[ $(jq -r '.results[0].context.authorization' <<<"$notices") == "[REDACTED]" ]] || fail "notice authorization redacted"
pass "fault details and notices are fetched and redacted"

error_file="$state_dir/error"
set +e
HONEYBADGER_PERSONAL_AUTH_TOKEN=test-token HONEYBADGER_API_URL="$api_url" "$cli" faults 999 >"$state_dir/output" 2>"$error_file"
error_status=$?
set -e
[[ "$error_status" -eq 69 ]] || fail "HTTP error status"
grep -q "Honeybadger returned HTTP 404" "$error_file" || fail "HTTP status is reported"
grep -q '"token": "\[REDACTED\]"' "$error_file" || fail "error token is redacted"
! grep -q "error-token" "$error_file" || fail "error token value absent"
pass "API errors are safe and actionable"

if grep -q 'local -n' "$cli"; then
  fail "CLI avoids Bash 4-only namerefs"
fi
pass "CLI remains compatible with macOS Bash 3.2"

install_root="$state_dir/install"
mkdir -p "$install_root/home" "$install_root/prefix"
CODEX_HOME='' HOME="$install_root/home" "$root/install.sh" --agent all --prefix "$install_root/prefix"
[[ -x "$install_root/prefix/bin/badgerpeek" ]] || fail "installed CLI"
[[ -f "$install_root/home/.codex/skills/badgerpeek/SKILL.md" ]] || fail "installed Codex skill"
[[ -f "$install_root/home/.claude/skills/badgerpeek/SKILL.md" ]] || fail "installed Claude skill"
[[ -f "$install_root/home/.pi/agent/skills/badgerpeek/SKILL.md" ]] || fail "installed Pi skill"
[[ $("$install_root/prefix/bin/badgerpeek" version) == "badgerpeek 1.1.0" ]] || fail "installed CLI runs"
run_installer_with_test_home() {
  CODEX_HOME='' HOME="$install_root/home" "$root/install.sh" --agent all --prefix "$install_root/prefix"
}
expect_status 1 run_installer_with_test_home
pass "installer supports every agent and refuses accidental overwrite"

printf '1..%d\n' "$test_count"
