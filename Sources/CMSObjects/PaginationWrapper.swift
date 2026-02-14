import Vapor

/// Metadata for paginated responses.
public struct PaginationMeta: Content, Sendable, Equatable {
    /// Current page number (1-based).
    public let page: Int
    /// Number of items per page.
    public let perPage: Int
    /// Total number of items across all pages.
    public let total: Int
    /// Total number of pages.
    public let totalPages: Int

    public init(page: Int, perPage: Int, total: Int) {
        self.page = page
        self.perPage = perPage
        self.total = total
        self.totalPages = perPage > 0 ? Int((Double(total) / Double(perPage)).rounded(.up)) : 0
    }
}

/// Generic pagination wrapper for all list endpoints.
public struct PaginationWrapper<T: Content>: Content, @unchecked Sendable {
    /// The array of items for the current page.
    public let data: [T]
    /// Pagination metadata.
    public let meta: PaginationMeta

    public init(data: [T], meta: PaginationMeta) {
        self.data = data
        self.meta = meta
    }

    /// Creates a paginated wrapper from a full result set.
    /// - Parameters:
    ///   - items: All matching items (pre-paginated from DB ideally).
    ///   - page: Current page (1-based).
    ///   - perPage: Items per page.
    ///   - total: Total count of matching items.
    public static func paginate(
        items: [T],
        page: Int,
        perPage: Int,
        total: Int
    ) -> PaginationWrapper<T> {
        let meta = PaginationMeta(page: page, perPage: perPage, total: total)
        return PaginationWrapper(data: items, meta: meta)
    }
}
