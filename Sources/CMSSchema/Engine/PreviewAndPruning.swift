import Vapor
import Fluent
import CMSObjects

// MARK: - Content Preview

/// Provides draft content preview with short-lived tokens.
public struct ContentPreviewService: Sendable {

    /// Generate a preview token (1hr expiry) for a draft entry.
    public static func generatePreviewToken(
        entryId: UUID,
        contentType: String
    ) throws -> String {
        let payload: [String: String] = [
            "sub": "preview",
            "entry_id": entryId.uuidString,
            "content_type": contentType,
            "exp": "\(Date().addingTimeInterval(3600).timeIntervalSince1970)"
        ]
        let data = try JSONEncoder().encode(payload)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Validate a preview token and return the entry ID.
    public static func validatePreviewToken(_ token: String) -> (entryId: UUID, contentType: String)? {
        var base64 = token
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }

        guard let data = Data(base64Encoded: base64),
              let payload = try? JSONDecoder().decode([String: String].self, from: data),
              let entryIdStr = payload["entry_id"],
              let entryId = UUID(uuidString: entryIdStr),
              let contentType = payload["content_type"],
              let expStr = payload["exp"],
              let exp = Double(expStr),
              Date(timeIntervalSince1970: exp) > Date()
        else {
            return nil
        }
        return (entryId, contentType)
    }
}

// MARK: - Preview Controller Extension

/// Add preview routes to the content API.
public struct PreviewController: RouteCollection {
    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        let content = routes.grouped(":contentType")

        // Generate preview token (requires auth)
        content.post(":entryId", "preview-token", use: generateToken)

        // Access preview (token-based, no auth required)
        content.get(":entryId", "preview", use: preview)
    }

    /// POST /api/v1/:contentType/:entryId/preview-token
    @Sendable
    func generateToken(req: Request) async throws -> Response {
        let contentType = try req.parameters.require("contentType")
        guard let entryId = req.parameters.get("entryId", as: UUID.self) else {
            throw ApiError.badRequest("Invalid entry ID")
        }

        // Verify entry exists
        guard let _ = try await ContentEntry.query(on: req.db)
            .filter(\.$contentType == contentType)
            .filter(\.$id == entryId)
            .first()
        else {
            throw ApiError.notFound("Entry not found")
        }

        let token = try ContentPreviewService.generatePreviewToken(
            entryId: entryId, contentType: contentType
        )

        let res = Response(status: .ok)
        try res.content.encode(["token": token])
        return res
    }

    /// GET /api/v1/:contentType/:entryId/preview?token=...
    @Sendable
    func preview(req: Request) async throws -> ContentEntryResponseDTO {
        guard let token = req.query[String.self, at: "token"] else {
            throw ApiError.unauthorized("Preview token required")
        }

        guard let validated = ContentPreviewService.validatePreviewToken(token) else {
            throw ApiError.unauthorized("Invalid or expired preview token")
        }

        guard let entry = try await ContentEntry.find(validated.entryId, on: req.db) else {
            throw ApiError.notFound("Entry not found")
        }

        return entry.toResponseDTO()
    }
}
