import Foundation

struct WordPressPostPayload: Encodable {
    var title: String?
    var content: String?
    var status: String?
    var meta: [String: String]
}

struct WordPressPost: Decodable {
    let id: Int
    let meta: Meta

    struct Meta: Decodable {
        let mac_id: String?
    }
}

enum WordPressAPIError: Error, Equatable {
    case invalidURL
    case httpError(status: Int)
    case decodingFailed
}

protocol WordPressAPIClient {
    func fetchPosts(postType: String) async throws -> [WordPressPost]
    func createPost(postType: String, payload: WordPressPostPayload) async throws -> WordPressPost
    func updatePost(postType: String, postId: Int, payload: WordPressPostPayload) async throws -> WordPressPost
}

final class URLSessionWordPressAPIClient: WordPressAPIClient {
    private let baseURL: URL
    private let username: String
    private let applicationPassword: String
    private let session: URLSession

    init(baseURL: URL, username: String, applicationPassword: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.username = username
        self.applicationPassword = applicationPassword
        self.session = session
    }

    private var authHeader: String {
        let raw = "\(username):\(applicationPassword)"
        return "Basic \(Data(raw.utf8).base64EncodedString())"
    }

    func fetchPosts(postType: String) async throws -> [WordPressPost] {
        guard let url = URL(string: "wp-json/wp/v2/\(postType)?per_page=100&status=any", relativeTo: baseURL) else {
            throw WordPressAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        let data = try await perform(request)
        guard let posts = try? JSONDecoder().decode([WordPressPost].self, from: data) else {
            throw WordPressAPIError.decodingFailed
        }
        return posts
    }

    func createPost(postType: String, payload: WordPressPostPayload) async throws -> WordPressPost {
        guard let url = URL(string: "wp-json/wp/v2/\(postType)", relativeTo: baseURL) else {
            throw WordPressAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        let data = try await perform(request)
        guard let post = try? JSONDecoder().decode(WordPressPost.self, from: data) else {
            throw WordPressAPIError.decodingFailed
        }
        return post
    }

    func updatePost(postType: String, postId: Int, payload: WordPressPostPayload) async throws -> WordPressPost {
        guard let url = URL(string: "wp-json/wp/v2/\(postType)/\(postId)", relativeTo: baseURL) else {
            throw WordPressAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST" // WordPress REST accepts POST for partial updates to an existing post
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)
        let data = try await perform(request)
        guard let post = try? JSONDecoder().decode(WordPressPost.self, from: data) else {
            throw WordPressAPIError.decodingFailed
        }
        return post
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw WordPressAPIError.decodingFailed
        }
        guard (200..<300).contains(http.statusCode) else {
            throw WordPressAPIError.httpError(status: http.statusCode)
        }
        return data
    }
}
