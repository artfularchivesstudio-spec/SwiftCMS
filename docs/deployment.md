# Deployment Guide

## Docker (Recommended)
```bash
docker compose up -d
```
The docker-compose.yml includes PostgreSQL 16, Redis 7, and Meilisearch.

## Kubernetes
```bash
kubectl apply -f k8s/
```
Includes: Deployment (2 replicas), Service (ClusterIP), HPA (70% CPU, max 10),
ConfigMap, and Secret templates.

### Health Checks
- `/healthz` — liveness probe (always 200)
- `/ready` — readiness probe (checks DB + Redis)
- `/startup` — startup probe (200 once boot completes)

### Resource Limits
- Request: 256Mi memory, 250m CPU
- Limit: 512Mi memory, 500m CPU

## Environment Variables
See `.env.example` for all configuration options.
Critical for production: DATABASE_URL, REDIS_URL, JWT_SECRET, AUTH_PROVIDER.
