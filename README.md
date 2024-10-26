```markdown
# Apache NiFi Helm Chart

This Helm chart deploys Apache NiFi in a Kubernetes cluster, supporting a variety of configurations to meet production requirements for scalability, security, and resilience.

## Table of Contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Storage Configuration](#storage-configuration)
- [Authentication](#authentication)
- [Logging and Monitoring](#logging-and-monitoring)
- [Scaling and Auto-scaling](#scaling-and-auto-scaling)
- [Backup and Restore](#backup-and-restore)
- [Uninstallation](#uninstallation)
- [Contributing](#contributing)
- [License](#license)

## Introduction

This Helm chart installs and configures an Apache NiFi cluster on Kubernetes, allowing customization for different environments, such as development, staging, and production. It provides support for secure deployments using TLS, role-based access control, and integrates with monitoring and logging tools for enhanced observability.

## Prerequisites

- Helm 3.x
- Kubernetes 1.21+ with RBAC enabled
- [Persistent storage provisioner](https://kubernetes.io/docs/concepts/storage/) (if using persistent storage)
- [Cert-manager](https://cert-manager.io/docs/) for certificate management (optional but recommended)

## Installation

To install the chart with the release name `my-nifi`:

```bash
helm repo add nifi https://<your-helm-repo-url>
helm install my-nifi nifi/nifi -f values.yaml
```

To upgrade the release:

```bash
helm upgrade my-nifi nifi/nifi -f values.yaml
```

> **Note:** Replace `<your-helm-repo-url>` with the appropriate repository URL.

## Configuration

The following table lists the configurable parameters of the NiFi chart and their default values.

| Parameter                    | Description                                      | Default                        |
|------------------------------|--------------------------------------------------|--------------------------------|
| `image.repository`           | NiFi image repository                            | `apache/nifi`                  |
| `image.tag`                  | NiFi image tag                                   | `latest`                       |
| `replicaCount`               | Number of NiFi replicas                          | `1`                            |
| `service.type`               | Service type                                     | `ClusterIP`                    |
| `resources`                  | Pod resource requests and limits                 | `{}`                           |
| `persistence.enabled`        | Enable persistence                               | `true`                         |
| `persistence.storageClass`   | Storage class for persistence                    | `efs`                          |
| `security.enabled`           | Enable TLS/SSL security                          | `false`                        |
| `auth.ldap.enabled`          | Enable LDAP authentication                       | `false`                        |
| `auth.oidc.enabled`          | Enable OIDC authentication                       | `false`                        |
| `logging.level`              | Log verbosity level                              | `INFO`                         |
| `monitoring.prometheus`      | Enable Prometheus metrics                        | `false`                        |

These parameters can be set in your `values.yaml` file.

### Example `values.yaml`

```yaml
image:
  repository: apache/nifi
  tag: 1.16.0

replicaCount: 3

service:
  type: LoadBalancer

persistence:
  enabled: true
  storageClass: efs

security:
  enabled: true
  certManager:
    enabled: true

auth:
  ldap:
    enabled: true
    url: "ldap://ldap.example.com"
    userSearchBase: "ou=users,dc=example,dc=com"

monitoring:
  prometheus: true
```

## Storage Configuration

The chart supports different storage backends, including Amazon EFS and local persistent volumes.

- **EFS (default)**: Allows data persistence across multiple NiFi instances.
- **Local PVs**: Can be configured with custom storage classes for smaller setups.

### Using Custom Storage Class

To specify a custom storage class, modify the `persistence.storageClass` in `values.yaml`:

```yaml
persistence:
  storageClass: my-custom-storage-class
```

## Authentication

The chart supports both LDAP and OIDC authentication.

- **LDAP**: Enable LDAP by setting `auth.ldap.enabled: true` and providing `url`, `userSearchBase`, and other parameters.
- **OIDC**: Enable OIDC by setting `auth.oidc.enabled: true` and configuring client ID, secret, and issuer URL.

For example:

```yaml
auth:
  oidc:
    enabled: true
    clientId: my-client-id
    clientSecret: my-client-secret
    issuerUrl: "https://auth.example.com"
```

## Logging and Monitoring

### Log Retention and Rotation

Log retention and rotation can be configured in NiFi’s `logback.xml`. To set this up, you may mount a custom `logback.xml` file by adding an entry in `extraVolumeMounts` and `extraVolumes` in `values.yaml`.

### Prometheus Monitoring

Prometheus metrics can be enabled by setting `monitoring.prometheus: true`. This will add the necessary annotations for scraping metrics.

```yaml
monitoring:
  prometheus: true
```

## Scaling and Auto-scaling

The chart supports horizontal scaling and integrates with the Kubernetes Horizontal Pod Autoscaler (HPA).

### Configuring HPA

To enable HPA, configure resource requests/limits and set HPA parameters in `values.yaml`:

```yaml
hpa:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  cpu: 80
  memory: 512Mi
```

## Backup and Restore

Data persistence ensures NiFi state is retained across pod restarts. However, regular backups are recommended for production deployments.

### Backup

- Use your storage provider’s snapshot feature for persistent volumes.
- Use the NiFi Registry to back up flow definitions.

### Restore

To restore, re-attach the backup volume to the NiFi StatefulSet.

## Uninstallation

To uninstall the `my-nifi` release:

```bash
helm uninstall my-nifi
```

This command removes all associated Kubernetes resources created by the chart, but it does **not** delete persistent data in the storage backend.

## Contributing

Contributions are welcome! Please submit pull requests to the repository with detailed descriptions and any relevant issue numbers.

### Reporting Issues

Please use GitHub issues to report bugs or suggest enhancements. Include as much information as possible, including chart version, Helm version, Kubernetes version, and any relevant logs.

## License

This project is licensed under the Apache License 2.0.
```

This `README.md` file provides detailed instructions on using, configuring, and managing the Apache NiFi Helm chart. Each section is organized to give clear guidance to users for deploying, scaling, and securing a NiFi deployment in Kubernetes. Let me know if you need further customization or additional details on any specific section!