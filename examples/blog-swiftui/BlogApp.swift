import SwiftUI

// Example SwiftUI app consuming SwiftCMS API

struct BlogPost: Codable, Identifiable {
    let id: UUID
    let contentType: String
    let data: PostData
    let status: String
    let createdAt: String

    struct PostData: Codable {
        let title: String
        let body: String
        let author: String?
        let tags: [String]?
    }
}

struct PaginatedPosts: Codable {
    let data: [BlogPost]
    let meta: Meta
    struct Meta: Codable {
        let page: Int
        let perPage: Int
        let total: Int
        let totalPages: Int
    }
}

class BlogViewModel: ObservableObject {
    @Published var posts: [BlogPost] = []
    @Published var isLoading = false

    let baseURL = "http://localhost:8080/api/v1"

    func loadPosts() async {
        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: "\(baseURL)/posts?status=published&perPage=20") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let result = try JSONDecoder().decode(PaginatedPosts.self, from: data)
            await MainActor.run { posts = result.data }
        } catch {
            print("Error loading posts: \(error)")
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = BlogViewModel()

    var body: some View {
        NavigationStack {
            List(viewModel.posts) { post in
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.data.title).font(.headline)
                    Text(post.data.body).font(.body).lineLimit(2).foregroundStyle(.secondary)
                    if let tags = post.data.tags, !tags.isEmpty {
                        HStack {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag).font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.blue.opacity(0.1)).cornerRadius(4)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Blog")
            .task { await viewModel.loadPosts() }
            .refreshable { await viewModel.loadPosts() }
        }
    }
}

@main
struct BlogApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
