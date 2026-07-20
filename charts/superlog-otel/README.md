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
| Chart Version | `0.1.1` |

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

- A node agent (`DaemonSet`) collects stdout/stderr from every pod on Porter's
  Application nodes, host CPU, memory, disk and network metrics, and kubelet
  pod/container metrics.
- One cluster collector (`Deployment`) collects Kubernetes events and workload
  state metrics across the cluster and accepts application OTLP traces, logs,
  and metrics on ports `4317` and `4318`.
- Both roles attach Kubernetes workload metadata and export directly to the
  selected Superlog project.

Application traces require an OpenTelemetry SDK or zero-code instrumentation in
the application. The collector receives and enriches traces; it cannot create
traces from an uninstrumented application.

The chart does not export complete Kubernetes object specifications. Those
objects may contain sensitive environment values and create unnecessary
telemetry volume. Kubernetes events, resource identity, and operational metrics
are collected instead.

## Porter node groups

By default, the node agent targets Porter's **Application** node group. This
keeps a one-click install schedulable on a fresh Porter cluster, where the fixed
System nodes may already be at their pod limit. Kubernetes events and workload
state metrics remain cluster-wide because the cluster collector is not a
DaemonSet.

To collect container logs and node metrics from every Linux node, replace the
default in Porter's **Values YAML** with the following. Use this only when every
node has capacity for one additional pod; otherwise Porter can remain in the
**Deploying** state while an agent waits to schedule.

```yaml
collectors:
  agent:
    porterNodeGroups: []
```

## Existing monitoring

[Porter's built-in application metrics](https://docs.porter.run/applications/observability/monitoring)
use a separate monitoring pipeline. It may collect some of the same Kubernetes
and kubelet metrics for Porter's dashboards, but it does not send application
container logs, metrics, or traces to Superlog. The default chart can therefore
be installed alongside Porter's built-in monitoring.

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
