# Quickstart Guide - Motion Tools (Antragsgruen)

Get Motion Tools (Antragsgruen) running locally in under 5 minutes!

## Prerequisites

- Docker and Docker Compose installed
- 2GB of available RAM
- Ports 8080 and 8025 available

## Quick Setup

### 1. Clone and Navigate

```bash
git clone <repository-url>
cd motion-tools-container/examples
```

### 2. Create Environment File

```bash
cp .env.example .env
```

### 3. Generate Random Seed

```bash
# Generate a secure random seed
openssl rand -base64 32
```

Edit `.env` and replace `CHANGE_THIS_TO_A_RANDOM_STRING_32_CHARACTERS_LONG` with the generated value.

### 4. Start Services

```bash
# Start all services (this will build images on first run, takes 5-10 minutes)
docker compose --profile dev up -d

# Watch the logs to see initialization progress
docker compose logs -f php-fpm
```

Wait for the message: `[init-db] Database initialization complete!`

### 5. Access the Application

Open your browser and navigate to:

- **Main Application**: http://localhost:8080
- **Email Viewer (MailHog)**: http://localhost:8025

You should see the "Main Consultation" homepage!

## Default Configuration

The quickstart uses single-site mode with these defaults:

- **Mode**: Single-site (one consultation)
- **Site Name**: Demo Site
- **Consultation**: Main Consultation (path: `/main`)
- **Database**: Auto-initialized on first run
- **Email**: Captured by MailHog (check port 8025)

## Common Tasks

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f php-fpm
docker compose logs -f nginx
docker compose logs -f db
```

### Restart Services

```bash
# Restart all
docker compose restart

# Restart specific service
docker compose restart php-fpm
```

### Stop Services

```bash
# Stop all services
docker compose down

# Stop and remove all data (WARNING: deletes database!)
docker compose down -v
```

### Access Database

```bash
# MySQL CLI
docker compose exec db mysql -u antragsgruen -p antragsgruen
# Password: antragsgruen (or your DB_PASSWORD from .env)
```

### Access PHP Container

```bash
# Shell access
docker compose exec php-fpm sh

# Run Yii commands
docker compose exec php-fpm php /var/www/html/yii help
```

## Troubleshooting

### Database Already Initialized Message

If you see `[init-db] Database already initialized, skipping setup`, the database has data. To reset:

```bash
docker compose down -v  # Removes volumes
docker compose up -d
```

### Port Already in Use

If port 8080 or 8025 is taken, edit `.env`:

```bash
HTTP_PORT=9090
MAILHOG_WEB_PORT=9025
```

### Config.json Not Found

If you see `ERROR: config.json not found`, check:

1. `config.json.template` exists in `php-fpm/` directory
2. Environment variables are set in `.env`
3. Rebuild the image: `docker compose build php-fpm`

### Can't Connect to Database

Check database health:

```bash
docker compose ps db
docker compose logs db
```

Wait for: `[Note] mariadbd: ready for connections`

### Build Takes Too Long

The first build downloads and compiles Antragsgruen (5-10 minutes). Subsequent builds use cache.

## What's Next?

- **Customize**: Edit `.env` to change site name, language, etc.
- **Multisite Mode**: See [README.md](README.md#multisite-mode) for instructions
- **Production**: See [README.md](README.md#production-deployment) for production setup
- **Development**: Mount local code for development (see README.md)

## Getting Help

- Check logs: `docker compose logs -f`
- Read full documentation: [README.md](README.md)
- Check Antragsgruen docs: https://github.com/CatoTH/antragsgruen

## Clean Uninstall

```bash
# Stop containers and remove all data
docker compose down -v

# Remove images (optional)
docker rmi motion-tools-container-php-fpm
docker rmi motion-tools-container-nginx

# Remove project directory
cd ../..
rm -rf motion-tools-container
```
