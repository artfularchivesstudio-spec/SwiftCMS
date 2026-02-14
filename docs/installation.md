# Installation Guide

## System Requirements

SwiftCMS requires the following software and versions:

- **Swift**: 6.1+ (latest stable release)
- **PostgreSQL**: 16+ (primary database)
- **Redis**: 7+ (caching, sessions, queues, event bus)
- **Meilisearch**: 1.x (full-text search)
- **Operating System**: macOS 13+ or Ubuntu 24.04

All dependencies except Swift are managed via Docker in development.

## Installation Methods

### Method 1: Quick Start with Docker (Recommended)

This is the fastest way to get SwiftCMS running locally:

```bash
# 1. Clone the repository
git clone https://github.com/artfularchivesstudio-spec/SwiftCMS.git
cd Swift-CMS

# 2. Copy environment configuration
cp .env.example .env

# 3. Start all services and build (takes 5-10 minutes on first run)
make setup

# 4. Run migrations
swift run App migrate --yes

# 5. Seed initial data (admin user and roles)
swift run cms seed

# 6. Start the application
make run
```

The server will be available at `http://localhost:8080` with:
- Admin panel: `http://localhost:8080/admin`
- REST API: `http://localhost:8080/api/v1`
- GraphQL: `http://localhost:8080/graphql` (if enabled)
- Health check: `http://localhost:8080/healthz`

Default admin credentials from `.env.example`:
- Email: `admin@swiftcms.dev`
- Password: `admin123`

### Method 2: Manual Installation

For more control over the installation process:

#### 1. Install Swift

**On macOS:**
```bash
# Install Xcode (includes Swift)
xcode-select --install
# Or download from: https://developer.apple.com/xcode/
```

**On Ubuntu/Linux:**
```bash
# Install Swift 6.1 from swift.org
wget -q -O - https://swift.org/keys/all-keys.asc | gpg --import -
wget https://download.swift.org/swift-6.1.2-release/ubuntu2404/swift-6.1.2-RELEASE-ubuntu24.04.tar.gz
tar xzf swift-6.1.2-RELEASE-ubuntu24.04.tar.gz
sudo mv swift-6.1.2-RELEASE-ubuntu24.04 /usr/share/swift
echo "export PATH=/usr/share/swift/usr/bin:$PATH" >> ~/.bashrc
source ~/.bashrc
```

Verify installation:
```bash
swift --version
# Should show: Swift version 6.1
```

#### 2. Install Docker and Start Dependencies

```bash
# Install Docker Desktop or Docker Engine
# https://docs.docker.com/get-docker/

# Start PostgreSQL, Redis, and Meilisearch
docker compose up -d postgres redis meilisearch

# Verify services are running
docker ps
```

#### 3. Clone and Build SwiftCMS

```bash
git clone https://github.com/artfularchivesstudio-spec/SwiftCMS.git
cd Swift-CMS

# Configure environment
cp .env.example .env
# Edit .env with your configuration

# Build the project
swift build -c release

# Run database migrations
swift run App migrate --yes

# Seed initial data
swift run cms seed
```

#### 4. Start the Server

Development mode (with hot reload):
```bash
swift run App serve --hostname 0.0.0.0 --port 8080 --env development
```

Production mode:
```bash
swift run App serve --hostname 0.0.0.0 --port 8080 --env production
```

#### 5. Verify Installation

Check that the server is running:
```bash
curl http://localhost:8080/healthz
# Should return: 200 OK

curl http://localhost:8080/ready
# Should return: {"status":"ready"}
```

Access the admin panel at `http://localhost:8080/admin`.

## First-Time Setup Process

After installation, follow these steps to configure your CMS:

1. **Access Admin Panel**
   - Open `http://localhost:8080/admin` in your browser
   - Log in with the admin credentials from your `.env` file

2. **Create Content Types**
   - Navigate to **Settings → Content Types**
   - Define your content types using JSON Schema
   - Example: Create a "Blog Post" type with fields like title, content, author, etc.

3. **Configure Permissions**
   - Go to **Settings → Roles & Permissions**
   - Assign appropriate permissions to different roles
   - Create API keys for external applications

4. **Set Up Authentication** (Optional but Recommended)
   - For production, configure Auth0 or Firebase Auth
   - See [Authentication Guide](./authentication.md) for details

5. **Configure Media Storage** (Optional)
   - By default, files are stored locally
   - For production, configure S3 storage in `.env`

6. **Generate Client SDK** (Optional)
   - For iOS/macOS apps: `swift run cms generate-sdk swift --output ./ClientSDK`
   - For other platforms, use the REST API directly

## Common Troubleshooting

### PostgreSQL Connection Issues

**Error:** `Unable to connect to database`

Solutions:
1. Ensure PostgreSQL is running:
   ```bash
   docker compose ps postgres
   ```

2. Check the database URL in `.env`:
   ```bash
   docker exec -it swiftcms-postgres-1 psql -U swiftcms -d swiftcms -c "\\l"
   ```

3. If the database doesn't exist, create it:
   ```bash
   docker exec -it swiftcms-postgres-1 createdb -U swiftcms swiftcms
   ```

### Redis Connection Issues

**Error:** `Redis connection refused`

Solutions:
1. Start Redis: `docker compose up -d redis`
2. Verify Redis is accessible: `redis-cli -h localhost -p 6379 ping`

### Port Already in Use

**Error:** `Address already in use`

Solutions:
1. Check what's using port 8080: `lsof -i :8080`
2. Use a different port: `swift run App serve --port 8081`
3. Stop the conflicting service

### Build Failures

**Error:** `Package resolution failed`

Solution:
```bash
cd /Users/gurindersingh/Documents/Developer/Swift-CMS
rm -rf .build Package.resolved
swift package resolve
swift build
```

**Error:** `Swift version mismatch`

Solution:
```bash
# Check Swift version
swift --version

# Update to Swift 6.1+
# macOS: Update Xcode to latest
# Linux: Download and install from swift.org
```

### Cannot Access Admin Panel

**Error:** `404 - Page not found`

Solution: Ensure environment is set to "development" for the admin panel:
```bash
swift run App serve --env development
```

### Permission Denied Errors

**Error:** `Permission denied` when running Swift commands

Solution:
```bash
# On Linux, ensure Swift is in PATH
echo 'export PATH=/usr/share/swift/usr/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# On macOS, ensure Xcode command line tools are installed
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Next Steps

After successful installation, refer to:
- [Configuration Guide](./configuration.md) for detailed setup
- [API Documentation](./api/) for API usage
- [Plugin Development](./plugin-development.md) for extending SwiftCMS
