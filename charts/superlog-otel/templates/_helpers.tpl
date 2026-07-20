{{- define "superlog-otel.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "superlog-otel.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- if contains (include "superlog-otel.name" .) .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "superlog-otel.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "superlog-otel.authSecretName" -}}
{{- if .Values.global.superlog.existingSecret.name }}
{{- .Values.global.superlog.existingSecret.name }}
{{- else }}
{{- printf "%s-superlog-otel-auth" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}


{{- define "superlog-otel.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "superlog-otel.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "superlog-otel.selectorLabels" -}}
app.kubernetes.io/name: {{ include "superlog-otel.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "superlog-otel.componentName" -}}
{{- printf "%s-%s" (include "superlog-otel.fullname" .root) .component | trunc 63 | trimSuffix "-" }}
{{- end }}
