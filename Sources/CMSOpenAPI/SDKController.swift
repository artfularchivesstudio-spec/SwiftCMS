import Vapor
import Fluent
import CMSObjects
import CMSSchema

// MARK: - SDK Controller

/// Controller for serving generated SDK code.
public struct SDKController: RouteCollection, Sendable {

    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        // TypeScript SDK
        routes.get("api", "sdk", "typescript") { req async throws -> Response in
            let generator = TypeScriptSDKGenerator()
            let contentTypes = try await ContentTypeDefinition.query(on: req.db).all()

            let host = req.headers.first(name: "Host") ?? "localhost:8080"
            let scheme = req.headers.first(name: "X-Forwarded-Proto") ?? "http"
            let baseURL = "\(scheme)://\(host)"

            let typescriptCode = try await generator.generate(
                contentTypes: contentTypes,
                apiBaseURL: baseURL
            )

            var res = Response(status: .ok)
            res.headers.add(name: .contentType, value: "text/typescript")
            res.headers.add(name: .contentDisposition, value: "attachment; filename=\"swiftcms-client.ts\"")
            res.body = .init(string: typescriptCode)
            return res
        }

        // Swift SDK
        routes.get("api", "sdk", "swift") { req async throws -> Response in
            let generator = SwiftSDKGenerator()
            let contentTypes = try await ContentTypeDefinition.query(on: req.db).all()

            let host = req.headers.first(name: "Host") ?? "localhost:8080"
            let scheme = req.headers.first(name: "X-Forwarded-Proto") ?? "http"
            let baseURL = "\(scheme)://\(host)"

            let swiftCode = try await generator.generate(
                contentTypes: contentTypes,
                apiBaseURL: baseURL
            )

            var res = Response(status: .ok)
            res.headers.add(name: .contentType, value: "text/x-swift")
            res.headers.add(name: .contentDisposition, value: "attachment; filename=\"SwiftCMSClient.swift\"")
            res.body = .init(string: swiftCode)
            return res
        }
    }
}
