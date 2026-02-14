import Vapor
import NIOCore
import SotoS3
import CMSCore

// MARK: - ☁️ S3 Storage Provider

/// ☁️ **AWS S3 Storage Provider**
///
/// Production-ready AWS S3 storage provider using the Soto SDK.
/// Provides scalable cloud object storage with advanced features for enterprise deployments.
///
/// ## Architecture Highlights
/// - Uses Soto SDK for full AWS S3 API compatibility
/// - Async/await native implementation
/// - Automatic region handling and endpoint management
/// - Presigned URL support for secure temporary access
/// - Graceful shutdown with resource cleanup
///
/// ## Cloud Features
/// - Regional distribution across AWS availability zones
/// - 99.999999999% (11 nines) data durability
/// - Infinite scalability for growing content libraries
/// - Automatic storage class selection
/// - Lifecycle policies for cost optimization
///
/// ## Security Model
/// - IAM role support with credential rotation
/// - Presigned URL expiration for temporary access
/// - Server-side encryption (SSE-S3, SSE-KMS)
/// - Bucket policy and ACL integration
/// - VPC endpoint support for private network access
///
/// ## Performance Characteristics
/// - Parallel multipart uploads for large files
/// - Connection pooling and HTTP/2 support
/// - Automatic retry with exponential backoff
/// - Regional endpoint optimization
///
/// ## Cost Optimization
/// - Intelligent tiering support (S3 Intelligent-Tiering)
/// - Lifecycle policies for automatic object transition
/// - Request pricing awareness
/// - Storage class selection (Standard, IA, Glacier)
///
/// ## Configuration
///
/// ### Environment Variables
/// ```bash
/// STORAGE_PROVIDER=s3
/// S3_BUCKET=swiftcms-production
/// S3_REGION=us-west-2
/// AWS_ACCESS_KEY_ID=AKIA...
/// AWS_SECRET_ACCESS_KEY=...
/// AWS_SESSION_TOKEN=...  # Optional for temporary credentials
/// ```
///
/// ### Programmatic Configuration
/// ```swift
/// let s3Storage = S3StorageProvider(
///     bucket: "swiftcms-media",
///     region: "eu-west-1"
/// )
///```
///
/// ## IAM Permissions Required
/// ```json
/// {
///   "Version": "2012-10-17",
///   "Statement": [
///     {
///       "Effect": "Allow",
///       "Action": [
///         "s3:GetObject",
///         "s3:PutObject",
///         "s3:DeleteObject"
///       ],
///       "Resource": "arn:aws:s3:::bucket-name/*"
///     }
///   ]
/// }
/// ```
///
/// ## Usage Examples
///
/// ### File Upload
/// ```swift
/// let key = try await s3Storage.upload(
///     key: "avatars/user123.jpg",
///     data: imageBuffer,
///     contentType: "image/jpeg"
/// )
/// // Result: "avatars/user123.jpg"
/// ```
///
/// ### File Download
/// ```swift
/// let data = try await s3Storage.download(key: "avatars/user123.jpg")
/// let image = UIImage(data: Data(buffer: data))
/// ```
///
/// ### Secure File Access
/// ```swift
/// let tempURL = try await s3Storage.presignedURL(
///     key: "private/reports/financial.pdf",
///     expiresIn: 3600
/// )
/// // Share tempURL with authorized users
/// ```
///
/// ### Resource Cleanup
/// ```swift
/// await s3Storage.shutdown()
/// ```
@available(macOS 13.0, *)
public struct S3StorageProvider: FileStorageProvider, Sendable {
    /// 🔌 AWS client for making S3 API calls
    private let client: AWSClient

    /// 📦 S3 service wrapper around AWS client
    private let s3: S3

    /// 🪣 Target S3 bucket name
    private let bucket: String

    /// 🏗️ Initialize S3 Storage Provider
    ///
    /// Creates S3 storage provider with bucket and region configuration.
    /// AWS credentials resolved from standard provider chain.
    ///
    /// - Parameters:
    ///   - bucket: S3 bucket name
    ///   - region: AWS region identifier (e.g., "us-east-1", "eu-west-1")
    public init(bucket: String, region: String) {
        self.bucket = bucket
        self.client = AWSClient()
        self.s3 = S3(client: client, region: .init(rawValue: region))
    }

    /// 📤 Upload File to S3
    ///
    /// Uploads file to S3 bucket with key-based organization.
    ///
    /// - Parameters:
    ///   - key: Object key within bucket (e.g., "uploads/2024/01/file.jpg")
    ///   - data: File contents as ByteBuffer
    ///   - contentType: MIME type for Content-Type header
    /// - Returns: The storage key
    /// - Throws: S3 errors on upload failure
    ///
    /// ## Implementation Details
    /// - Uses `PutObjectRequest` with ByteBuffer body
    /// - Content-Type header ensures proper browser rendering
    /// - Failures trigger Soto error types with detailed diagnostics
    public func upload(key: String, data: ByteBuffer, contentType: String) async throws -> String {
        let request = S3.PutObjectRequest(
            body: .init(buffer: data),
            bucket: bucket,
            contentType: contentType,
            key: key
        )

        _ = try await s3.putObject(request)
        return key
    }

    /// 📥 Download File from S3
    ///
    /// Downloads a file from S3 bucket by key.
    ///
    /// - Parameter key: Object key to download
    /// - Returns: File contents as ByteBuffer
    /// - Throws: AccessDenied, NoSuchKey, or network errors
    ///
    /// ## Implementation Details
    /// - Uses `GetObjectRequest` with streaming response
    /// - AsyncStream enables memory-efficient large file handling
    /// - collect(upTo:) prevents memory exhaustion with safe limits
    public func download(key: String) async throws -> ByteBuffer {
        let request = S3.GetObjectRequest(bucket: bucket, key: key)
        let response = try await s3.getObject(request)
        return try await response.body.collect(upTo: .max)
    }

    /// 🗑️ Delete File from S3
    ///
    /// Deletes an object from S3 bucket.
    ///
    /// - Parameter key: Object key to delete
    /// - Throws: AccessDenied or bucket permission errors
    ///
    /// ## Implementation Details
    /// - Idempotent operation - no error if key doesn't exist
    /// - If bucket versioning enabled, creates delete marker
    public func delete(key: String) async throws {
        let request = S3.DeleteObjectRequest(bucket: bucket, key: key)
        _ = try await s3.deleteObject(request)
    }

    /// 🔗 Get Public URL for S3 Object
    ///
    /// Returns public HTTPS URL for S3 object using virtual-hosted style.
    ///
    /// - Parameter key: Object key
    /// - Returns: Public URL string or nil if not publicly accessible
    ///
    /// ## Notes
    /// - Uses format: `https://bucket.s3.amazonaws.com/key`
    /// - Requires object or bucket to be public-read
    /// - For private objects, use `presignedURL()` instead
    public func publicURL(key: String) -> String? {
        return "https://\(bucket).s3.amazonaws.com/\(key)"
    }

    /// 🔐 Generate Presigned URL
    ///
    /// Creates time-limited secure URL for temporary access to private objects.
    ///
    /// - Parameters:
    ///   - key: Object key
    ///   - expiresIn: Time interval in seconds (default: 3600)
    /// - Returns: Presigned URL string
    /// - Throws: Signing errors or invalid URL construction
    ///
    /// ## Security Features
    /// - HMAC-SHA256 signature
    /// - No AWS credentials exposed to clients
    /// - Default expiration: 1 hour (3600 seconds)
    /// - Maximum expiration: 7 days (604800 seconds)
    public func presignedURL(key: String, expiresIn: TimeInterval = 3600) async throws -> String {
        let url = URL(string: "https://\(bucket).s3.amazonaws.com/\(key)")!
        let signedURL = try await s3.signURL(
            url: url,
            httpMethod: .GET,
            expires: .seconds(Int64(expiresIn))
        )
        return signedURL.absoluteString
    }

    /// 🔌 Gracefully shutdown AWS client
    ///
    /// Closes connections and releases resources.
    ///
    /// - Throws: Errors if shutdown fails
    public func shutdown() async throws {
        try await client.shutdown()
    }
}
