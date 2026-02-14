import Vapor
import Fluent
import CMSObjects
import CMSSchema

// MARK: - TypeScript SDK Generator

/// Generates a TypeScript client SDK for the SwiftCMS API.
///
/// This generator introspects content type definitions and generates
/// fully typed TypeScript interfaces and API client code.
public actor TypeScriptSDKGenerator {

    /// Generate the complete TypeScript SDK.
    public func generate(
        contentTypes: [ContentTypeDefinition],
        apiBaseURL: String,
        moduleName: String = "SwiftCMS"
    ) async throws -> String {
        var output = ""

        // Header
        output += generateHeader(apiBaseURL: apiBaseURL, moduleName: moduleName)

        // Types
        output += generateTypes(contentTypes: contentTypes)

        // API Client
        output += generateClient(contentTypes: contentTypes)

        // Exports
        output += generateExports()

        return output
    }

    /// Generate the file header with configuration.
    private func generateHeader(apiBaseURL: String, moduleName: String) -> String {
        return """
        /**
         * SwiftCMS TypeScript Client SDK
         * Generated from SwiftCMS content type definitions
         * @version 1.0.0
         */

        // Configuration
        export const API_BASE_URL = "\(apiBaseURL)";
        export const API_TIMEOUT = 30000;

        // Types
        type JSONValue = string | number | boolean | null | JSONObject | JSONValue[];
        interface JSONObject { [key: string]: JSONValue; }

        """
    }

    /// Generate TypeScript interfaces for content types.
    private func generateTypes(contentTypes: [ContentTypeDefinition]) -> String {
        var output = "// Content Type Interfaces\n\n"

        // Pagination types
        output += """
        export interface PaginationMeta {
            page: number;
            perPage: number;
            total: number;
            totalPages: number;
        }

        export interface PaginatedResponse<T> {
            data: T[];
            meta: PaginationMeta;
        }

        export interface ContentEntry {
            id: string;
            contentType: string;
            status: 'draft' | 'published' | 'archived';
            data: JSONObject;
            locale: string;
            createdAt?: string;
            updatedAt?: string;
            publishedAt?: string;
            createdBy?: string;
        }

        """

        for contentType in contentTypes {
            output += generateTypeInterface(from: contentType)
        }

        return output
    }

    /// Generate a TypeScript interface for a single content type.
    private func generateTypeInterface(from contentType: ContentTypeDefinition) -> String {
        let typeName = typeNameFromSlug(contentType.slug)
        var output = "export interface \(typeName) {\n"

        guard case let .dictionary(jsonSchema) = contentType.jsonSchema else {
            return output + "    // Invalid schema\n}\n\n"
        }

        if let properties = jsonSchema["properties"]?.dictionaryValue {
            for fieldName in properties.keys.sorted() {
                guard let fieldSchema = properties[fieldName],
                      let dict = fieldSchema.dictionaryValue,
                      let type = dict["type"]?.stringValue else {
                    continue
                }

                let description = dict["description"]?.stringValue
                let isRequired = jsonSchema["required"]?.arrayValue?.contains(
                    where: { $0.stringValue == fieldName }
                ) ?? false

                let tsType = typeScriptType(from: dict, type: type)
                let optional = isRequired ? "" : "?"

                var line = "    /**"
                if let desc = description {
                    line += desc
                }
                line += " */\n"
                line += "    \(fieldName)\(optional): \(tsType);"

                output += line + "\n"
            }
        }

        output += "}\n\n"

        // Also generate the data interface (just the data part)
        output += "export interface \(typeName)Data {\n"
        if let properties = jsonSchema["properties"]?.dictionaryValue {
            for fieldName in properties.keys.sorted() {
                guard let fieldSchema = properties[fieldName],
                      let dict = fieldSchema.dictionaryValue,
                      let type = dict["type"]?.stringValue else {
                    continue
                }

                let tsType = typeScriptType(from: dict, type: type)
                let isRequired = jsonSchema["required"]?.arrayValue?.contains(
                    where: { $0.stringValue == fieldName }
                ) ?? false
                let optional = isRequired ? "" : "?"

                output += "    \(fieldName)\(optional): \(tsType);\n"
            }
        }
        output += "}\n\n"

        return output
    }

    /// Convert JSON Schema type to TypeScript type.
    private func typeScriptType(from dict: [String: AnyCodableValue], type: String) -> String {
        switch type {
        case "string":
            let format = dict["format"]?.stringValue
            if format == "email" { return "string" }
            if format == "date" || format == "date-time" { return "string" }
            if format == "uuid" { return "string" }
            return "string"

        case "integer":
            return "number"

        case "number":
            return "number"

        case "boolean":
            return "boolean"

        case "array":
            if let items = dict["items"]?.dictionaryValue,
               let itemType = items["type"]?.stringValue {
                let innerType = typeScriptType(from: items, type: itemType)
                return "\(innerType)[]"
            }
            return "any[]"

        case "object":
            return "JSONObject"

        default:
            return "any"
        }
    }

    /// Generate API client methods.
    private func generateClient(contentTypes: [ContentTypeDefinition]) -> String {
        var output = """
        // API Client Class
        export class SwiftCMSClient {
            private baseUrl: string;
            private timeout: number;
            private token: string | null = null;

            constructor(options?: { baseUrl?: string; timeout?: number; token?: string }) {
                this.baseUrl = options?.baseUrl || API_BASE_URL;
                this.timeout = options?.timeout || API_TIMEOUT;
                this.token = options?.token || null;
            }

            setToken(token: string) {
                this.token = token;
            }

            private async request<T>(
                method: string,
                path: string,
                body?: any,
                options?: RequestInit
            ): Promise<T> {
                const headers: Record<string, string> = {
                    'Content-Type': 'application/json',
                    ...options?.headers
                };

                if (this.token) {
                    headers['Authorization'] = `Bearer ${this.token}`;
                }

                const response = await fetch(`${this.baseUrl}${path}`, {
                    method,
                    headers,
                    body: body ? JSON.stringify(body) : undefined,
                    signal: AbortSignal.timeout(this.timeout),
                    ...options
                });

                if (!response.ok) {
                    const error = await response.text();
                    throw new Error(`HTTP ${response.status}: ${error}`);
                }

                return response.json();
            }

        """

        // Generate CRUD methods for each content type
        for contentType in contentTypes {
            let typeName = typeNameFromSlug(contentType.slug)
            let slug = contentType.slug

            output += """
            // ========== \(contentType.displayName) ==========

            /**
             * List all \(contentType.displayName) entries
             */
            async list\(typeName)(params?: {
                page?: number;
                perPage?: number;
                status?: 'draft' | 'published' | 'archived';
                locale?: string;
            }): Promise<PaginatedResponse<\(typeName)Data>> {
                const searchParams = new URLSearchParams();
                if (params?.page) searchParams.set('page', params.page.toString());
                if (params?.perPage) searchParams.set('perPage', params.perPage.toString());
                if (params?.status) searchParams.set('status', params.status);
                if (params?.locale) searchParams.set('locale', params.locale);

                return this.request<PaginatedResponse<\(typeName)Data>>(
                    'GET',
                    `/api/v1/\(slug)?${searchParams}`
                );
            }

            /**
             * Get a single \(contentType.displayName.singularized()) by ID
             */
            async get\(typeName)(id: string): Promise<\(typeName)Data> {
                return this.request<\(typeName)Data>(
                    'GET',
                    `/api/v1/\(slug)/${encodeURIComponent(id)}`
                );
            }

            /**
             * Create a new \(contentType.displayName.singularized())
             */
            async create\(typeName)(data: \(typeName)Data): Promise<\(typeName)Data> {
                return this.request<\(typeName)Data>(
                    'POST',
                    `/api/v1/\(slug)`,
                    { data }
                );
            }

            /**
             * Update a \(contentType.displayName.singularized())
             */
            async update\(typeName)(id: string, data: Partial<\(typeName)Data>): Promise<\(typeName)Data> {
                return this.request<\(typeName)Data>(
                    'PUT',
                    `/api/v1/\(slug)/${encodeURIComponent(id)}`,
                    { data }
                );
            }

            /**
             * Delete a \(contentType.displayName.singularized())
             */
            async delete\(typeName)(id: string): Promise<void> {
                return this.request<void>(
                    'DELETE',
                    `/api/v1/\(slug)/${encodeURIComponent(id)}`
                );
            }

            /**
             * Publish a \(contentType.displayName.singularized())
             */
            async publish\(typeName)(id: string): Promise<\(typeName)Data> {
                return this.request<\(typeName)Data>(
                    'POST',
                    `/api/v1/\(slug)/${encodeURIComponent(id)}/publish`
                );
            }

            /**
             * Unpublish a \(contentType.displayName.singularized())
             */
            async unpublish\(typeName)(id: string): Promise<\(typeName)Data> {
                return this.request<\(typeName)Data>(
                    'POST',
                    `/api/v1/\(slug)/${encodeURIComponent(id)}/unpublish`
                );
            }

            """
        }

        output += "}// End of SwiftCMSClient\n"
        return output
    }

    /// Generate export statements.
    private func generateExports() -> String {
        return """
        // Export default client instance
        export const client = new SwiftCMSClient();

        // Export class for named instances
        export { SwiftCMSClient };

        """
    }

    /// Convert a slug to a TypeScript type name (PascalCase).
    private func typeNameFromSlug(_ slug: String) -> String {
        // Convert slug to PascalCase
        return slug
            .split(separator: "_")
            .map { $0.capitalized }
            .joined()
            .replacingOccurrences(of: "-", with: "_")
            .split(separator: "_")
            .map { $0.capitalized }
            .joined()
    }

}
