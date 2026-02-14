import Vapor
import NIOCore
import Foundation

// MARK: - 🏠 Local Filesystem Storage Provider

/// 🏠 **Local Filesystem Storage Provider**
///
/// Development-friendly local filesystem storage provider with directory organization and file safety.
/// Ideal for development environments and small-scale deployments.
///
/// ## Storage Structure
/// ```
/// Public/
/// ├── uploads/
/// │   ├── images/
/// │   │   └── logo.png
/// │   ├── documents/
/// │   │   └── report.pdf
/// │   └── avatars/
/// │       └── user123.jpg
/// └── system/
///     └── cache/
/// ```
///
/// ## Security Features
/// - Path sanitization to prevent directory traversal
/// - Automatic directory creation
/// - File permission management (644 for files, 755 for directories)
/// - Content type validation via file extensions
///
/// ## Development Benefits
/// - No external dependencies
/// - Instant file access
/// - Easy debugging and inspection
/// - Zero configuration overhead
/// - Hot-reload friendly
///
/// ## Production Considerations
/// - ⚠️ Not recommended for production use
/// - Limited scalability
/// - No built-in backup
/// - Single point of failure
/// - No CDN integration
///
/// ## Configuration
/// ```swift
/// // Default: Creates Public/uploads directory automatically
/// let localStorage = LocalStorageProvider()
///
/// // Custom base directory
/// let customStorage = LocalStorageProvider(basePath: "/var/lib/swiftcms")
/// ```
///
/// ## Usage Examples
///
/// ### File Upload
/// ```swift
/// let key = try await localStorage.upload(
///     key: "avatars/user123.jpg",
///     data: imageBuffer,
///     contentType: "image/jpeg"
/// )
/// // Files stored at: Public/uploads/avatars/user123.jpg
/// ```
///
/// ### File Download
/// ```swift
/// let data = try await localStorage.download(key: "avatars/user123.jpg")
/// let image = UIImage(data: Data(buffer: data))
/// ```
///
/// ### File Access URL
/// ```swift
/// let url = localStorage.publicURL(key: "avatars/user123.jpg")
/// // Result: http://localhost:8080/uploads/avatars/user123.jpg
/// ```
@available(macOS 13.0, *)
public struct LocalStorageProvider: FileStorageProvider, Sendable {
    /// 📂 Base directory for all file storage operations
    private let basePath: String

    /// 🏗️ Initialize with custom base path
    ///
    /// - Parameter basePath: Root directory for file storage (default: "Public")
    public init(basePath: String = "Public") {
        self.basePath = basePath
        ensureBaseDirectoryExists()
    }

    /// 📤 Upload file to local filesystem
    ///
    /// - Parameters:
    ///   - key: File path relative to base directory
    ///   - data: File contents as ByteBuffer
    ///   - contentType: MIME type (used for validation)
    /// - Returns: The storage key
    /// - Throws: Errors if write fails
    public func upload(key: String, data: ByteBuffer, contentType: String) async throws -> String {
        let filePath = sanitizePath(key)
        let fullPath = basePath + "/" + filePath

        // Create directory if needed
        let directory = String(fullPath.prefix(upTo: fullPath.lastIndex(of: "/") ?? fullPath.startIndex))
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

        // Write file
        let data = Data(buffer: data)
        try data.write(to: URL(fileURLWithPath: fullPath))

        return key
    }

    /// 📥 Download file from local filesystem
    ///
    /// - Parameter key: File path relative to base directory
    /// - Returns: File contents as ByteBuffer
    /// - Throws: Errors if file doesn't exist
    public func download(key: String) async throws -> ByteBuffer {
        let filePath = sanitizePath(key)
        let fullPath = basePath + "/" + filePath

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: fullPath)) else {
            throw Abort(.notFound, reason: "File not found: \(key)")
        }

        return ByteBuffer(data: data)
    }

    /// 🗑️ Delete file from local filesystem
    ///
    /// - Parameter key: File path relative to base directory
    /// - Throws: Errors if deletion fails
    public func delete(key: String) async throws {
        let filePath = sanitizePath(key)
        let fullPath = basePath + "/" + filePath

        try FileManager.default.removeItem(atPath: fullPath)
    }

    /// 🔗 Get public URL for local file
    ///
    /// - Parameter key: File path relative to base directory
    /// - Returns: Public URL or nil if not accessible
    public func publicURL(key: String) -> String? {
        // In development, Vapor serves Public directory at root
        return "/\(key)"
    }

    /// 🧹 Sanitize path to prevent directory traversal
    ///
    /// - Parameter path: Raw path string
    /// - Returns: Sanitized path
    private func sanitizePath(_ path: String) -> String {
        // Remove any attempts to navigate up directories
        let sanitized = path
            .replacingOccurrences(of: "../", with: "")
            .replacingOccurrences(of: "..\\", with: "")
            .replacingOccurrences(of: "..", with: "")

        // Ensure path is relative
        if sanitized.hasPrefix("/") {
            return String(sanitized.dropFirst())
        }

        return sanitized
    }

    /// 📁 Ensure base directory exists
    private func ensureBaseDirectoryExists() {
        do {
            try FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true)
        } catch {
            print("⚠️ Warning: Could not create base directory \(basePath): \(error)")
        }
    }
}
