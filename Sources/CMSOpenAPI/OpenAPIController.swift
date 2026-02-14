import Vapor
import Fluent

// MARK: - OpenAPI Controller

/// Controller for serving OpenAPI documentation.
public struct OpenAPIController: RouteCollection, Sendable {

    public init() {}

    public func boot(routes: any RoutesBuilder) throws {
        // OpenAPI JSON specification
        routes.get("api", "docs", "openapi.json") { req async throws -> OpenAPIDocument in
            let generator = OpenAPIGenerator()

            let host = req.headers.first(name: "Host") ?? "localhost:8080"
            let scheme = req.headers.first(name: "X-Forwarded-Proto") ?? "http"
            let baseURL = "\(scheme)://\(host)"

            return try await generator.generateSpecification(
                app: req.application,
                baseURL: baseURL
            )
        }

        // Swagger UI
        routes.get("api", "docs") { req -> Response in
            let html = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>SwiftCMS API Documentation</title>
                <link rel="stylesheet" type="text/css" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui.css">
                <style>
                    html { box-sizing: border-box; }
                    *, *:before, *:after { box-sizing: inherit; }
                    body { margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; }
                </style>
            </head>
            <body>
                <div id="swagger-ui"></div>
                <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
                <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui-standalone-preset.js"></script>
                <script>
                    window.onload = function() {
                        const ui = SwaggerUIBundle({
                            url: "/api/docs/openapi.json",
                            dom_id: '#swagger-ui',
                            deepLinking: true,
                            presets: [
                                SwaggerUIBundle.presets.apis,
                                SwaggerUIStandalonePreset
                            ],
                            plugins: [
                                SwaggerUIBundle.plugins.DownloadUrl
                            ],
                            layout: "StandaloneLayout",
                            defaultModelsExpandDepth: 1,
                            defaultModelExpandDepth: 1,
                            docExpansion: "list",
                            filter: true,
                            tryItOutEnabled: true
                        });
                    };
                </script>
            </body>
            </html>
            """

            var res = Response(status: .ok)
            res.headers.add(name: .contentType, value: "text/html")
            res.body = .init(string: html)
            return res
        }

        // ReDoc
        routes.get("api", "docs", "redoc") { req -> Response in
            let html = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>SwiftCMS API Reference</title>
                <meta charset="utf-8"/>
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <link href="https://fonts.googleapis.com/css?family=Montserrat:300,400,700|Roboto:300,400,700" rel="stylesheet">
                <style>
                    body { margin: 0; padding: 0; }
                </style>
            </head>
            <body>
                <redoc spec-url='/api/docs/openapi.json'></redoc>
                <script src="https://cdn.jsdelivr.net/npm/redoc@latest/bundles/redoc.standalone.js"></script>
            </body>
            </html>
            """

            var res = Response(status: .ok)
            res.headers.add(name: .contentType, value: "text/html")
            res.body = .init(string: html)
            return res
        }
    }
}
