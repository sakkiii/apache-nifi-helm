{{/*
Expand the name of the chart.
*/}}
{{- define "nifi.name" -}}
nifi
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "nifi.fullname" -}}
{{- $name := include "nifi.name" . }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "nifi.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "nifi.labels" -}}
helm.sh/chart: {{ include "nifi.chart" . }}
{{ include "nifi.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "nifi.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nifi.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "nifi.siteToSiteHostName" -}}
{{ printf "%s.%s" .Values.ingress.siteToSite.subDomain .Values.ingress.hostName }}
{{- end }}

{{- define "nifi.hostNodeList" -}}
{{- $ctx := . }}  # Save the context in a variable
{{- range $i := until ($ctx.Values.global.nifi.nodeCount | int) }}
- {{ printf "%s-%d.%s.%s" (include "nifi.fullname" $ctx) $i (include "nifi.fullname" $ctx) $ctx.Release.Namespace }}
{{- end }}
{{- end }}

{{- define "nifi.ingressNodeList" -}}
{{- range $i, $e := until (.Values.global.nifi.nodeCount | int) }}
{{ printf "- %s-%d.%s" (include "nifi.fullname" $) $i (include "nifi.siteToSiteHostName" $) }}
{{- end }}
{{- end }}

{{/*
NiFi Registry FQDN
*/}}
{{- define "nifi.registryUrl" -}}
{{ .Release.Name }}-{{ include "nifi-registry.fullname" . }}.{{ .Release.Namespace }}.svc
{{- end }}

{{/*
Certificate path constants
*/}}
{{- $keystoreFile := "keystore.p12" }}
{{- $truststoreFile := "truststore.p12" }}
{{- define "nifi.certPath" -}}
{{ "/opt/certmanager" }}
{{- end }}
{{- define "nifi.tlsPath" -}}
{{ "/opt/tls" }}
{{- end }}

{{/*
Certificate subject alternative names
*/}}
{{- define "nifi.certificateSubjectAltNames" }}
{{- $fullName := (include "nifi.fullname" . ) }}
{{- $namespace := .Release.Namespace }}
{{- printf "${POD_NAME}.%s.%s,%s-http.%s" $fullName $namespace $fullName $namespace }}
{{- with .Values.tls.subjectAltNames }}
{{- printf ",%s" (join "," .) }}
{{- end }}
{{- end }}

{{/*
Returns whether `.Values.extraPorts` contains one or more entries with either `nodePort` or `loadBalancerPort`
*/}}
{{- define "nifi.hasExternalPorts" -}}
{{- $hasNodePorts := false }}
{{- $hasLoadBalancerPorts := false }}
{{- range $name, $port := .Values.extraPorts }}
{{- if and (hasKey $port "nodePort") (gt (int $port.nodePort) 0) }}
{{- $hasNodePorts = true }}
{{- else if and (hasKey $port "loadBalancerPort") (gt (int $port.loadBalancerPort) 0) }}
{{- $hasLoadBalancerPorts = true }}
{{- end }}
{{- end }}
{{- if (or $hasNodePorts $hasLoadBalancerPorts) }}true{{ end }}
{{- end }}

{{/*
Common NiFi/Registry keystore environment variables
*/}}
{{- define "nifi.keystoreEnvironment" -}}
- name: KEYSTORE_PATH
  value: {{ include "nifi.tlsPath" . }}/keystore.p12
- name: KEYSTORE_TYPE
  value: PKCS12
- name: KEYSTORE_PASSWORD
  valueFrom:
    secretKeyRef:
      {{- toYaml .Values.global.tls.certificate.keystorePasswordSecretRef | nindent 6 }}
- name: TRUSTSTORE_PATH
  value: {{ include "nifi.tlsPath" . }}/truststore.p12
- name: TRUSTSTORE_TYPE
  value: PKCS12
- name: TRUSTSTORE_PASSWORD
  valueFrom:
    secretKeyRef:
      {{- toYaml .Values.global.tls.certificate.keystorePasswordSecretRef | nindent 6 }}
{{- end }}

{{/*
Comon NiFi/Registry LDAP environment variables
*/}}
{{- define "nifi.ldapEnvironment" -}}
{{- with .Values.global.ldap -}}
- name: AUTH
  value: ldap
- name: LDAP_URL
  value: {{ .url | quote }}
- name: LDAP_TLS_PROTOCOL
  value: {{ .tlsProtocol | quote }}
- name: LDAP_AUTHENTICATION_STRATEGY
  value: {{ .authenticationStrategy | quote }}
- name: LDAP_IDENTITY_STRATEGY
  value: {{ .identityStrategy | quote }}
- name: INITIAL_ADMIN_IDENTITY
  value: {{ .initialAdminIdentity | quote }}
- name: LDAP_MANAGER_DN
  value: {{ .manager.distinguishedName | quote }}
- name: LDAP_MANAGER_PASSWORD
  valueFrom:
    secretKeyRef:
      {{- toYaml .manager.passwordSecretRef | nindent 6 }}
- name: LDAP_USER_SEARCH_BASE
  value: {{ .userSearchBase | quote }}
- name: LDAP_USER_SEARCH_FILTER
  value: {{ .userSearchFilter | quote }}
{{- if or (eq .authenticationStrategy "LDAPS") (eq .authenticationStrategy "START_TLS") }}
- name: LDAP_TLS_KEYSTORE
  value: {{ include "nifi.tlsPath" $ }}/keystore.p12
- name: LDAP_TLS_KEYSTORE_TYPE
  value: PKCS12
- name: LDAP_TLS_KEYSTORE_PASSWORD
  valueFrom:
    secretKeyRef:
      {{- toYaml $.Values.global.tls.certificate.keystorePasswordSecretRef | nindent 6 }}
- name: LDAP_TLS_TRUSTSTORE
  value: {{ include "nifi.tlsPath" $ }}/truststore.p12
- name: LDAP_TLS_TRUSTSTORE_TYPE
  value: PKCS12
- name: LDAP_TLS_TRUSTSTORE_PASSWORD
  valueFrom:
    secretKeyRef:
      {{- toYaml $.Values.global.tls.certificate.keystorePasswordSecretRef | nindent 6 }}
{{- end }}
{{- end }}
{{- end }}
