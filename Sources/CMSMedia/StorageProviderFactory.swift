import Vapor
import CMSCore

// MARK: - 🏭 Storage Provider Factory

/// 🏭 **Storage Provider Factory**
///
/// Factory for creating appropriate storage provider from environment configuration.
/// Supports multiple backends with zero-downtime switching.
///
/// ## Provider Selection Logic
/// - Checks `STORAGE_PROVIDER` environment variable
/// - Defaults to `local` for development
/// - Case-insensitive matching
///
/// ## Supported Providers
/// - `s3` → AWS S3 object storage
/// - `local` → Local filesystem storage
///
/// ## Environment Configuration
///
/// ### S3 Configuration
/// ```bash
/// STORAGE_PROVIDER=s3
/// S3_BUCKET=swiftcms-production
/// S3_REGION=us-west-2
/// AWS_ACCESS_KEY_ID=your-key
/// AWS_SECRET_ACCESS_KEY=your-secret
/// ```
///
/// ### Local Configuration
/// ```bash
/// STORAGE_PROVIDER=local
/// ```
///
/// ## Usage
/// ```swift
/// // In configure.swift
/// app.fileStorage = StorageProviderFactory.create()
///```
@available(macOS 13.0, *)
public struct StorageProviderFactory {
    /// 🔄 Create storage provider from environment
    ///
    /// Automatically selects and configures provider based on environment variables.
    ///
    /// - Returns: Configured FileStorageProvider instance
    public static func create() -> FileStorageProvider {
        let provider = Environment.get("STORAGE_PROVIDER") ?? "local"

        switch provider.lowercased() {
        case "s3":
            let bucket = Environment.get("S3_BUCKET") ?? "swiftcms-media"
            let region = Environment.get("S3_REGION") ?? "us-east-1"
            return S3StorageProvider(bucket: bucket, region: region)

        default:
            return LocalStorageProvider()
        }
    }
}
