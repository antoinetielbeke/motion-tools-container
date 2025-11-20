# Motion Tools Container - Examples

This directory contains deployment examples for Motion Tools (Antragsgruen) containers.

## Directory Structure

```
examples/
├── docker-compose.yml        # Docker Compose deployment example
├── .env.example             # Environment variables template
└── kubernetes/              # Kubernetes deployment manifests
    ├── namespace.yaml       # Namespace definition
    ├── configmap.yaml       # Configuration for PHP and NGINX
    ├── secret.yaml          # Sensitive data (passwords, SMTP)
    ├── pvc.yaml            # Persistent volume claims
    ├── deployment.yaml     # Deployments for PHP and NGINX
    ├── service.yaml        # Services for internal communication
    ├── ingress.yaml        # Ingress for external access
    ├── hpa.yaml            # Horizontal Pod Autoscalers
    └── kustomization.yaml  # Kustomize configuration
```

## Docker Compose Deployment

### Quick Start

```bash
# Navigate to examples directory
cd examples

# Copy environment template
cp .env.example .env

# Edit .env with your configuration
nano .env

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Access the application
open http://localhost:8080
```

### Services Included

- **db**: MariaDB 11 database
- **redis**: Redis 7 cache
- **php-fpm**: PHP-FPM application container
- **nginx**: NGINX web server
- **mailhog**: Email testing tool (dev profile only)

### Useful Commands

```bash
# Check service status
docker-compose ps

# View logs for specific service
docker-compose logs -f php-fpm

# Execute command in container
docker-compose exec php-fpm sh

# Run database migrations
docker-compose exec php-fpm php /var/www/html/yii migrate

# Restart services
docker-compose restart

# Stop all services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

### Development Mode

To start with MailHog for email testing:

```bash
docker-compose --profile dev up -d
```

Access MailHog web UI at: http://localhost:8025

## Kubernetes Deployment

### Prerequisites

- Kubernetes cluster (1.24+)
- kubectl configured
- Storage provisioner (for PersistentVolumes)
- Ingress controller (nginx-ingress recommended)

### Quick Start with Kustomize

```bash
# Create namespace
kubectl create namespace motion-tools

# Update secrets with your values
nano kubernetes/secret.yaml

# Deploy everything
kubectl apply -k kubernetes/

# Check deployment status
kubectl get all -n motion-tools

# Watch pod startup
kubectl get pods -n motion-tools -w

# View logs
kubectl logs -n motion-tools deployment/motion-tools-php -f
```

### Manual Deployment

```bash
# Deploy in order
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/secret.yaml
kubectl apply -f kubernetes/configmap.yaml
kubectl apply -f kubernetes/pvc.yaml
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
kubectl apply -f kubernetes/ingress.yaml
kubectl apply -f kubernetes/hpa.yaml
```

### Configuration Steps

#### 1. Update Secrets

Edit `kubernetes/secret.yaml` and replace these values:

```yaml
# Database credentials
DB_ROOT_PASSWORD: "your-secure-root-password"
DB_PASSWORD: "your-secure-db-password"

# SMTP credentials
MAILER_DSN: "smtp://username:password@smtp.example.com:587"

# Application seed
RANDOM_SEED: "generate-32-character-random-string"
```

Generate secure passwords:
```bash
openssl rand -base64 32
```

#### 2. Update ConfigMap

Edit `kubernetes/configmap.yaml`:

- Update `domainPlain` and `domainSubdomain` with your domain
- Adjust PHP/NGINX settings as needed

#### 3. Configure Ingress

Edit `kubernetes/ingress.yaml`:

- Replace `motion.example.com` with your domain
- Uncomment TLS section if using HTTPS
- Adjust annotations for your ingress controller

#### 4. Storage Configuration

Edit `kubernetes/pvc.yaml`:

- Set appropriate `storageClassName` for your cluster
- Adjust storage sizes based on your needs
- Ensure storage class supports `ReadWriteMany` for assets PVC

### Useful Kubernetes Commands

```bash
# Get all resources
kubectl get all -n motion-tools

# Check pod status
kubectl get pods -n motion-tools

# View pod logs
kubectl logs -n motion-tools deployment/motion-tools-php -f
kubectl logs -n motion-tools deployment/motion-tools-nginx -f

# Execute command in pod
kubectl exec -n motion-tools deployment/motion-tools-php -- php -v

# Run migrations
kubectl exec -n motion-tools deployment/motion-tools-php -- \
  php /var/www/html/yii migrate --interactive=0

# Port forward for local testing
kubectl port-forward -n motion-tools service/motion-tools-nginx-service 8080:80

# Scale deployments manually
kubectl scale -n motion-tools deployment/motion-tools-php --replicas=5
kubectl scale -n motion-tools deployment/motion-tools-nginx --replicas=10

# Check HPA status
kubectl get hpa -n motion-tools

# Describe resource for debugging
kubectl describe pod -n motion-tools <pod-name>

# Delete all resources
kubectl delete -k kubernetes/
```

### Scaling

#### Horizontal Pod Autoscaler

HPA is configured for both PHP and NGINX:

**PHP-FPM:**
- Min: 2 replicas
- Max: 10 replicas
- Target CPU: 70%
- Target Memory: 80%

**NGINX:**
- Min: 3 replicas
- Max: 20 replicas
- Target CPU: 60%
- Target Memory: 70%

#### Manual Scaling

```bash
# Scale PHP-FPM
kubectl scale -n motion-tools deployment/motion-tools-php --replicas=5

# Scale NGINX
kubectl scale -n motion-tools deployment/motion-tools-nginx --replicas=10
```

### Monitoring

#### Check Application Health

```bash
# NGINX health endpoint
kubectl port-forward -n motion-tools service/motion-tools-nginx-service 8080:80
curl http://localhost:8080/health

# PHP-FPM status (from within cluster)
kubectl exec -n motion-tools deployment/motion-tools-nginx -- \
  curl http://motion-tools-php-service:9000/fpm-status
```

#### View Metrics

```bash
# Pod resource usage
kubectl top pods -n motion-tools

# Node resource usage
kubectl top nodes
```

### Troubleshooting

#### Pod Not Starting

```bash
# Check pod events
kubectl describe pod -n motion-tools <pod-name>

# Check logs
kubectl logs -n motion-tools <pod-name>

# Check previous logs if pod restarted
kubectl logs -n motion-tools <pod-name> --previous
```

#### Configuration Issues

```bash
# Verify ConfigMap
kubectl get configmap -n motion-tools motion-tools-config -o yaml

# Verify Secrets
kubectl get secret -n motion-tools motion-tools-db-secret -o yaml

# Test ConfigMap mounting
kubectl exec -n motion-tools deployment/motion-tools-php -- \
  cat /usr/local/etc/php/conf.d/zz-antragsgruen.ini
```

#### Database Connection Issues

```bash
# Test database connectivity
kubectl exec -n motion-tools deployment/motion-tools-php -- \
  nc -zv mariadb 3306

# Check database service
kubectl get svc -n motion-tools mariadb
```

#### Networking Issues

```bash
# Test PHP-FPM to NGINX connectivity
kubectl exec -n motion-tools deployment/motion-tools-nginx -- \
  nc -zv motion-tools-php-service 9000

# Check services
kubectl get svc -n motion-tools

# Check endpoints
kubectl get endpoints -n motion-tools
```

## Environment Variables Reference

See the main [README.md](../README.md#environment-variables) for a complete list of environment variables.

## Additional Resources

- [Main Documentation](../README.md)
- [Contributing Guide](../CONTRIBUTING.md)
- [Antragsgruen GitHub](https://github.com/CatoTH/antragsgruen/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

## Support

For issues or questions:
- GitHub Issues: https://github.com/yourusername/motion-tools-container/issues
- GitHub Discussions: https://github.com/yourusername/motion-tools-container/discussions
