{{/* Expand the name of the chart. */}}
{{- define "chrony.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Expand the name of the chart. */}}
{{- define "chrony.port" -}}
{{- default "123" .Values.service.port }}
{{- end }}

{{/* Expand the name of the chart. */}}
{{- define "chrony.namespace" -}}
{{- default .Chart.Name .Values.namespace | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Create a default fully qualified app name. We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec). If release name contains chart name it will be used as a full name. */}}
{{- define "chrony.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/* Create chart name and version as used by the chart label. */}}
{{- define "chrony.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Common labels */}}
{{- define "chrony.labels" -}}
helm.sh/chart: {{ include "chrony.chart" . }}
{{ include "chrony.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Selector labels */}}
{{- define "chrony.selectorLabels" -}}
type: daemon
tier: infrastructure
cluster: pentapis
app.kubernetes.io/name: {{ include "chrony.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Create the log Level to use for chrony */}}
{{- define "chrony.logLevel" -}}
{{- if .Values.opts.logLevel }}
{{- .Values.opts.logLevel }}
{{- else }}
0
{{- end }}
{{- end }}

{{/* Create the securityContext */}}
{{- define "chrony.securityContext" -}}
{{ include "chrony.seccompProfile" . }}
{{ include "chrony.appArmorProfile" . }}
runAsUser: {{- default 1000 .Values.securityContext.runAsUser }}
runAsGroup: {{- default 3000 .Values.securityContext.runAsGroup }}
fsGroup: {{- default 2000 .Values.securityContext.fsGroup }}
supplementalGroups: {{- default (list 4000) .Values.securityContext.supplementalGroups }}
supplementalGroupsPolicy: {{- default "strict" .Values.securityContext.supplementalGroupsPolicy }}
{{- end }}

{{/* Create the seccompProfile */}}
{{- define "chrony.seccompProfile" -}}
{{- if .Values.securityContext.seccompProfile }}
{{- .Values.securityContext.seccompProfile }}
{{- else }}
seccompProfile:
    type: Unconfined
{{- end }}
{{- end }}

{{/* Create the appArmorProfile */}}
{{- define "chrony.appArmorProfile" -}}
{{- if .Values.securityContext.appArmorProfile }}
{{- .Values.securityContext.appArmorProfile }}
{{- else }}
appArmorProfile:
    type: Localhost
    localhostProfile: k8s-apparmor-example-deny-write
{{- end }}
{{- end }}
