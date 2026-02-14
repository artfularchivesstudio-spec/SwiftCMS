import Vapor
import NIOCore

// MARK: - 🗄️ File Storage Provider Protocol

/// 🗄️ **File Storage Provider**
///
/// Abstract interface for file storage backends supporting multiple providers (local, S3, Azure).
/// Enables pluggable storage architecture for flexible deployment strategies across different environments.
///
/// ## Concurrency Design
/// - `Sendable` conformance ensures thread-safe usage across async boundaries
/// - All operations are `async throws` for proper async/await integration
/// - Supports concurrent uploads and downloads from multiple threads
///
/// ## Security Requirements
/// - Implementations MUST validate file paths to prevent directory traversal attacks
/// - Content type validation occurs before upload to prevent malicious content
/// - Storage providers should implement their own security measures
/// - All paths should be sanitized and normalized
///
/// ## Conforming Types
/// - `S3StorageProvider` - Cloud storage using AWS S3
/// - `LocalStorageProvider` - Local filesystem storage
/// - Future: `AzureBlobProvider`, `GoogleCloudProvider`, etc.
///
/// ## Usage Example
/// ```swift
/// // Choose provider based on environment
/// let storage = Environment.get("STORAGE_PROVIDER") == "s3"
///     ? S3StorageProvider()
///     : LocalStorageProvider()
///
/// // Upload a file
/// let url = try await storage.upload(
///     key: "assets/logo.png",
///     data: fileBuffer,
///     contentType: "image/png"
/// )
///
/// // Download a file
/// let data = try await storage.download(key: "assets/logo.png")
///
/// // Delete a file
/// try await storage.delete(key: "assets/logo.png")
///
/// // Get public URL
/// let publicURL = storage.publicURL(key: "assets/logo.png")
/// ```
@available(macOS 13.0, *)
public protocol FileStorageProvider: Sendable {
    /// 📤 **Upload File**
    ///
    /// Uploads a file to storage and returns the storage key.
    ///
    /// - Parameters:
    ///   - key: Unique storage path/key for the file (e.g., "avatars/user123.jpg")
    ///   - data: Raw file data as ByteBuffer
    ///   - contentType: MIME type of the file for proper HTTP serving
    /// - Returns: String storage key that can be used for subsequent operations
    /// - Throws: `ApiError.internalError` if upload fails, or provider-specific errors
    func upload(key: String, data: ByteBuffer, contentType: String) async throws -> String

    /// 📥 **Download File**
    ///
    /// Downloads a file from storage by key.
    ///
    /// - Parameter key: Storage key returned from upload
    /// - Returns: File contents as ByteBuffer
    /// - Throws: Errors if key doesn't exist or download fails
    func download(key: String) async throws -> ByteBuffer

    /// 🗑️ **Delete File**
    ///
    /// Deletes a file from storage by key.
    ///
    /// - Parameter key: Storage key to delete
    /// - Throws: Errors if deletion fails. Note: should be idempotent (no error if key doesn't exist)
    func delete(key: String) async throws

    /// 🔗 **Get Public URL**
    ///
    /// Returns a public URL for the file if available.
    /// May return nil if file is private and requires authentication.
    ///
    /// - Parameter key: Storage key
    /// - Returns: Public URL string or nil if not publicly accessible
    func publicURL(key: String) -> String?
}
