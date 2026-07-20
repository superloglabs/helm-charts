#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
chart_dir="$repo_root/charts/superlog-otel"
kubeconform_image="ghcr.io/yannh/kubeconform@sha256:faffaf43f95aa6425306e1ab8d6fcad72acb9049158f38e574c085ea1ec0f64e"

bash "$chart_dir/tests/render-contract.sh"
bash "$repo_root/scripts/validate-collector-configs.sh"

helm template superlog-otel "$chart_dir" \
  --namespace monitoring \
  --set global.superlog.apiKey=sl_public_test \
  | docker run --rm -i "$kubeconform_image" \
      -strict \
      -summary \
      -kubernetes-version 1.30.0

package_dir="$(mktemp -d)"
trap 'rm -r "$package_dir"' EXIT
helm package "$chart_dir" --destination "$package_dir" >/dev/null

echo "chart validation passed"

