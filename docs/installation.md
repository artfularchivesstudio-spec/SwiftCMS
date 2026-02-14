# Installation Guide

## Prerequisites
- Swift 5.10+
- Docker (for PostgreSQL, Redis, Meilisearch)
- macOS 13+ or Ubuntu 24.04

## Quick Start
```bash
git clone https://github.com/swiftcms/swiftcms.git
cd swiftcms
cp .env.example .env
make setup   # starts Docker services + builds
make run     # starts the server
```

## Manual Setup
1. Install Swift 5.10 from swift.org
2. Start services: `docker compose up -d postgres redis meilisearch`
3. Build: `swift build`
4. Run migrations: `swift run App migrate --yes`
5. Start: `swift run App serve --hostname 0.0.0.0 --port 8080`

## Configuration
All configuration via environment variables. See `.env.example` for all options.

Key variables:
- `DATABASE_URL` — PostgreSQL connection string
- `REDIS_URL` — Redis connection string  
- `AUTH_PROVIDER` — `auth0`, `firebase`, or `local`
- `STORAGE_PROVIDER` — `local` or `s3`
