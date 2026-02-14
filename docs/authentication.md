# Authentication Guide

## Overview
SwiftCMS supports three authentication providers, selectable via AUTH_PROVIDER env.

## Auth0 (Recommended)
```env
AUTH_PROVIDER=auth0
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_AUDIENCE=https://api.example.com
```
- JWKS-based JWT verification
- Native RBAC via Auth0 dashboard
- Multi-tenant via Auth0 Organizations

## Firebase Auth
```env
AUTH_PROVIDER=firebase
```
- X.509 certificate verification with periodic refresh
- Custom claims mapped to CMS roles

## Local JWT
```env
AUTH_PROVIDER=local
JWT_SECRET=your-secret-key
```
- Self-issued JWT tokens
- bcrypt password hashing
- 24-hour token expiry
- Login: POST /api/v1/auth/login

## RBAC
Four default roles: Super Admin, Editor, Author, Public.
Six actions: create, read, update, delete, publish, configure.
Permissions are per-role, per-content-type.

## API Keys
For machine-to-machine access. Send via X-API-Key header.
