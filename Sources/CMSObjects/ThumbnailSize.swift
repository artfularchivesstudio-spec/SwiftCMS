import Foundation

// MARK: - Thumbnail Size

/// Available thumbnail sizes.
public enum ThumbnailSize: String, CaseIterable, Codable, Sendable {
    case small = "150x150"
    case medium = "500x500"
    case large = "1000x1000"

    /// The dimensions for this thumbnail size.
    public var dimensions: (width: Int, height: Int) {
        switch self {
        case .small:
            return (150, 150)
        case .medium:
            return (500, 500)
        case .large:
            return (1000, 1000)
        }
    }

    /// Whether to crop to exact dimensions (small) or preserve aspect ratio.
    public var shouldCrop: Bool {
        self == .small
    }
}

// MARK: - Thumbnail Extensions

extension ThumbnailSize {
    /// The name of this thumbnail size for use in URLs and storage keys.
    public var storageKey: String {
        switch self {
        case .small:
            return "thumb-small"
        case .medium:
            return "thumb-medium"
        case .large:
            return "thumb-large"
        }
    }
}
