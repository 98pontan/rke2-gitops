{{/* Chart name */}}
{{- define "app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Fully qualified resource name */}}
{{- define "app.fullname" -}}
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

{{/* Chart label */}}
{{- define "app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Selector labels */}}
{{- define "app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Common labels */}}
{{- define "app.labels" -}}
helm.sh/chart: {{ include "app.chart" . }}
{{ include "app.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Service account name */}}
{{- define "app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/* Image reference: repository@digest, or repository:tag (tag defaults to appVersion) */}}
{{- define "app.image" -}}
{{- if .Values.image.digest }}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest }}
{{- else }}
{{- printf "%s:%s" .Values.image.repository (default .Chart.AppVersion .Values.image.tag) }}
{{- end }}
{{- end }}

{{/*
Resolve a Vault secret path. Takes a dict with "root" (the chart root context) and "secret".
  - starts with "<mount>/"  -> used as is
  - otherwise               -> <mount>/data/<namespace>/<path>   (path defaults to the secret name)
*/}}
{{- define "app.vaultPath" -}}
{{- $mount := default "secret" .root.Values.vault.mount -}}
{{- $path := default .secret.name .secret.path -}}
{{- if hasPrefix (printf "%s/" $mount) $path -}}
{{- $path -}}
{{- else -}}
{{- printf "%s/data/%s/%s" $mount .root.Release.Namespace $path -}}
{{- end -}}
{{- end }}

{{/*
Pod annotations: generated Vault injector annotations, overridden by vault.annotations,
overridden by podAnnotations. Renders YAML, or nothing when there are none.
*/}}
{{- define "app.podAnnotations" -}}
{{- $a := dict -}}
{{- if .Values.vault.enabled -}}
{{- $_ := set $a "vault.hashicorp.com/agent-inject" "true" -}}
{{- $_ := set $a "vault.hashicorp.com/role" .Values.vault.role -}}
{{- if .Values.vault.prePopulateOnly -}}
{{- $_ := set $a "vault.hashicorp.com/agent-pre-populate-only" "true" -}}
{{- end -}}
{{- if .Values.vault.initFirst -}}
{{- $_ := set $a "vault.hashicorp.com/agent-init-first" "true" -}}
{{- end -}}
{{- range .Values.vault.secrets -}}
{{- $_ := set $a (printf "vault.hashicorp.com/agent-inject-secret-%s" .name) (include "app.vaultPath" (dict "root" $ "secret" .)) -}}
{{- if .template -}}
{{- $_ := set $a (printf "vault.hashicorp.com/agent-inject-template-%s" .name) .template -}}
{{- end -}}
{{- end -}}
{{- $_ := mergeOverwrite $a (default dict .Values.vault.annotations) -}}
{{- end -}}
{{- $_ := mergeOverwrite $a (default dict .Values.podAnnotations) -}}
{{- if $a -}}
{{- toYaml $a -}}
{{- end -}}
{{- end }}

{{/* Name of the Kubernetes Secret an ExternalSecret creates. Takes a dict with "root" and "secret". */}}
{{- define "app.esoSecretName" -}}
{{- default (printf "%s-%s" (include "app.fullname" .root) .secret.name) .secret.secretName -}}
{{- end }}

{{/* envFrom entries for ESO secrets that set envFrom: true (YAML list, or nothing) */}}
{{- define "app.esoEnvFrom" -}}
{{- $l := list -}}
{{- if .Values.eso.enabled -}}
{{- range .Values.eso.secrets -}}
{{- if .envFrom -}}
{{- $l = append $l (dict "secretRef" (dict "name" (include "app.esoSecretName" (dict "root" $ "secret" .)))) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if $l -}}{{- toYaml $l -}}{{- end -}}
{{- end }}

{{/* volumeMounts for ESO secrets that set mountPath (YAML list, or nothing) */}}
{{- define "app.esoVolumeMounts" -}}
{{- $l := list -}}
{{- if .Values.eso.enabled -}}
{{- range .Values.eso.secrets -}}
{{- if .mountPath -}}
{{- $l = append $l (dict "name" (printf "eso-%s" .name) "mountPath" .mountPath "readOnly" true) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if $l -}}{{- toYaml $l -}}{{- end -}}
{{- end }}

{{/* volumes for ESO secrets that set mountPath (YAML list, or nothing) */}}
{{- define "app.esoVolumes" -}}
{{- $l := list -}}
{{- if .Values.eso.enabled -}}
{{- range .Values.eso.secrets -}}
{{- if .mountPath -}}
{{- $l = append $l (dict "name" (printf "eso-%s" .name) "secret" (dict "secretName" (include "app.esoSecretName" (dict "root" $ "secret" .)))) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if $l -}}{{- toYaml $l -}}{{- end -}}
{{- end }}

{{/* Selector labels for the bundled Postgres (must differ from the app's, or the app Service would match it) */}}
{{- define "app.postgresSelectorLabels" -}}
app.kubernetes.io/name: {{ include "app.name" . }}-postgres
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: database
{{- end }}
