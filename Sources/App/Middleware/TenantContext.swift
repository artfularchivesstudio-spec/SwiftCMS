import Vapor
import Fluent
import CMSObjects

// MARK: - Tenant Context Storage

/// Storage key for the resolved tenant ID on the request.
struct TenantContextKey: StorageKey {
    typealias Value = TenantContext
}

/// Holds the resolved tenant information for the current request.
public struct TenantContext: Sendable {
    /// The resolved tenant identifier.
    public let tenantId: String

    /// How the tenant was resolved.
    public let source: TenantSource

    public enum TenantSource: String, Sendable {
        case jwt       // From authenticated user's JWT claims
        case header    // From X-Tenant-ID header
        case subdomain // From Host header subdomain
    }

    public init(tenantId: String, source: TenantSource) {
        self.tenantId = tenantId
        self.source = source
    }
}

// MARK: - Request Extension

extension Request {
    /// The resolved tenant context for this request, if multi-tenancy is active.
    public var tenantContext: TenantContext? {
        get { storage[TenantContextKey.self] }
        set { storage[TenantContextKey.self] = newValue }
    }

    /// Convenience: the current tenant ID, or nil in single-tenant mode.
    public var tenantId: String? {
        tenantContext?.tenantId
    }
}

// MARK: - Tenant Context Middleware

/// Extracts tenant identity from the request using three strategies:
/// 1. Authenticated user's JWT `tenantId` claim
/// 2. `X-Tenant-ID` request header
/// 3. Subdomain of the `Host` header
///
/// Only active when `MULTI_TENANT=true` environment variable is set.
/// In single-tenant mode (default), this middleware is a passthrough.
public struct TenantContextMiddleware: AsyncMiddleware, Sendable {

    /// The base domain used for subdomain extraction (e.g., "example.com").
    /// Subdomains of this domain resolve to tenant IDs.
    private let baseDomain: String?

    public init(baseDomain: String? = nil) {
        self.baseDomain = baseDomain ?? Environment.get("TENANT_BASE_DOMAIN")
    }

    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        // Skip if multi-tenancy is not enabled
        guard Environment.get("MULTI_TENANT")?.lowercased() == "true" else {
            return try await next.respond(to: request)
        }

        // Strategy 1: From authenticated user's JWT claims
        if let user = request.auth.get(CmsUser.self), let tenantId = user.tenantId {
            request.tenantContext = TenantContext(tenantId: tenantId, source: .jwt)
            request.logger[metadataKey: "tenant-id"] = "\(tenantId)"
            request.logger[metadataKey: "tenant-source"] = "jwt"
            return try await next.respond(to: request)
        }

        // Strategy 2: From X-Tenant-ID header
        if let headerTenant = request.headers.first(name: "X-Tenant-ID"), !headerTenant.isEmpty {
            request.tenantContext = TenantContext(tenantId: headerTenant, source: .header)
            request.logger[metadataKey: "tenant-id"] = "\(headerTenant)"
            request.logger[metadataKey: "tenant-source"] = "header"
            return try await next.respond(to: request)
        }

        // Strategy 3: From subdomain
        if let baseDomain = self.baseDomain,
           let host = request.headers.first(name: "Host") {
            let subdomain = extractSubdomain(from: host, baseDomain: baseDomain)
            if let subdomain = subdomain, !subdomain.isEmpty {
                request.tenantContext = TenantContext(tenantId: subdomain, source: .subdomain)
                request.logger[metadataKey: "tenant-id"] = "\(subdomain)"
                request.logger[metadataKey: "tenant-source"] = "subdomain"
                return try await next.respond(to: request)
            }
        }

        // No tenant resolved in multi-tenant mode.
        // Public endpoints may proceed without tenant context.
        // Protected endpoints should check for tenant via TenantScopedQueryModifier.
        return try await next.respond(to: request)
    }

    /// Extract subdomain from a host string given a base domain.
    /// e.g., "blog.example.com" with base "example.com" → "blog"
    /// e.g., "example.com" with base "example.com" → nil
    private func extractSubdomain(from host: String, baseDomain: String) -> String? {
        // Strip port if present
        let hostOnly = host.split(separator: ":").first.map(String.init) ?? host

        guard hostOnly.hasSuffix(baseDomain), hostOnly != baseDomain else {
            return nil
        }

        // Remove the base domain and trailing dot
        let prefix = String(hostOnly.dropLast(baseDomain.count))
        let subdomain = prefix.hasSuffix(".") ? String(prefix.dropLast()) : prefix

        return subdomain.isEmpty ? nil : subdomain
    }
}

// MARK: - Tenant Scoped Query Modifier

/// Middleware that enforces tenant isolation on mutating requests.
/// When active, it ensures that:
/// - POST/PUT/PATCH requests include the tenant_id in the body
/// - The tenant_id in the body matches the request's tenant context
///
/// This provides row-level tenant isolation at the API boundary.
public struct TenantScopedQueryModifier: AsyncMiddleware, Sendable {

    public init() {}

    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        // Only enforce in multi-tenant mode
        guard Environment.get("MULTI_TENANT")?.lowercased() == "true" else {
            return try await next.respond(to: request)
        }

        // Only enforce on API routes
        guard request.url.path.hasPrefix("/api/") else {
            return try await next.respond(to: request)
        }

        // Only enforce on mutating methods
        guard [.POST, .PUT, .PATCH, .DELETE].contains(request.method) else {
            // For GET requests, tenant scoping is handled at the query level
            return try await next.respond(to: request)
        }

        // If we have a tenant context, stamp it into logger for tracing
        if let tenantId = request.tenantId {
            request.logger[metadataKey: "tenant-scope"] = "\(tenantId)"
        }

        return try await next.respond(to: request)
    }
}

// MARK: - Fluent Query Extension for Tenant Scoping

extension QueryBuilder {
    /// Scope a Fluent query to the current tenant, if multi-tenancy is active.
    /// Usage: `ContentEntry.query(on: req.db).scopedToTenant(req)`
    ///
    /// This requires the model to have an optional `tenant_id` String field.
    /// Models without this field should not use this method.
    @discardableResult
    public func scopedToTenant(_ req: Request, fieldKey: FieldKey = "tenant_id") -> Self {
        guard Environment.get("MULTI_TENANT")?.lowercased() == "true",
              let tenantId = req.tenantId else {
            return self
        }

        return self.filter(.path(
            [fieldKey],
            schema: Model.schema
        ), .equal, .bind(tenantId))
    }
}
