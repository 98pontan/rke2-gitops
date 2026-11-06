{{ include "app.fullname" . }} deployed to namespace {{ .Release.Namespace }}.
{{- if .Values.vault.enabled }}

Vault (role "{{ .Values.vault.role }}"): secrets are injected as files under /vault/secrets/
{{- range .Values.vault.secrets }}
  /vault/secrets/{{ .name }}  <-  {{ include "app.vaultPath" (dict "root" $ "secret" .) }}
{{- end }}
{{- if not .Values.vault.secrets }}
  (no secrets configured: set vault.secrets)
{{- end }}
The Vault policy only allows reading {{ default "secret" .Values.vault.mount }}/data/{{ .Release.Namespace }}/*
{{- end }}
{{- if .Values.ingress.enabled }}

Ingress:
{{- range .Values.ingress.hosts }}
  https://{{ .host }}
{{- end }}
{{- else if .Values.service.enabled }}

Port-forward:
  kubectl -n {{ .Release.Namespace }} port-forward svc/{{ include "app.fullname" . }} 8080:{{ .Values.service.port }}
{{- end }}
