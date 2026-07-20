#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
chart_dir="$repo_root/charts/superlog-otel"
image_repository="$(awk '/^image:/{found=1; next} found && /repository:/{print $2; exit}' "$chart_dir/values.yaml")"
image_tag="$(awk '/^image:/{found=1; next} found && /tag:/{gsub(/\"/, "", $2); print $2; exit}' "$chart_dir/values.yaml")"
collector_image="${image_repository}:${image_tag}"
validation_dir="$(mktemp -d)"
mkdir -p "$validation_dir/hostfs" "$validation_dir/storage" "$validation_dir/serviceaccount"
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$validation_dir/serviceaccount/ca.key" \
  -out "$validation_dir/serviceaccount/ca.crt" \
  -subj /CN=test-kubernetes-ca \
  -days 1 >/dev/null 2>&1
openssl rand -hex -out "$validation_dir/serviceaccount/token" 16
trap 'rm -r "$validation_dir"' EXIT

validate() {
  local config_name="$1"
  shift
  docker run --rm \
    "$@" \
    -e SUPERLOG_API_KEY=sl_public_test \
    -e SUPERLOG_ENDPOINT=https://intake.superlog.sh \
    -e SUPERLOG_CLUSTER_NAME=test-cluster \
    -v "$chart_dir/files/$config_name.yaml:/conf/relay.yaml:ro" \
    "$collector_image" validate --config=/conf/relay.yaml
}

validate agent \
  -e MY_POD_NAME=superlog-otel-agent-test \
  -e MY_POD_IP=127.0.0.1 \
  -e K8S_NODE_IP=127.0.0.1 \
  -e K8S_NODE_NAME=test-node \
  -e KUBELET_INSECURE_SKIP_VERIFY=true \
  -v "$validation_dir/hostfs:/hostfs:ro" \
  -v "$validation_dir/storage:/var/lib/otelcol" \
  -v "$validation_dir/serviceaccount:/var/run/secrets/kubernetes.io/serviceaccount:ro"

validate cluster -e MY_POD_IP=127.0.0.1

echo "collector configs passed"
