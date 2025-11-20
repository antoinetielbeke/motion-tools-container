# Motion Tools Container

Container images for [Antragsgruen](https://github.com/CatoTH/antragsgruen/) - a comprehensive platform for managing motions, amendments, and proposals in democratic organizations.

## Overview

This project provides production-ready, Kubernetes-optimized container images for Antragsgruen with a split architecture:

- **PHP-FPM Container**: Handles application logic using PHP 8.3 on Alpine Linux
- **NGINX Container**: Serves static content and proxies to PHP-FPM with OpenTelemetry support

### Key Features

- **Split Architecture**: PHP and web server in separate containers for independent scaling
- **Multi-Architecture**: Supports both `linux/amd64` and `linux/arm64`
- **Kubernetes-Ready**: Designed for Kubernetes but works with Docker Compose
- **Configurable**: PHP settings, NGINX configuration, and application config via ConfigMaps
- **SMTP Support**: Full Symfony Mailer integration with flexible SMTP configuration
- **Observability**: Built-in health checks and OpenTelemetry support in NGINX
- **Security**: Non-root containers, minimal attack surface, security scanning in CI

## Architecture

### C4 System Context Diagram

```mermaid
C4Context
    title System Context Diagram for Motion Tools (Antragsgruen)

    Person(user, "User", "Member of organization using motion management system")
    Person(admin, "Administrator", "Manages consultations and system settings")

    System(motionTools, "Motion Tools", "Manages motions, amendments, proposals, and voting in democratic organizations")

    System_Ext(database, "MariaDB Database", "Stores motions, users, votes, and application data")
    System_Ext(redis, "Redis Cache", "Caching layer for sessions and application data")
    System_Ext(smtp, "SMTP Server", "Sends email notifications and updates")
    System_Ext(storage, "Persistent Storage", "Stores uploaded files and generated assets")

    Rel(user, motionTools, "Views and submits motions, votes", "HTTPS")
    Rel(admin, motionTools, "Configures and manages", "HTTPS")

    Rel(motionTools, database, "Reads/Writes data", "MySQL Protocol")
    Rel(motionTools, redis, "Caches data", "Redis Protocol")
    Rel(motionTools, smtp, "Sends emails", "SMTP/TLS")
    Rel(motionTools, storage, "Stores files", "File System")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="2")
```

### C4 Container Diagram

```mermaid
C4Container
    title Container Diagram for Motion Tools

    Person(user, "User", "Organization member")

    Container_Boundary(k8s, "Kubernetes Cluster") {
        Container(nginx, "NGINX", "nginx:1.29-alpine3.22-otel", "Serves static content, proxies PHP requests, OpenTelemetry tracing")
        Container(phpfpm, "PHP-FPM", "php:8.3-fpm-alpine", "Antragsgruen application logic, motion processing, Symfony Mailer")
        ContainerDb(redis, "Redis", "redis:7-alpine", "Session storage and application cache")
    }

    System_Ext(database, "MariaDB", "Persistent database")
    System_Ext(smtp, "SMTP Server", "Email delivery")
    System_Ext(storage, "Persistent Volumes", "File storage")

    Rel(user, nginx, "Views motions, submits proposals", "HTTPS")
    Rel(nginx, phpfpm, "Forwards PHP requests", "FastCGI on port 9000")
    Rel(phpfpm, database, "Queries data", "MySQL Protocol")
    Rel(phpfpm, redis, "Caches data, stores sessions", "Redis Protocol")
    Rel(phpfpm, smtp, "Sends email notifications", "SMTP/TLS")
    Rel(phpfpm, storage, "Reads/writes files", "Volume Mount")
    Rel(nginx, storage, "Serves static assets", "Volume Mount (read-only)")

    UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="1")
```

### C4 Deployment Diagram

```mermaid
C4Deployment
    title Deployment Diagram for Motion Tools on Kubernetes

    Deployment_Node(k8s, "Kubernetes Cluster", "Cloud Provider") {
        Deployment_Node(ingress, "Ingress Controller", "NGINX Ingress") {
            Container(ingressCtrl, "Ingress", "Handles TLS termination, routing")
        }

        Deployment_Node(nginxPods, "NGINX Deployment", "3-20 replicas (HPA)") {
            Container(nginx1, "NGINX Pod 1", "nginx:1.29-alpine3.22-otel", "Serves static content")
            Container(nginx2, "NGINX Pod 2", "nginx:1.29-alpine3.22-otel", "Serves static content")
            Container(nginx3, "NGINX Pod N", "nginx:1.29-alpine3.22-otel", "Auto-scaled")
        }

        Deployment_Node(phpPods, "PHP-FPM Deployment", "2-10 replicas (HPA)") {
            Container(php1, "PHP-FPM Pod 1", "php:8.3-fpm-alpine", "Application logic")
            Container(php2, "PHP-FPM Pod 2", "php:8.3-fpm-alpine", "Application logic")
            Container(php3, "PHP-FPM Pod N", "php:8.3-fpm-alpine", "Auto-scaled")
        }

        Deployment_Node(data, "Data Layer") {
            ContainerDb(redis, "Redis", "redis:7-alpine", "Cache")
            ContainerDb(db, "MariaDB", "mariadb:11", "Database")
        }

        Deployment_Node(storage, "Persistent Storage") {
            Container(pvc1, "Runtime PVC", "5Gi RWO")
            Container(pvc2, "Assets PVC", "10Gi RWX")
            Container(pvc3, "Config PVC", "1Gi RWO")
        }
    }

    Deployment_Node(external, "External Services") {
        System_Ext(smtp, "SMTP Server", "Email delivery")
    }

    Rel(ingressCtrl, nginx1, "Routes traffic", "HTTP")
    Rel(ingressCtrl, nginx2, "Routes traffic", "HTTP")
    Rel(ingressCtrl, nginx3, "Routes traffic", "HTTP")

    Rel(nginx1, php1, "Proxies", "FastCGI")
    Rel(nginx2, php2, "Proxies", "FastCGI")
    Rel(nginx3, php3, "Proxies", "FastCGI")

    Rel(php1, db, "Queries")
    Rel(php2, db, "Queries")
    Rel(php3, db, "Queries")

    Rel(php1, redis, "Caches")
    Rel(php2, redis, "Caches")

    Rel(php1, smtp, "Sends email")
    Rel(php2, smtp, "Sends email")

    Rel(php1, pvc1, "Writes")
    Rel(php2, pvc2, "Writes")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="2")
```

## Quick Start

### Docker Compose

```bash
# Clone the repository
git clone https://github.com/yourusername/motion-tools-container.git
cd motion-tools-container/examples

# Copy and configure environment
cp .env.example .env
# Edit .env with your settings

# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Access the application
open http://localhost:8080
```

### Kubernetes

```bash
# Create namespace
kubectl create namespace motion-tools

# Configure secrets (edit with your values)
kubectl apply -f examples/kubernetes/secret.yaml

# Deploy using kustomize
kubectl apply -k examples/kubernetes/

# Check deployment status
kubectl get pods -n motion-tools

# Get ingress URL
kubectl get ingress -n motion-tools
```

## Container Images

### PHP-FPM Image

**Available at:**
- Docker Hub: `docker.io/yourusername/motion-tools-php`
- GitHub Container Registry: `ghcr.io/yourusername/motion-tools-php`

**Tags:**
- `latest` - Latest stable build from main branch
- `v4.12.4` - Antragsgruen version 4.12.4 (container version 1)
- `v4.12.4+2` - Antragsgruen version 4.12.4, container version 2
- `4.12` - Latest patch version of 4.12.x
- `main-sha-abc123` - Commit-specific build

**Included PHP Extensions:**
- Core: `gd`, `intl`, `pdo_mysql`, `opcache`, `zip`, `bcmath`, `exif`, `mysqli`, `xml`, `mbstring`, `fileinfo`
- Additional: `imagick` (ImageMagick support for PDFs)

**Ports:**
- `9000` - PHP-FPM

### NGINX Image

**Available at:**
- Docker Hub: `docker.io/yourusername/motion-tools-nginx`
- GitHub Container Registry: `ghcr.io/yourusername/motion-tools-nginx`

**Based on:** `nginx:1.29-alpine3.22-otel`

**Features:**
- OpenTelemetry support for distributed tracing
- Optimized for serving static content
- FastCGI proxy to PHP-FPM
- Rate limiting and security headers
- Health check endpoint at `/health`

**Ports:**
- `80` (or `8080` in Kubernetes) - HTTP

## Configuration

### Environment Variables

#### PHP Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `PHP_MEMORY_LIMIT` | `512M` | PHP memory limit |
| `PHP_UPLOAD_MAX_FILESIZE` | `32M` | Max upload file size |
| `PHP_POST_MAX_SIZE` | `40M` | Max POST data size |
| `PHP_MAX_EXECUTION_TIME` | `300` | Script execution timeout |
| `PHP_TIMEZONE` | `UTC` | PHP timezone |
| `PHP_OPCACHE_ENABLE` | `1` | Enable OPcache |
| `PHP_OPCACHE_MEMORY` | `256` | OPcache memory (MB) |

#### PHP-FPM Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `PHP_FPM_PM` | `dynamic` | Process manager type |
| `PHP_FPM_MAX_CHILDREN` | `50` | Maximum child processes |
| `PHP_FPM_START_SERVERS` | `5` | Start servers count |
| `PHP_FPM_MIN_SPARE_SERVERS` | `5` | Minimum spare servers |
| `PHP_FPM_MAX_SPARE_SERVERS` | `35` | Maximum spare servers |

#### Database Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_HOST` | - | Database hostname |
| `DB_PORT` | `3306` | Database port |
| `DB_NAME` | - | Database name |
| `DB_USER` | - | Database username |
| `DB_PASSWORD` | - | Database password |

#### SMTP Configuration (Symfony Mailer)

| Variable | Default | Description |
|----------|---------|-------------|
| `MAILER_DSN` | - | Symfony Mailer DSN (e.g., `smtp://user:pass@host:587`) |
| `SMTP_HOST` | `localhost` | SMTP server hostname |
| `SMTP_PORT` | `587` | SMTP server port |
| `SMTP_USER` | - | SMTP authentication username |
| `SMTP_PASSWORD` | - | SMTP authentication password |
| `SMTP_FROM` | - | Default FROM email address |
| `SMTP_AUTH` | `on` | Enable SMTP authentication |
| `SMTP_TLS` | `on` | Enable TLS |
| `SMTP_STARTTLS` | `on` | Enable STARTTLS |

#### NGINX Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_PORT` | `80` | Listen port |
| `NGINX_SERVER_NAME` | `_` | Server name |
| `NGINX_WORKER_PROCESSES` | `auto` | Worker processes |
| `NGINX_WORKER_CONNECTIONS` | `2048` | Worker connections |
| `NGINX_CLIENT_MAX_BODY_SIZE` | `32M` | Max request body size |
| `PHP_FPM_HOST` | `php-fpm` | PHP-FPM backend host |
| `PHP_FPM_PORT` | `9000` | PHP-FPM backend port |

### Volumes

| Path | Description | Access Mode |
|------|-------------|-------------|
| `/var/www/html/runtime` | Application runtime data, logs, cache | RWO |
| `/var/www/html/web/assets` | Generated and uploaded assets | RWX (shared) |
| `/var/www/html/config` | Application configuration (config.json) | RWO |

## Version Strategy

This project uses **double semantic versioning** in the format:

```
<antragsgruen-version>+<container-version>
```

**Examples:**
- `v4.12.4+1` - Antragsgruen 4.12.4, first container build
- `v4.12.4+2` - Antragsgruen 4.12.4, second container build (fixes/improvements)
- `v4.12.5+1` - Antragsgruen 4.12.5, first container build

**How it works:**
1. Base version tracks upstream Antragsgruen releases
2. Container version increments for fixes/improvements without Antragsgruen changes
3. Both images (PHP and NGINX) share the same version tag

## Development

### Building Locally

```bash
# Build PHP-FPM image
docker build -t motion-tools-php:local ./php-fpm

# Build NGINX image
docker build -t motion-tools-nginx:local ./nginx

# Build for multiple architectures
docker buildx build --platform linux/amd64,linux/arm64 \
  -t motion-tools-php:local ./php-fpm
```

### Testing

```bash
# Test with docker-compose
cd examples
docker-compose up -d

# Check container health
docker-compose ps

# View logs
docker-compose logs -f php-fpm
docker-compose logs -f nginx

# Run database migrations
docker-compose exec php-fpm php /var/www/html/yii migrate

# Access container shell
docker-compose exec php-fpm sh
```

## Production Considerations

### Security

1. **Use Kubernetes Secrets** for sensitive data (database passwords, SMTP credentials)
2. **Enable TLS** via Ingress with Let's Encrypt (cert-manager)
3. **Set strong passwords** for database and application
4. **Review NGINX security headers** in configuration
5. **Keep images updated** - enable Dependabot or Renovate

### Performance

1. **Scale independently** - PHP-FPM handles computation, NGINX handles traffic
2. **Use Redis** for session storage and caching
3. **Enable OPcache** (enabled by default)
4. **Configure HPA** for auto-scaling based on CPU/memory
5. **Use ReadWriteMany storage** for assets shared between pods

### Monitoring

1. **Health checks** are configured for both containers
2. **PHP-FPM status** available at `/fpm-status` (internal)
3. **NGINX health** available at `/health`
4. **OpenTelemetry** support in NGINX for distributed tracing
5. **Logs** sent to stdout/stderr for aggregation

### Backup

Ensure you backup:
- Database (MariaDB)
- Persistent volumes (runtime, assets, config)
- Configuration secrets

## Troubleshooting

### PHP-FPM not starting

```bash
# Check logs
kubectl logs -n motion-tools deployment/motion-tools-php

# Verify configuration
kubectl exec -n motion-tools deployment/motion-tools-php -- php -v
kubectl exec -n motion-tools deployment/motion-tools-php -- php -m
```

### NGINX cannot connect to PHP-FPM

```bash
# Verify service DNS
kubectl exec -n motion-tools deployment/motion-tools-nginx -- \
  nslookup motion-tools-php-service

# Check PHP-FPM port
kubectl exec -n motion-tools deployment/motion-tools-php -- \
  netstat -tuln | grep 9000
```

### Database connection issues

```bash
# Test database connectivity
kubectl exec -n motion-tools deployment/motion-tools-php -- \
  mysql -h mariadb -u antragsgruen -p

# Check configuration
kubectl get configmap motion-tools-config -n motion-tools -o yaml
```

### Email not sending

```bash
# Test msmtp configuration
kubectl exec -n motion-tools deployment/motion-tools-php -- \
  cat /etc/msmtprc

# Check SMTP secrets
kubectl get secret motion-tools-smtp-secret -n motion-tools -o yaml

# Test email sending
kubectl exec -n motion-tools deployment/motion-tools-php -- \
  echo "Test" | msmtp -a default test@example.com
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Antragsgruen is licensed under the AGPL-3.0 license.

## Acknowledgments

- [Antragsgruen](https://github.com/CatoTH/antragsgruen/) by Tobias Hössl
- [PHP Official Images](https://hub.docker.com/_/php)
- [NGINX Official Images](https://hub.docker.com/_/nginx)

## Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/motion-tools-container/issues)
- **Antragsgruen Documentation**: https://github.com/CatoTH/antragsgruen/
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/motion-tools-container/discussions)
