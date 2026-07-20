# Superlog OpenTelemetry for Kubernetes

One Helm add-on that sends Kubernetes logs, metrics, events, and application
OpenTelemetry signals to [Superlog](https://superlog.sh).

## Install in Porter

In Porter, open **Add-ons → Create add-on → Helm Chart** and enter:

| Porter field | Value |
| --- | --- |
| Add-on name | `superlog-otel` |
| Helm Repository URL | `https://superloglabs.github.io/helm-charts` |
| Chart Name | `superlog-otel` |
| Chart Version | `0.1.0` |

Paste this into **Values YAML**, replacing the placeholder with the project
ingest key shown in Superlog:

```yaml
global:
  superlog:
    apiKey: sl_public_replace_me
```

Select **Deploy**. No cluster name or Kubernetes setup is required. The Porter
add-on name becomes the display name, while the collector attaches the
Kubernetes cluster UID as its stable identity.

## What is collected

The chart installs two coordinated collector roles in one Helm release:

- A node agent (`DaemonSet`) collects stdout/stderr from every pod, host CPU,
  memory, disk and network metrics, and kubelet pod/container metrics.
- One cluster collector (`Deployment`) collects Kubernetes events and workload
  state metrics and accepts application OTLP traces, logs, and metrics on ports
  `4317` and `4318`.
- Both roles attach Kubernetes workload metadata and export directly to the
  selected Superlog project.

Application traces require an OpenTelemetry SDK or zero-code instrumentation in
the application. The collector receives and enriches traces; it cannot create
traces from an uninstrumented application.

The chart does not export complete Kubernetes object specifications. Those
objects may contain sensitive environment values and create unnecessary
telemetry volume. Kubernetes events, resource identity, and operational metrics
are collected instead.

## Existing monitoring

[Porter's built-in application metrics](https://docs.porter.run/applications/observability/monitoring)
use Prometheus, so a standard Porter cluster does not have a competing
OpenTelemetry Collector. Install the default chart as shown above.

If the cluster's **Add-ons** page shows an OpenTelemetry, Datadog, New Relic,
Fluent, Promtail, or Vector add-on that already exports the same data to
Superlog, disable that add-on in Porter before deploying this chart to avoid
duplicate logs or metrics.

For clusters where an existing add-on must remain, either role can be disabled
in the same Porter **Values YAML** field:

```yaml
global:
  superlog:
    apiKey: sl_public_replace_me

collectors:
  agent:
    enabled: false
  cluster:
    enabled: true
```

Set `agent.enabled: false` when another collector owns pod logs and node/kubelet
metrics. Set `cluster.enabled: false` when another collector owns Kubernetes
events, cluster metrics, and the OTLP gateway.

## Application OTLP endpoint

Applications in the add-on namespace can use these environment values in their
Porter application settings:

```yaml
OTEL_EXPORTER_OTLP_ENDPOINT: http://superlog-otel-cluster:4318
OTEL_EXPORTER_OTLP_PROTOCOL: http/protobuf
OTEL_SERVICE_NAME: my-service
```

The chart's gateway adds the Superlog ingest key; applications do not need it.

## Security and permissions

The ingest key entered in Porter is stored in the Helm release and in a
Kubernetes Secret. It is project-scoped and permits ingestion only.

The node agent runs as root so it can read host container logs and persist
filelog checkpoints. Its log and host filesystem mounts are read-only; only its
dedicated checkpoint directory is writable. The two roles use separate service
accounts and least-privilege ClusterRoles. Neither role can read Kubernetes
Secret or ConfigMap contents.

Kubelet requests authenticate with the collector's service-account token. TLS
certificate verification is disabled by default because managed-cluster kubelet
certificates commonly omit the node host IP from their subject alternative
names. Clusters with compatible kubelet certificates can enable verification in
Porter's **Values YAML**:

```yaml
collectors:
  agent:
    kubelet:
      insecureSkipVerify: false
```

## Validation

Pull requests render every supported installation shape, lint and package the
chart, validate the Kubernetes resource schemas, and validate both collector
configurations with the pinned collector image.
