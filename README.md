# Motion Tools Container

Container images for [Antragsgruen](https://github.com/CatoTH/antragsgruen/) - a platform for managing motions, amendments, and proposals in democratic organizations.

Based on **v4.17-volt** with native 12-factor environment variable support.

## Container Images

Images are available on [GitHub Container Registry](https://github.com/antoinetielbeke?tab=packages):

```bash
# Pull specific version
docker pull ghcr.io/antoinetielbeke/motion-tools-php:v4.17.0-volt.1
docker pull ghcr.io/antoinetielbeke/motion-tools-nginx:v4.17.0-volt.1

# Pull latest
docker pull ghcr.io/antoinetielbeke/motion-tools-php:latest
docker pull ghcr.io/antoinetielbeke/motion-tools-nginx:latest
```

### Versioning

Container releases follow semantic versioning: `v{upstream}.{build}`

```
v4.17.0-volt.1
│ │   │ │   │
│ │   │ │   └── Container build number (resets on upstream bump)
│ │   │ └────── Pre-release identifier (custom branch/fork)
│ │   └──────── Patch version (added if missing)
│ └──────────── Minor version
└────────────── 'v' prefix
```

**Examples:**
- `v4.18.0.1` - Official Antragsgruen v4.18 release, first container build
- `v4.17.0-volt.1` - Custom volt branch/fork, first container build
- `v4.17.0-volt.2` - Same upstream, second container build (entrypoint fix, dependency update, etc.)

**Note:** The Antragsgruen version in Dockerfile (`ARG ANTRAGSGRUEN_VERSION=v4.17-volt`) is the upstream git tag being built. The container release tag (e.g., `v4.17.0-volt.1`) is applied when creating a GitHub release.

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

# Access at http://localhost:8080/main
# (Default path is /main, configurable via CONSULTATION_PATH env var)
```

## Environment Variables

Configuration is handled via environment variables with automatic minimal `config.json` generation. The entrypoint creates a minimal config file (single-site mode: `{"multisiteMode": false, "siteSubdomain": "std"}`, multisite mode: `{}`), while all other settings come from environment variables.

See [upstream documentation](https://github.com/CatoTH/antragsgruen/blob/main/docs/environment-variables.md) for complete reference.

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

### Single-Site Configuration

These variables only apply when `MULTISITE_MODE=false`:

| Variable | Default | Description |
|----------|---------|-------------|
| `SITE_SUBDOMAIN` | `std` | Site identifier (used in config and database) |
| `SITE_TITLE` | `Demo Site` | Site display name |
| `CONSULTATION_PATH` | `main` | URL path for consultation (access at `/main`) |
| `CONSULTATION_TITLE` | `Main Consultation` | Consultation display name |
| `CONSULTATION_TITLE_SHORT` | `Main` | Short consultation name |

### Redis (Recommended)

**Note**: Redis is included in the docker-compose setup and significantly improves performance through caching.

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

## Deployment Modes

### Single-Site Mode (Default)

```bash
MULTISITE_MODE=false
CONSULTATION_PATH=main  # Customize the URL path (default: main)
SITE_TITLE="My Organization"  # Optional: customize site name
CONSULTATION_TITLE="Annual Meeting 2026"  # Optional: customize consultation name
```

- One consultation per deployment
- Auto-creates default site and consultation on first run
- Access via: `http://your-domain/{CONSULTATION_PATH}` (default: `/main`)
- **Note**: Root URL (`/`) does not work - access consultations via their URL path
- Fully configurable via environment variables (site subdomain, titles, paths)

### Multisite Mode

```bash
MULTISITE_MODE=true
```

- Multiple sites per deployment
- No default site created - create sites via admin interface
- Access via subdomains: `http://subdomain.your-domain/consultation-path`
- Requires subdomain configuration in your DNS/proxy

## Known Limitations

This container implements environment-variable configuration for v4.17-volt. Some upstream limitations exist:

- Root URL (`/`) doesn't work in single-site mode - access via consultation path (e.g., `/main`)
- Single-site mode requires `siteSubdomain` in config.json (no env var available)
- See `UPSTREAM_FIXES_TODO.md` for detailed list of improvements needed upstream

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

## Release Process

Creating a new release:

1. **Update Antragsgruen version** (if needed):
   ```bash
   # Edit php-fpm/Dockerfile and nginx/Dockerfile
   ARG ANTRAGSGRUEN_VERSION=v4.18-volt
   ```

2. **Create and push a git tag**:
   ```bash
   # For official release (e.g., Antragsgruen v4.18)
   git tag v4.18.0.1

   # For custom branch (e.g., volt fork)
   git tag v4.17.0-volt.1

   # For container-only changes
   git tag v4.17.0-volt.2

   git push origin v4.18.0.1
   ```

3. **Automated actions**:
   - GitHub Actions builds both images with multi-arch support (amd64, arm64)
   - Images pushed to GitHub Container Registry with version tag and `latest`
   - GitHub Release created with auto-generated changelog

**When to increment:**
- New Antragsgruen version/branch → `v4.18.0.1` or `v4.18.0-volt.1`
- Container fix (entrypoint, dependencies, etc.) → increment build number (`.2`, `.3`, etc.)

## Troubleshooting

### Application shows "Error" page

**Single-site mode**: Access via consultation URL path (e.g., `/main`), not root URL `/`

**Multisite mode**: Ensure you've created a site via admin interface and are accessing via correct subdomain

### Database connection issues

Check that `DB_HOST`, `DB_NAME`, `DB_USER`, and `DB_PASSWORD` are set correctly in `.env`

### Redis not connecting

Verify `REDIS_HOST=redis` in docker-compose setup, or your Redis hostname in production

### RANDOM_SEED not set error

Generate a secure seed:
```bash
echo "RANDOM_SEED=$(openssl rand -base64 32)" >> .env
```

## License

MIT. Antragsgruen is AGPL-3.0.
