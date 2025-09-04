# Apache NiFi Helm Chart

[![Publish Helm Chart](https://github.com/sakkiii/apache-nifi-helm/actions/workflows/publish-chart.yml/badge.svg)](https://github.com/sakkiii/apache-nifi-helm/actions/workflows/publish-chart.yml)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Helm Version](https://img.shields.io/badge/Helm-v3+-green.svg)](https://helm.sh/)
[![Kubernetes Version](https://img.shields.io/badge/Kubernetes-v1.21+-blue.svg)](https://kubernetes.io/)

A production-ready Helm chart for deploying Apache NiFi on Kubernetes with enterprise-grade features including multiple authentication methods, high availability, monitoring, and advanced security configurations.

## ✨ Key Features

- 🔐 **Multiple Authentication Methods**: Basic Auth, LDAP, and OIDC with automatic fallback
- 🏗️ **High Availability**: Multi-node clustering with StatefulSets and Pod Disruption Budgets
- 🚀 **Smart State Management**: Kubernetes-native state management for NiFi 2.0+ with ZooKeeper fallback
- 🔒 **Enterprise Security**: TLS/SSL, cert-manager integration, and secure secret management
- 📊 **Monitoring & Observability**: Prometheus metrics, Grafana dashboards, and custom exporters
- 💾 **Flexible Storage**: Multiple persistent volume configurations for different repositories
- 🚀 **Production Ready**: Resource management, scaling, backup strategies, and upgrade support
- 🌐 **Advanced Networking**: Site-to-Site communication, ingress routing, and load balancing

## 📋 Table of Contents

- [Quick Start](#-quick-start)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [State Management](#-state-management)
- [Authentication](#-authentication)
- [Configuration](#-configuration)
- [Advanced Configuration](#-advanced-configuration)
- [Storage Configuration](#-storage-configuration)
- [Monitoring & Observability](#-monitoring--observability)
- [Security](#-security)
- [Networking](#-networking)
- [Scaling & High Availability](#-scaling--high-availability)
- [Backup & Restore](#-backup--restore)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)

## 🚀 Quick Start

### Basic Deployment (Single Node)
```bash
# Add the Helm repository
helm repo add apache-nifi-helm https://sakkiii.github.io/apache-nifi-helm
helm repo update

# Install with default basic authentication
helm install my-nifi apache-nifi-helm/nifi

# Access NiFi (after port-forward)
kubectl port-forward svc/my-nifi-http 8443:8443
# Open https://localhost:8443/nifi
# Default credentials: admin / your32characterpasswordhere123
```

### Production Deployment (Multi-Node with OIDC)
```bash
# Install with OIDC authentication and 3 nodes
helm install my-nifi apache-nifi-helm/nifi \
  --set global.nifi.nodeCount=3 \
  --set global.oidc.enabled=true \
  --set global.oidc.oidc_url="https://your-oidc-provider/.well-known/openid-configuration" \
  --set global.oidc.client_id="nifi-client" \
  --set global.oidc.client_secret="your-secret" \
  --set global.oidc.initial_admin_identity="admin@company.com" \
  --set ingress.enabled=true \
  --set ingress.hostName="nifi.company.com"
```

## 📦 Prerequisites

- **Helm**: 3.x or higher
- **Kubernetes**: 1.21+ with RBAC enabled
- **Storage**: Persistent storage provisioner (e.g., AWS EBS, Azure Disk, GCP PD)
- **Cert-manager**: For automatic TLS certificate management (recommended)
- **Ingress Controller**: For external access (e.g., NGINX, AWS ALB, Traefik)

### Optional Dependencies
- **Prometheus**: For metrics collection
- **Grafana**: For visualization dashboards
- **External DNS**: For automatic DNS management

## 📥 Installation

### 1. Add Helm Repository
```bash
helm repo add apache-nifi-helm https://sakkiii.github.io/apache-nifi-helm
helm repo update
```

### 2. Create Namespace (Optional)
```bash
kubectl create namespace nifi
```

### 3. Install Chart
```bash
# Basic installation
helm install my-nifi apache-nifi-helm/nifi -n nifi

# With custom values file
helm install my-nifi apache-nifi-helm/nifi -f my-values.yaml -n nifi

# With inline overrides
helm install my-nifi apache-nifi-helm/nifi \
  --set global.nifi.nodeCount=3 \
  --set ingress.enabled=true \
  --set ingress.hostName="nifi.example.com" \
  -n nifi
```

### 4. Upgrade
```bash
helm upgrade my-nifi apache-nifi-helm/nifi -f my-values.yaml -n nifi
```

### 5. Uninstall
```bash
helm uninstall my-nifi -n nifi
```

## 🚀 State Management

This chart supports **both ZooKeeper and Kubernetes-native state management** with automatic version detection and backward compatibility.

### 📋 **Available Strategies**

| Strategy | NiFi Version | Description |
|----------|--------------|-------------|
| `auto` | All | **Recommended** - Automatically choose based on NiFi version |
| `kubernetes` | 2.0+ | Native Kubernetes state management (ConfigMaps + Leases) |
| `zookeeper` | All | Traditional ZooKeeper-based clustering |

### 🎯 **Quick Configuration**

```yaml
# values.yaml - Automatic strategy (recommended)
stateManagement:
  strategy: "auto"  # Kubernetes for NiFi 2.0+, ZooKeeper for older versions
```

```yaml
# values.yaml - Force Kubernetes state management (NiFi 2.0+)
stateManagement:
  strategy: "kubernetes"
  kubernetes:
    leasePrefix: "nifi-lease"
    statePrefix: "nifi-state"
    # Note: Always uses release namespace
```

```yaml
# values.yaml - Force ZooKeeper state management
stateManagement:
  strategy: "zookeeper"
zookeeper:
  enabled: true
  replicaCount: 3
```

### 📚 **Detailed Documentation**

For comprehensive state management documentation, examples, and migration guides, see:
**[📖 Kubernetes State Management Guide](./KUBERNETES_STATE_MANAGEMENT.md)**

## 🔐 Authentication

The chart supports **three authentication methods** with automatic priority-based selection:

### Priority Order
1. **OIDC** (highest priority) - if `global.oidc.enabled: true`
2. **LDAP** (second priority) - if OIDC disabled and `global.ldap.enabled: true`
3. **Basic Auth** (default fallback) - if both OIDC and LDAP disabled

### Basic Authentication (Default)
**Automatically enabled** when no other authentication method is configured.

```yaml
global:
  nifi:
    nodeCount: 1  # Basic auth only supports single-node
  basic:
    admin_username: "admin"
    admin_password: "your32characterpasswordhere123"  # Min 12 chars
```

**⚠️ Important**: Basic authentication only supports single-node deployment (`nodeCount: 1`).

### OIDC Authentication (Recommended for Production)
```yaml
global:
  nifi:
    nodeCount: 3  # Clustering supported
  oidc:
    enabled: true
    oidc_url: "https://auth.company.com/.well-known/openid-configuration"
    client_id: "nifi-client"
    client_secret: "your-client-secret"
    claim_identifying_user: "preferred_username"
    initial_admin_identity: "admin@company.com"
```

### LDAP Authentication
```yaml
global:
  nifi:
    nodeCount: 3  # Clustering supported
  ldap:
    enabled: true
    url: "ldaps://ldap.company.com:636"
    tlsProtocol: "TLSv1.2"
    authenticationStrategy: "LDAPS"
    identityStrategy: "USE_USERNAME"
    initialAdminIdentity: "CN=NiFi Admin,OU=Users,DC=company,DC=com"
    manager:
      distinguishedName: "CN=Service Account,OU=Services,DC=company,DC=com"
      passwordSecretRef:
        name: "ldap-manager-secret"
        key: "password"
    userSearchBase: "OU=Users,DC=company,DC=com"
    userSearchFilter: "sAMAccountName={0}"
```

### Authentication Examples
See the [`examples/`](examples/) directory for complete configuration files:
- [`examples/values-auth-basic.yaml`](examples/values-auth-basic.yaml) - Basic authentication
- [`examples/values-auth-oidc.yaml`](examples/values-auth-oidc.yaml) - OIDC authentication  
- [`examples/values-auth-ldap.yaml`](examples/values-auth-ldap.yaml) - LDAP authentication

## ⚙️ Configuration

### Core Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.nifi.nodeCount` | Number of NiFi nodes (1 for basic auth, 1+ for OIDC/LDAP) | `1` |
| `image.repository` | NiFi Docker image repository | `apache/nifi` |
| `image.tag` | NiFi Docker image tag | `""` (uses appVersion) |
| `ingress.enabled` | Enable ingress for external access | `true` |
| `ingress.hostName` | Hostname for NiFi web interface | `example.com` |
| `zookeeper.enabled` | Enable embedded Zookeeper (required for clustering) | `true` |

### Authentication Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.basic.admin_username` | Basic auth admin username | `admin` |
| `global.basic.admin_password` | Basic auth admin password (min 12 chars) | `your32characterpasswordhere123` |
| `global.oidc.enabled` | Enable OIDC authentication | `false` |
| `global.oidc.oidc_url` | OIDC discovery URL | `""` |
| `global.oidc.client_id` | OIDC client ID | `""` |
| `global.oidc.client_secret` | OIDC client secret | `""` |
| `global.ldap.enabled` | Enable LDAP authentication | `false` |
| `global.ldap.url` | LDAP server URL | `""` |

### Resource Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources.requests.cpu` | CPU request per pod | `500m` |
| `resources.requests.memory` | Memory request per pod | `2Gi` |
| `jvmHeap.min` | JVM minimum heap size | `512m` |
| `jvmHeap.max` | JVM maximum heap size | `1g` |

### Storage Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `volumeClaims.config.size` | Configuration volume size | `5Gi` |
| `volumeClaims.state.size` | State volume size | `10Gi` |
| `volumeClaims.content.size` | Content repository size | `15Gi` |
| `volumeClaims.provenance.size` | Provenance repository size | `10Gi` |
| `volumeClaims.flowfile.size` | FlowFile repository size | `10Gi` |

## 🔧 Advanced Configuration

### Multi-Environment Setup

#### Development Environment
```yaml
# values-dev.yaml
global:
  nifi:
    nodeCount: 1
  basic:
    admin_username: "admin"
    admin_password: "devpassword123"

resources:
  requests:
    cpu: 200m
    memory: 1Gi

jvmHeap:
  min: 256m
  max: 512m

volumeClaims:
  config:
    size: 1Gi
  state:
    size: 2Gi
  content:
    size: 5Gi
```

#### Production Environment
```yaml
# values-prod.yaml
global:
  nifi:
    nodeCount: 3
  oidc:
    enabled: true
    oidc_url: "https://auth.company.com/.well-known/openid-configuration"
    client_id: "nifi-prod"
    client_secret: "prod-secret"
    initial_admin_identity: "nifi-admin@company.com"

resources:
  requests:
    cpu: 2
    memory: 8Gi
  limits:
    cpu: 4
    memory: 16Gi

jvmHeap:
  min: 4g
  max: 6g

pdb:
  enabled: true
  maxUnavailable: 1

metrics:
  serviceMonitor:
    enabled: true
    interval: 30s

nifiMonitor:
  enabled: true
  replicas: 2
```

### Custom NiFi Properties
```yaml
extraConfig:
  nifiProperties:
    nifi.cluster.node.connection.timeout: "10 secs"
    nifi.cluster.node.read.timeout: "10 secs"
    nifi.web.request.timeout: "60 secs"
    nifi.administrative.yield.duration: "30 sec"
```

### External Zookeeper
```yaml
zookeeper:
  enabled: false
  url: "zk-cluster.company.com"
  port: 2181
  rootNode: "/nifi"
```

### Custom Storage Classes
```yaml
volumeClaims:
  config:
    storageClass: "fast-ssd"
    size: "10Gi"
  content:
    storageClass: "bulk-storage"
    size: "100Gi"
  provenance:
    storageClass: "archive-storage"
    size: "500Gi"
```

## 💾 Storage Configuration

### Storage Architecture
NiFi uses multiple repositories for different types of data:

- **Config**: Configuration files and user settings
- **State**: Component state and cluster coordination
- **FlowFile**: Active data flow metadata
- **Content**: Actual data content
- **Provenance**: Data lineage and audit information
- **Logs**: Application and audit logs

### Storage Classes
```yaml
volumeClaims:
  config:
    storageClass: "gp3"          # Fast access for configs
    size: "5Gi"
  state:
    storageClass: "gp3"          # Fast access for state
    size: "10Gi"
  flowfile:
    storageClass: "gp3"          # Fast access for active flows
    size: "20Gi"
  content:
    storageClass: "gp3"          # Balanced performance/cost
    size: "100Gi"
  provenance:
    storageClass: "sc1"          # Cold storage for archives
    size: "500Gi"
  logs:
    storageClass: "gp3"
    size: "10Gi"
```

### Backup Strategy
```yaml
# Enable log persistence for backup
persistence:
  logs:
    volumeMount:
      name: "logs"
      subPath: "nifi-logs"

# Custom backup paths
extraTakeOwnershipPaths:
  - "/backup/flows"
  - "/backup/templates"

extraVolumeMounts:
  - mountPath: /backup
    name: backup-volume

extraVolumes:
  - name: backup-volume
    persistentVolumeClaim:
      claimName: nifi-backup-pvc
```

## 📊 Monitoring & Observability

### Prometheus Integration
```yaml
metrics:
  serviceMonitor:
    enabled: true
    interval: 30s
    scrapeTimeout: 10s
    labels:
      monitoring: "prometheus"

nifiMonitor:
  enabled: true
  image:
    repository: ghcr.io/sakkiii/nifi_exporter
    tag: latest
  replicas: 2
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
```

### Custom Metrics Ingress
```yaml
metrics:
  ingress:
    enabled: true
    https: true
    basePath: /metrics
    requireClientCertificate: true
```

### Grafana Dashboards
The chart includes pre-built Grafana dashboards in the [`grafana/`](grafana/) directory:
- `nifi-cluster-health.json` - Cluster health and performance
- `zookeeper.json` - Zookeeper metrics and coordination

### Log Management
```yaml
logging:
  levels:
    org.apache.nifi.web.security: ERROR
    org.apache.nifi.processors: WARN
    org.apache.nifi.processors.standard.LogAttribute: WARN
  totalSizeCap:
    APP_FILE: 10GB
    USER_FILE: 5GB

# Optional: Filebeat sidecar for log shipping
filebeat:
  enabled: true
  image:
    repository: docker.elastic.co/beats/filebeat
    tag: "8.8.0"
  output:
    type: elasticsearch
    parameters:
      hosts: ["elasticsearch.logging.svc.cluster.local:9200"]
      index: "nifi-logs-%{+yyyy.MM.dd}"
```

## 🔒 Security

### TLS/SSL Configuration
```yaml
global:
  tls:
    certificate:
      duration: 8760h      # 1 year
      renewBefore: 168h    # 1 week
      keystorePasswordSecretRef:
        name: "nifi-keystore-password"
        key: "password"

# Additional subject alternative names
tls:
  subjectAltNames:
    - "nifi.internal"
    - "*.nifi.company.com"
```

### Secret Management
```yaml
global:
  encryption:
    sensitivePropertiesKey:
      secretRef:
        name: "nifi-sensitive-key"    # Auto-generated if not exists
        key: "sensitivekey"

  # Repository encryption (optional)
  encryption:
    repository:
      enabled: true
      keyId: 1
      secretRef:
        name: "nifi-repo-encryption"
        key: "repository.p12"
```

### Security Context
```yaml
securityContext:
  runAsUser: 1000
  runAsGroup: 1000
  runAsNonRoot: true

# Custom umask
umask: "0002"
```

## 🌐 Networking

### Ingress Configuration
```yaml
ingress:
  enabled: true
  ingressClassName: "nginx"  # or "alb", "traefik"
  hostName: "nifi.company.com"
  siteToSite:
    subDomain: "s2s"  # Creates s2s.company.com
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

### AWS Application Load Balancer
```yaml
ingress:
  enabled: true
  ingressClassName: "alb"
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/backend-protocol: HTTPS
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:region:account:certificate/cert-id"
```

### Site-to-Site Communication
```yaml
# Automatic configuration for S2S routing
# - Cluster-local communication via service
# - External communication via ingress
# - Proper hostname resolution and port mapping
```

### Extra Ports and Services
```yaml
extraPorts:
  datafeed:
    containerPort: 9443
    protocol: TCP
    nodePort: 30443        # For NodePort service
    loadBalancerPort: 9443 # For LoadBalancer service
    ingress:
      path: /datafeed
      pathType: Exact

service:
  external:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
```

## 📈 Scaling & High Availability

### Horizontal Scaling
```yaml
global:
  nifi:
    nodeCount: 5  # Scale to 5 nodes

# Pod Disruption Budget
pdb:
  enabled: true
  maxUnavailable: 1  # Allow only 1 pod down during disruptions
```

### Resource Scaling
```yaml
resources:
  requests:
    cpu: 2
    memory: 8Gi
  limits:
    cpu: 4
    memory: 16Gi

jvmHeap:
  min: 4g
  max: 6g
```

### Anti-Affinity Rules
```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: app.kubernetes.io/name
          operator: In
          values:
          - nifi
      topologyKey: kubernetes.io/hostname
```

### Topology Spread Constraints
```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: nifi
```

## 💾 Backup & Restore

### Automated Backup Strategy
```yaml
# 1. Use storage provider snapshots
# Example for AWS EBS
volumeClaims:
  config:
    storageClass: "gp3"
    annotations:
      volume.beta.kubernetes.io/storage-class: "gp3"
      # Add backup annotations for automated snapshots

# 2. NiFi Registry integration
extraConfig:
  nifiProperties:
    nifi.registry.url: "https://nifi-registry.company.com"
    nifi.registry.bucket.default: "production-flows"
```

### Manual Backup Process
```bash
# 1. Create consistent snapshot
kubectl exec -it nifi-0 -- /opt/nifi/nifi-current/bin/nifi.sh stop

# 2. Backup persistent volumes
kubectl get pvc -l app.kubernetes.io/name=nifi

# 3. Export flow definitions
kubectl exec -it nifi-0 -- curl -k https://localhost:8443/nifi-api/flow/download

# 4. Restart NiFi
kubectl exec -it nifi-0 -- /opt/nifi/nifi-current/bin/nifi.sh start
```

### Disaster Recovery
```yaml
# Multi-region deployment
global:
  nifi:
    nodeCount: 3

# Cross-region replication
extraConfig:
  nifiProperties:
    nifi.remote.input.host: "nifi-dr.company.com"
    nifi.remote.input.port: "10443"
    nifi.remote.input.secure: "true"
```

## 🔍 Troubleshooting

### Common Issues

#### 1. Authentication Problems
```bash
# Check authentication configuration
kubectl logs nifi-0 | grep -i auth

# Verify secrets exist
kubectl get secrets | grep nifi

# Check OIDC/LDAP connectivity
kubectl exec -it nifi-0 -- curl -k https://auth.company.com/.well-known/openid-configuration
```

#### 2. Clustering Issues
```bash
# Check Zookeeper connectivity
kubectl exec -it nifi-0 -- nc -zv nifi-zookeeper 2181

# Verify cluster status
kubectl exec -it nifi-0 -- curl -k https://localhost:8443/nifi-api/controller/cluster

# Check node communication
kubectl logs nifi-0 | grep -i cluster
```

#### 3. Storage Issues
```bash
# Check PVC status
kubectl get pvc -l app.kubernetes.io/name=nifi

# Verify permissions
kubectl exec -it nifi-0 -- ls -la /opt/nifi/nifi-current/

# Check disk space
kubectl exec -it nifi-0 -- df -h
```

#### 4. Performance Issues
```bash
# Check resource usage
kubectl top pods -l app.kubernetes.io/name=nifi

# Monitor JVM metrics
kubectl exec -it nifi-0 -- jstat -gc $(pgrep java)

# Check NiFi system diagnostics
kubectl exec -it nifi-0 -- curl -k https://localhost:8443/nifi-api/system-diagnostics
```

### Debug Mode
```yaml
# Enable debug startup
debugStartup: true

# Increase log levels
logging:
  levels:
    org.apache.nifi: DEBUG
    org.apache.nifi.web.security: DEBUG
```

### Health Checks
```bash
# Check pod readiness
kubectl get pods -l app.kubernetes.io/name=nifi

# Test NiFi API
kubectl exec -it nifi-0 -- curl -k https://localhost:8443/nifi-api/system-diagnostics

# Verify ingress
curl -k https://nifi.company.com/nifi-api/system-diagnostics
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup
```bash
# Clone the repository
git clone https://github.com/sakkiii/apache-nifi-helm.git
cd apache-nifi-helm

# Test the chart
helm lint .
helm template test-release . -f examples/values-auth-oidc.yaml

# Run tests
helm test my-nifi
```

### Reporting Issues
Please use [GitHub Issues](https://github.com/sakkiii/apache-nifi-helm/issues) to report bugs or request features. Include:
- Chart version
- Helm version  
- Kubernetes version
- Values file (sanitized)
- Error logs

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Apache NiFi](https://nifi.apache.org/) community
- [Kubernetes](https://kubernetes.io/) project
- [Helm](https://helm.sh/) maintainers
- All [contributors](https://github.com/sakkiii/apache-nifi-helm/graphs/contributors)

---

**⭐ If this chart helped you, please consider giving it a star on GitHub!**