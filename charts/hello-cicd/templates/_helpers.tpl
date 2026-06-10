{{/*
Standard Helm helpers for hello-cicd.
Centralizes naming + labels so the chart is idiomatic. IMPORTANT: the selector
labels are kept EXACTLY as the original (app + environment) because a
Deployment's/Service's selector is immutable — changing it would break
upgrades of the already-running idev1/2/3 deployments.
*/}}

{{- define "hello-cicd.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "hello-cicd.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "hello-cicd.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common METADATA labels — recommended K8s set + the chart's env/release labels.
These are applied to metadata.labels only (safe to add/change).
*/}}
{{- define "hello-cicd.labels" -}}
helm.sh/chart: {{ include "hello-cicd.chart" . }}
app.kubernetes.io/name: {{ include "hello-cicd.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{ include "hello-cicd.selectorLabels" . }}
{{- end -}}

{{/*
SELECTOR labels — EXACTLY the original two. Immutable; never add to these.
*/}}
{{- define "hello-cicd.selectorLabels" -}}
app: {{ include "hello-cicd.name" . }}
environment: {{ .Values.env.name }}
{{- end -}}
