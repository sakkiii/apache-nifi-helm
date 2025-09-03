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
Common NiFi keystore environment variables
*/}}
{{- define "nifi.keystoreEnvironment" -}}
- name: KEYSTORE_PATH
  value: {{ include "nifi.tlsPath" . }}/keystore.p12
- name: KEYSTORE_TYPE
  value: PKCS12
- name: KEYSTORE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ default "certificate-keystore-password" .Values.global.tls.certificate.keystorePasswordSecretRef.name | quote }}
      key: {{ .Values.global.tls.certificate.keystorePasswordSecretRef.key | quote }}
- name: TRUSTSTORE_PATH
  value: {{ include "nifi.tlsPath" . }}/truststore.p12
- name: TRUSTSTORE_TYPE
  value: PKCS12
- name: TRUSTSTORE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ default "certificate-keystore-password" .Values.global.tls.certificate.keystorePasswordSecretRef.name | quote }}
      key: {{ .Values.global.tls.certificate.keystorePasswordSecretRef.key | quote }}
{{- end }}

{{/*
Common NiFi OIDC environment variables
*/}}
{{- define "nifi.oidcEnvironment" -}}
{{- with .Values.global.oidc -}}
- name: AUTH
  value: oidc
- name: NIFI_SECURITY_USER_OIDC_DISCOVERY_URL
  value: {{ .oidc_url | quote }}
- name: NIFI_SECURITY_USER_OIDC_CLIENT_ID
  value: {{ .client_id | quote }}
{{- if .client_secretFrom }}
- name: NIFI_SECURITY_USER_OIDC_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .client_secretFrom.secretName | quote }}
      key: {{ .client_secretFrom.secretKey | quote }}
{{- else if .client_secret }}
- name: NIFI_SECURITY_USER_OIDC_CLIENT_SECRET
  value: {{ .client_secret | quote }}
{{- end }}
- name: NIFI_SECURITY_USER_OIDC_CLAIM_IDENTIFYING_USER
  value: {{ .claim_identifying_user | quote }}
- name: INITIAL_ADMIN_IDENTITY
  value: {{ .initial_admin_identity | quote }}
{{- end }}
{{- end }}

{{/*
Common NiFi LDAP environment variables
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

{{/*
Common NiFi Basic Authentication environment variables
Uses official NiFi Single User Authentication environment variables
Automatically disabled if OIDC or LDAP is enabled
*/}}
{{- define "nifi.basicAuthEnvironment" -}}
{{- /* Only enable basic auth if both OIDC and LDAP are disabled */ -}}
{{- if and (not .Values.global.oidc.enabled) (not .Values.global.ldap.enabled) -}}
{{- with .Values.global.basic -}}
- name: AUTH
  value: single-user
- name: SINGLE_USER_CREDENTIALS_USERNAME
  value: {{ .admin_username | quote }}
- name: SINGLE_USER_CREDENTIALS_PASSWORD
  value: {{ .admin_password | quote }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Determine if NiFi version is 2.0 or higher
*/}}
{{- define "nifi.isVersion2Plus" -}}
{{- $appVersion := .Chart.AppVersion | toString -}}
{{- $version := $appVersion | replace "v" "" | replace "-SNAPSHOT" "" -}}
{{- $majorVersion := $version | splitList "." | first | int -}}
{{- if ge $majorVersion 2 -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
Determine the state management strategy to use
Returns: "kubernetes" or "zookeeper"
*/}}
{{- define "nifi.stateManagementStrategy" -}}
{{- $strategy := .Values.stateManagement.strategy | default "auto" -}}
{{- if eq $strategy "auto" -}}
  {{- if eq (include "nifi.isVersion2Plus" .) "true" -}}
kubernetes
  {{- else -}}
zookeeper
  {{- end -}}
{{- else -}}
{{ $strategy }}
{{- end -}}
{{- end }}

{{/*
Check if ZooKeeper should be enabled
*/}}
{{- define "nifi.useZooKeeper" -}}
{{- if eq (include "nifi.stateManagementStrategy" .) "zookeeper" -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
Check if Kubernetes state management should be used
*/}}
{{- define "nifi.useKubernetesStateManagement" -}}
{{- if eq (include "nifi.stateManagementStrategy" .) "kubernetes" -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
Get the namespace for Kubernetes state management resources
Always uses the release namespace for security and simplicity
*/}}
{{- define "nifi.stateManagementNamespace" -}}
{{ .Release.Namespace }}
{{- end }}

{{/*
Common cluster environment variables (used by both state management strategies)
*/}}
{{- define "nifi.clusterEnvironment" -}}
- name: NIFI_CLUSTER_NODE_PROTOCOL_MAX_THREADS
  value: {{ .Values.cluster.nodeProtocol.maxThreads | quote }}
{{- end }}

{{/*
Kubernetes state management environment variables
*/}}
{{- define "nifi.kubernetesStateEnvironment" -}}
- name: NIFI_CLUSTER_LEADER_ELECTION_IMPLEMENTATION
  value: KubernetesLeaderElectionManager
- name: NIFI_CLUSTER_LEADER_ELECTION_KUBERNETES_LEASE_PREFIX
  value: {{ .Values.stateManagement.kubernetes.leasePrefix | quote }}
- name: NIFI_CLUSTER_LEADER_ELECTION_KUBERNETES_LEASE_NAMESPACE
  value: {{ include "nifi.stateManagementNamespace" . | quote }}
- name: NIFI_STATE_MANAGEMENT_PROVIDER_CLUSTER
  value: kubernetes-provider
- name: NIFI_STATE_MANAGEMENT_KUBERNETES_CONFIG_MAP_NAME_PREFIX
  value: {{ .Values.stateManagement.kubernetes.statePrefix | quote }}
- name: NIFI_STATE_MANAGEMENT_KUBERNETES_CONFIG_MAP_NAMESPACE
  value: {{ include "nifi.stateManagementNamespace" . | quote }}
{{- end }}

{{/*
ZooKeeper state management environment variables
*/}}
{{- define "nifi.zookeeperStateEnvironment" -}}
{{- if .Values.zookeeper.enabled }}
- name: NIFI_ZK_CONNECT_STRING
  value: "{{ .Release.Name }}-zookeeper:{{ .Values.zookeeper.external.port | default 2181 }}"
{{- else }}
- name: NIFI_ZK_CONNECT_STRING
  value: "{{ .Values.zookeeper.external.url }}"
{{- end }}
- name: NIFI_ZK_ROOT_NODE
  value: {{ .Values.zookeeper.rootNode | default "/nifi" | quote }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "nifi.serviceAccountName" -}}
{{- if .Values.global.serviceAccount.name }}
{{- .Values.global.serviceAccount.name }}
{{- else }}
{{- include "nifi.fullname" . }}
{{- end }}
{{- end }}