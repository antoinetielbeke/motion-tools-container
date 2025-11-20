# Contributing to Motion Tools Container

Thank you for your interest in contributing to Motion Tools Container! This document provides guidelines and instructions for contributing.

## Code of Conduct

Be respectful, inclusive, and professional. We're all here to make this project better.

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](https://github.com/yourusername/motion-tools-container/issues)
2. If not, create a new issue with:
   - Clear title and description
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (OS, Kubernetes version, etc.)
   - Relevant logs or screenshots

### Suggesting Enhancements

1. Check existing issues and discussions
2. Create a new issue with:
   - Clear use case
   - Proposed solution
   - Alternative approaches considered
   - Impact on existing functionality

### Pull Requests

1. **Fork the repository**
2. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**:
   - Follow existing code style
   - Update documentation as needed
   - Add comments for complex logic
   - Test your changes locally

4. **Commit your changes**:
   ```bash
   git commit -m "Add feature: your feature description"
   ```
   - Use clear, descriptive commit messages
   - Reference issue numbers when applicable

5. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Open a Pull Request**:
   - Provide clear description of changes
   - Link related issues
   - Describe testing performed
   - Note any breaking changes

## Development Setup

### Prerequisites

- Docker 20.10+
- Docker Buildx (for multi-arch builds)
- kubectl (for Kubernetes testing)
- A local Kubernetes cluster (minikube, kind, or Docker Desktop)

### Local Development

```bash
# Clone your fork
git clone https://github.com/yourusername/motion-tools-container.git
cd motion-tools-container

# Build images locally
docker build -t motion-tools-php:dev ./php-fpm
docker build -t motion-tools-nginx:dev ./nginx

# Test with docker-compose
cd examples
cp .env.example .env
# Edit .env with test values
docker-compose up -d

# View logs
docker-compose logs -f

# Run tests
docker-compose exec php-fpm php /var/www/html/yii migrate
docker-compose exec php-fpm php -v
docker-compose exec php-fpm php -m

# Clean up
docker-compose down -v
```

### Testing Changes

#### Docker Compose Testing

```bash
cd examples
docker-compose up --build -d
docker-compose logs -f
# Test functionality
docker-compose down
```

#### Kubernetes Testing

```bash
# Build and load into local cluster
docker build -t motion-tools-php:test ./php-fpm
docker build -t motion-tools-nginx:test ./nginx

# For minikube
minikube image load motion-tools-php:test
minikube image load motion-tools-nginx:test

# For kind
kind load docker-image motion-tools-php:test
kind load docker-image motion-tools-nginx:test

# Deploy
kubectl apply -k examples/kubernetes/

# Test
kubectl get pods -n motion-tools
kubectl logs -n motion-tools deployment/motion-tools-php
kubectl port-forward -n motion-tools service/motion-tools-nginx-service 8080:80

# Clean up
kubectl delete -k examples/kubernetes/
```

## Project Structure

```
motion-tools-container/
├── php-fpm/                    # PHP-FPM container
│   ├── Dockerfile             # Multi-stage PHP build
│   ├── docker-entrypoint.sh   # Startup script
│   ├── php.ini.template       # PHP configuration template
│   ├── php-fpm.conf.template  # PHP-FPM configuration template
│   └── msmtprc.template       # SMTP configuration template
├── nginx/                      # NGINX container
│   ├── Dockerfile             # NGINX build
│   ├── docker-entrypoint.sh   # Startup script
│   ├── nginx.conf.template    # Main NGINX config
│   └── default.conf.template  # Server block config
├── .github/workflows/          # CI/CD pipelines
│   ├── build-php.yml          # PHP-FPM build workflow
│   └── build-nginx.yml        # NGINX build workflow
├── examples/                   # Deployment examples
│   ├── docker-compose.yml     # Docker Compose example
│   ├── .env.example           # Environment template
│   └── kubernetes/            # Kubernetes manifests
└── docs/                       # Additional documentation
```

## Contribution Guidelines

### Docker Images

- Use Alpine Linux for minimal image size
- Follow multi-stage build patterns
- Ensure images support both amd64 and arm64
- Include health checks
- Run as non-root user where possible
- Add clear labels and documentation

### Configuration

- Use environment variables for configuration
- Provide sensible defaults
- Support ConfigMap/Secret mounting in Kubernetes
- Document all configuration options

### Documentation

- Update README.md for user-facing changes
- Update inline comments for code changes
- Add examples for new features
- Update C4 diagrams if architecture changes

### Testing

Test your changes with:
1. Docker Compose deployment
2. Kubernetes deployment
3. Multi-architecture builds (if modifying Dockerfiles)
4. Different configuration scenarios

## Versioning

This project uses double semantic versioning:

- **Antragsgruen version** tracks upstream releases
- **Container version** increments for container-specific changes

Example: `v4.12.4+2` means Antragsgruen 4.12.4, container build 2

When contributing:
- Don't manually update version numbers
- Versions are managed through Git tags
- CI/CD automatically builds and tags images

## Release Process

Releases are automated via GitHub Actions:

1. Changes merged to `main` branch
2. Manual GitHub release created with tag (e.g., `v4.12.4+1`)
3. GitHub Actions automatically:
   - Builds multi-arch images
   - Pushes to Docker Hub and GHCR
   - Creates release artifacts

## Getting Help

- **Questions**: Use [GitHub Discussions](https://github.com/yourusername/motion-tools-container/discussions)
- **Bugs**: Open an [Issue](https://github.com/yourusername/motion-tools-container/issues)
- **Real-time**: Join our community chat (if available)

## Recognition

Contributors will be recognized in:
- GitHub contributors list
- Release notes
- Project documentation

Thank you for contributing to Motion Tools Container!
