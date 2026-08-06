{{- define "ollama.name" -}}
{{- default .Chart.Name .Values.nameOverride }}
{{- end -}}

{{- define "ollama.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- printf "%s" .Values.fullnameOverride }}
{{- else }}
{{- printf "%s-%s" (include "ollama.name" .) .Release.Name }}
{{- end }}
{{- end -}}

{{- define "ollama.labels" -}}
app.kubernetes.io/name: {{ include "ollama.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
