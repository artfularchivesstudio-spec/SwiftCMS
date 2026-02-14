# Configuration Guide

This guide covers all configuration options for SwiftCMS, including environment variables, authentication setup, storage configuration, and external services.

## Environment Variables Reference

SwiftCMS uses environment variables for configuration. Copy `.env.example` to `.env` and modify as needed.

### Database Configuration

```bash
# PostgreSQL connection string
DATABASE_URL=postgresql://swiftcms:swiftcms@localhost:5432/swiftcms

# Connection pool settings
DB_POOL_SIZE=10
DB_IDLE_TIMEOUT=60
```

**Format:** `postgresql://username:password@host:port/database`

### Redis Configuration

```bash
# Redis connection string
REDIS_URL=redis://localhost:6379

# Connection pool settings
REDIS_POOL_SIZE=5
REDIS_TIMEOUT=30
```

**Format:** `redis://host:port`

For Redis with authentication: `redis://:password@host:port`

### Search Configuration (Meilisearch)

```bash
# Meilisearch URL and master key
MEILI_URL=http://localhost:7700
MEILI_KEY=masterKey

# Index prefix (useful for multiple environments)
MEILI_INDEX_PREFIX=api_development_

# Sync interval (seconds)
MEILI_SYNC_INTERVAL=30
```

Get your master key from the Meilisearch dashboard.

### Authentication Configuration

#### Auth0 Setup (Recommended for Production)

```bash
# Use Auth0 as the authentication provider
AUTH_PROVIDER=auth0

# Your Auth0 domain
AUTH0_DOMAIN=your-tenant.auth0.com

# Your API audience (should match your Auth0 API identifier)
AUTH0_AUDIENCE=https://api.yourapp.com

# Optional: Auth0 Management API for advanced features
AUTH0_CLIENT_ID=your-client-id
AUTH0_CLIENT_SECRET=your-client-secret
```

**Configuration Steps:**

1. **Create Auth0 Application:**
   - Go to [Auth0 Dashboard](https://manage.auth0.com)
   - Create a new "Single Page Application" or "Regular Web Application"
   - Configure allowed callbacks: `http://localhost:8080/admin/callback`

2. **Create Auth0 API:**
   - Navigate to **Applications → APIs**
   - Click "Create API"
   - Set **Name**: "SwiftCMS API"
   - Set **Identifier**: `https://api.yourapp.com` (use your actual domain)
   - Set **Signing Algorithm**: RS256

3. **Create Roles in Auth0:**
   ```yaml
   Roles:
     - super_admin: Full system access
     - admin: Organization admin
     - editor: Can publish content
     - author: Can create/edit own content
     - public: Read-only access
   ```

4. **Configure RBAC:**
   - Go to your API settings
   - Enable **RBAC Settings**
   - Check "Add Permissions in the Access Token"

5. **Get Management API Access:**
   - Create a "Machine-to-Machine" application
   - Add scopes: `read:users`, `update:users`, `read:roles`, `create:role_members`

#### Firebase Authentication

```bash
# Use Firebase as the authentication provider
AUTH_PROVIDER=firebase

# Firebase project ID
FIREBASE_PROJECT_ID=your-project-id

# X.509 certificates URL (auto-configured)
GOOGLE_CERTS_URL=https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com

# Certificate refresh interval (hours)
GOOGLE_CERTS_INTERVAL=24
```

**Configuration Steps:**

1. **Create Firebase Project:**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Create a new project
   - Enable "Email/Password" and any other desired providers

2. **Create Service Account:**
   - Go to **Project Settings → Service Accounts**
   - Click "Generate New Private Key"
   - Save the JSON file

3. **Configure Custom Claims:**
   ```javascript
   // In Firebase Cloud Functions or Admin SDK
   admin.auth().setCustomUserClaims(uid, {
     roles: ['editor'],
     tenantId: 'tenant-123'
   });
   ```

#### Local JWT (Development Only)

```bash
# Use local JWT authentication
AUTH_PROVIDER=local

# Secret key for signing tokens
JWT_SECRET=change-me-to-a-secure-random-string

# Token expiration (hours)
JWT_EXPIRY=24

# Password hashing cost (4-31, higher is more secure but slower)
BCRYPT_COST=12
```

**Generate a Secure Secret:**
```bash
openssl rand -base64 32
```

**API Authentication:**
```bash
# Get token
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@swiftcms.dev", "password": "admin123"}'

# Use token
curl http://localhost:8080/api/v1/content \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Storage Configuration

#### Local Storage (Development)

```bash
# Store files locally
STORAGE_PROVIDER=local

# Upload directory
LOCAL_STORAGE_PATH=Public/uploads

# Public URL base path
LOCAL_PUBLIC_URL=http://localhost:8080/uploads
```

#### AWS S3 Storage (Production)

```bash
# Use S3 for file storage
STORAGE_PROVIDER=s3

# S3 bucket configuration
S3_BUCKET=swiftcms-media
S3_REGION=us-east-1

# S3 optional settings
S3_ENDPOINT=          # For S3-compatible services (MinIO, DigitalOcean Spaces)
S3_PATH_STYLE=false   # For older S3-compatible services

# AWS credentials (use IAM roles in production)
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key

# Default ACL for uploaded objects
S3_ACL=public-read

# Upload options
S3_MULTIPART_THRESHOLD=8388608  # 8MB
S3_MAX_PART_SIZE=8388608        # 8MB
```

**IAM Policy Example:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::swiftcms-media/*",
        "arn:aws:s3:::swiftcms-media"
      ]
    }
  ]
}
```

### Email/SMTP Configuration

```bash
# SMTP settings for notifications and password reset
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password

# Connection settings
SMTP_TLS=true
SMTP_TIMEOUT=30

# From email addresses
FROM_EMAIL=notifications@yourapp.com
FROM_NAME=SwiftCMS

# Email templates directory
EMAIL_TEMPLATES_PATH=Resources/Views/Emails
```

**For Gmail:**
- Use "App Password" instead of regular password
- Enable 2FA on your Google account first
- Generate app password at: [https://myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords)

### Application Configuration

```bash
# Application URL (used for generating links)
APP_URL=http://localhost:8080

# Server port (overridden by command line)
PORT=8080

# Environment: development, staging, production
ENVIRONMENT=development

# Allowed CORS origins
ALLOWED_ORIGINS=*
# OR specify domains: http://localhost:3000,https://yourapp.com

# Allowed hosts for CSRF protection
ALLOWED_HOSTS=localhost:8080,yourapp.com

# Security headers
HSTS_MAX_AGE=31536000
HSTS_INCLUDE_SUBDOMAINS=true
HSTS_PRELOAD=true
```

### Performance & Scaling

```bash
# HTTP server settings
MAX_CONCURRENT_CONNECTIONS=1000
KEEP_ALIVE_TIMEOUT=75
PROXY_PROTOCOL=false

# Request limits
MAX_BODY_SIZE=50mb
MAX_UPLOAD_SIZE=50mb

# Rate limiting
RATE_LIMIT_PER_MINUTE=1000
RATE_LIMIT_BURST_SIZE=100
RATE_LIMIT_ENABLED=true

# Thread pool settings
THREAD_POOL_SIZE=system_default
THREAD_POOL_TIMEOUT=10
```

### Logging Configuration

```bash
# Log level: trace, debug, info, warning, error, critical
LOG_LEVEL=info

# Log format: short, extended, json
LOG_FORMAT=json

# Log output: console, file, both
LOG_OUTPUT=console

# Log destinations
LOG_DESTINATIONS=console
# OR: /var/log/swiftcms/app.log,https://your-log-service.com/api/logs

# Request logging
LOG_REQUESTS=true
LOG_REQUEST_BODIES=false
LOG_REQUEST_HEADERS=false
```

### Advanced Configuration

#### WebSocket Settings

```bash
# WebSocket endpoint
WEBSOCKET_PATH=/ws

# WebSocket timeout
WEBSOCKET_TIMEOUT=300

# WebSocket ping interval
WEBSOCKET_PING_INTERVAL=60

# WebSocket buffer size
WEBSOCKET_BUFFER_SIZE=4096
```

#### GraphQL Settings

```bash
# GraphQL endpoint
GRAPHQL_PATH=/graphql

# Enable GraphiQL playground
GRAPHIQL_ENABLED=true

# GraphQL playground title
GRAPHIQL_TITLE=SwiftCMS API

# Max query depth (prevents DoS attacks)
GRAPHQL_MAX_DEPTH=10

# Max query complexity
GRAPHQL_MAX_COMPLEXITY=1000

# Query timeout (seconds)
GRAPHQL_TIMEOUT=30
```

#### Client SDK Generation

```bash
# Swift SDK output directory
SWIFT_SDK_OUTPUT=./ClientSDK

# SDK version
SDK_VERSION=1.0.0

# SDK author
SDK_AUTHOR=SwiftCMS

# Generate async/await SDK
SDK_ASYNC_AWAIT=true

# Include documentation
SDK_INCLUDE_DOCS=true
```

## Development Configuration

Create a `.env.development` file for local overrides:

```bash
# .env.development
ENVIRONMENT=development
LOG_LEVEL=debug
LOG_REQUEST_BODIES=true
GRAPHQL_MAX_DEPTH=15
MEILI_INDEX_PREFIX=development_
```

SwiftCMS will load `.env` first, then `.env.{environment}`.

## Environment-Specific Examples

### Production Environment

```bash
# .env.production
ENVIRONMENT=production
LOG_LEVEL=warning
LOG_FORMAT=json
LOG_OUTPUT=both

DATABASE_URL=postgresql://swiftcms:strong-password@prod-db.internal:5432/swiftcms
REDIS_URL=redis://prod-redis.internal:6379

AUTH_PROVIDER=auth0
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_AUDIENCE=https://api.yourapp.com

STORAGE_PROVIDER=s3
S3_BUCKET=swiftcms-production
S3_REGION=us-east-1

MEILI_URL=https://search.yourapp.com
MEILI_KEY=secure-master-key

APP_URL=https://yourapp.com
ALLOWED_ORIGINS=https://yourapp.com,https://admin.yourapp.com

RATE_LIMIT_PER_MINUTE=10000
MAX_BODY_SIZE=100mb
MAX_UPLOAD_SIZE=100mb
```

### Staging Environment

```bash
# .env.staging
ENVIRONMENT=staging
LOG_LEVEL=info

DATABASE_URL=postgresql://swiftcms:staging@staging-db.internal:5432/swiftcms

APP_URL=https://staging.yourapp.com
ALLOWED_ORIGINS=https://staging.yourapp.com,https://admin-staging.yourapp.com

MEILI_INDEX_PREFIX=staging_
```

## Security Best Practices

1. **Use Strong Secrets**: Never use default JWT secrets in production
2. **Rotate Credentials**: Regularly rotate database passwords and API keys
3. **Use IAM Roles**: For AWS, use IAM roles instead of access keys
4. **HTTPS Only**: Always use HTTPS in production
5. **Network Security**: Use VPC/private networks for databases and Redis
6. **Backup Configuration**: Keep `.env` files in secure storage with backups
7. **Environment Isolation**: Never share configuration between environments
8. **Monitoring**: Set up alerts for failed authentication attempts
9. **Rate Limiting**: Enable rate limiting in production
10. **CORS**: Only allow trusted origins in production

## Testing Configuration

Test your configuration before deploying:

```bash
# Test database connection
pg_isready -h $(echo $DATABASE_URL | cut -d'@' -f2 | cut -d':' -f1) -p 5432

# Test Redis
redis-cli -u $REDIS_URL ping

# Test Meilisearch
curl -H "Authorization: Bearer $MEILI_KEY" $MEILI_URL/health

# Test S3 access
aws s3 ls s3://$S3_BUCKET --region $S3_REGION

# Send test email
curl smtp://$SMTP_HOST:$SMTP_PORT --mail-from $FROM_EMAIL --mail-rcpt test@example.com
```

## Troubleshooting

### Database Connection Timeout

Increase timeout values:
```bash
DB_POOL_SIZE=20
DB_IDLE_TIMEOUT=120
```

### Redis Connection Failures

Enable Redis cluster mode if using cluster:
```bash
REDIS_CLUSTER=true
REDIS_POOL_SIZE=10_per_node
```

### Meilisearch Sync Issues

If Meilisearch is out of sync:
```bash
# Trigger full reindex
swift run cms search:reindex --all

# Reindex specific content type
swift run cms search:reindex --type posts
```

### Auth0 Token Verification Failures

Ensure clocks are synchronized:
```bash
# Sync system time
sudo ntpdate -s time.nist.gov
```

Check JWKS endpoint:
```bash
curl https://your-tenant.auth0.com/.well-known/jwks.json
```

## Next Steps

- [Installation Guide](./installation.md) - Get SwiftCMS running
- [Authentication Guide](./authentication.md) - Detailed auth setup
- [Plugin Development](./plugin-development.md) - Extend SwiftCMS
- [API Documentation](./api/) - API reference