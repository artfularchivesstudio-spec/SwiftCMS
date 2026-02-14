import Vapor
import NIOCore
import SotoS3

/// AWS S3 file storage provider via Soto.
public struct S3StorageProvider: FileStorageProvider, Sendable {
    let client: AWSClient
    let s3: S3
    let bucket: String

    public init(bucket: String, region: String) {
        self.bucket = bucket
        self.client = AWSClient()
        self.s3 = S3(client: client, region: .init(rawValue: region))
    }

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

    public func download(key: String) async throws -> ByteBuffer {
        let request = S3.GetObjectRequest(bucket: bucket, key: key)
        let response = try await s3.getObject(request)
        let body = try await response.body.collect(upTo: .max)
        return body
    }

    public func delete(key: String) async throws {
        let request = S3.DeleteObjectRequest(bucket: bucket, key: key)
        _ = try await s3.deleteObject(request)
    }

    public func publicURL(key: String) -> String {
        "https://\(bucket).s3.amazonaws.com/\(key)"
    }

    /// Generate a presigned URL for temporary access (1hr expiry).
    public func presignedURL(key: String, expiresIn: TimeInterval = 3600) async throws -> String {
        _ = S3.GetObjectRequest(bucket: bucket, key: key)
        let signedURL = try await s3.signURL(
            url: URL(string: "https://\(bucket).s3.amazonaws.com/\(key)")!,
            httpMethod: .GET,
            expires: .seconds(Int64(expiresIn))
        )
        return signedURL.absoluteString
    }

    /// Shutdown the AWS client.
    public func shutdown() async throws {
        try await client.shutdown()
    }
}

/// Factory to create the appropriate storage provider from environment.
public struct StorageProviderFactory {
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
