#!/usr/bin/env bash
set -euo pipefail

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rendered="$(mktemp)"
trap 'rm -f "$rendered"' EXIT

fail() {
  echo "render contract failed: $*" >&2
  exit 1
}

assert_contains() {
  local needle="$1"
  grep -Fq -- "$needle" "$rendered" || fail "expected rendered chart to contain: $needle"
}

assert_not_contains() {
  local needle="$1"
  if grep -Fq -- "$needle" "$rendered"; then
    fail "expected rendered chart not to contain: $needle"
  fi
}

assert_line() {
  local line="$1"
  grep -Fxq -- "$line" "$rendered" || fail "expected rendered chart to contain line: $line"
}

assert_no_line() {
  local line="$1"
  if grep -Fxq -- "$line" "$rendered"; then
    fail "expected rendered chart not to contain line: $line"
  fi
}

assert_line_count() {
  local expected="$1"
  local line="$2"
  local actual
  actual="$(grep -Fxc -- "$line" "$rendered" || true)"
  [[ "$actual" == "$expected" ]] || fail "expected $expected '$line' lines, found $actual"
}

render() {
  helm template porter-monitoring "$chart_dir" \
    --namespace monitoring \
    --set global.superlog.apiKey=sl_public_test \
    "$@" >"$rendered"
}

helm lint "$chart_dir" \
  --set global.superlog.apiKey=sl_public_test >/dev/null

# Default install owns node collection and one cluster-wide OTLP gateway.
render
assert_line "kind: DaemonSet"
assert_line "kind: Deployment"
assert_line "kind: Service"
assert_line_count 1 "kind: DaemonSet"
assert_line_count 1 "kind: Deployment"
assert_line_count 1 "kind: Service"
assert_contains "name: otlp"
assert_contains "port: 4317"
assert_contains "name: otlp-http"
assert_contains "port: 4318"
assert_contains "filelog:"
assert_contains "      - \"/var/log/pods/*_\${env:MY_POD_NAME}_*/collector/*.log\""
assert_contains "name: MY_POD_NAME"
assert_contains "hostmetrics:"
assert_contains "kubeletstats:"
assert_contains "insecure_skip_verify: \${env:KUBELET_INSECURE_SKIP_VERIFY}"
assert_contains "name: KUBELET_INSECURE_SKIP_VERIFY"
assert_contains "k8sobjects:"
assert_contains "k8s_cluster:"
assert_contains "- persistentvolumes"
assert_contains "- persistentvolumeclaims"
assert_contains "x-api-key: \${env:SUPERLOG_API_KEY}"
assert_contains 'value: "porter-monitoring"'

# Component suffixes remain distinct even at Kubernetes' 63-character limit.
long_fullname="$(printf 'a%.0s' {1..63})"
expected_agent_name="${long_fullname:0:57}-agent"
expected_cluster_name="${long_fullname:0:55}-cluster"
render --set fullnameOverride="$long_fullname"
assert_contains "name: $expected_agent_name"
assert_contains "name: $expected_cluster_name"

# A pre-created Secret avoids writing the ingest key into the rendered release.
render \
  --set global.superlog.apiKey= \
  --set global.superlog.existingSecret.name=porter-superlog-auth \
  --set global.superlog.existingSecret.key=token
assert_no_line "kind: Secret"
assert_contains "name: porter-superlog-auth"
assert_contains 'key: "token"'

# Existing collectors can be retained without installing overlapping workloads.
render --set collectors.agent.enabled=false
assert_no_line "kind: DaemonSet"
assert_line "kind: Deployment"

render --set collectors.cluster.enabled=false
assert_line "kind: DaemonSet"
assert_no_line "kind: Deployment"
assert_no_line "kind: Service"

# The Porter guide is dashboard-only: it must not require a local CLI.
if grep -Eq '^```(bash|sh|shell)$' "$chart_dir/README.md"; then
  fail "Porter guide must not include shell command blocks"
fi
if grep -Eiq '\b(kubectl|helm (install|upgrade|repo add|template|lint))\b' "$chart_dir/README.md"; then
  fail "Porter guide must not require kubectl or Helm commands"
fi

echo "render contract passed"
