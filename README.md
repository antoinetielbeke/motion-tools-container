# Motion Tools Container

Container images for [Antragsgruen](https://github.com/CatoTH/antragsgruen/) - a platform for managing motions, amendments, and proposals in democratic organizations.

Based on **v4.17-volt** with native 12-factor environment variable support.

## Architecture

- **PHP-FPM Container**: PHP 8.4 on Alpine, handles application logic
- **NGINX Container**: Serves static content, proxies to PHP-FPM (OpenTelemetry support)

## Quick Start

```bash
cd examples
cp .env.example .env

# Generate required RANDOM_SEED
echo "RANDOM_SEED=$(openssl rand -base64 32)" >> .env

# Set a database password
echo "DB_PASSWORD=your-secure-password" >> .env

# Start services
docker-compose up -d

# Access at http://localhost:8080
```

## Environment Variables

Configuration is handled natively by Antragsgruen via environment variables. See [upstream documentation](https://github.com/CatoTH/antragsgruen/blob/main/docs/environment-variables.md).

### Required

| Variable | Description |
|----------|-------------|
| `RANDOM_SEED` | Security seed. Generate with: `openssl rand -base64 32` |
| `DB_HOST` | Database hostname |
| `DB_NAME` | Database name |
| `DB_USER` | Database username |
| `DB_PASSWORD` | Database password |

### Application

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_DOMAIN` | - | Domain (e.g., `motion.tools`) |
| `APP_PROTOCOL` | `https` | `http` or `https` |
| `MULTISITE_MODE` | `false` | Enable multisite mode |
| `BASE_LANGUAGE` | `en` | Language (`en`, `de`, `fr`, etc.) |

### Redis (Optional)

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_HOST` | - | Redis hostname (enables caching if set) |
| `REDIS_PORT` | `6379` | Redis port |
| `REDIS_PASSWORD` | - | Redis password |

### Mail

| Variable | Description |
|----------|-------------|
| `MAILER_DSN` | Symfony format: `smtp://user:pass@host:587` |

Or individual settings: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`

## Kubernetes

```bash
kubectl create namespace motion-tools

# Edit secrets first!
kubectl apply -f examples/kubernetes/secret.yaml
kubectl apply -k examples/kubernetes/
```

## Building

```bash
# PHP-FPM
docker build -t motion-tools-php:local ./php-fpm

# NGINX
docker build -t motion-tools-nginx:local ./nginx
```

## License

MIT. Antragsgruen is AGPL-3.0.
