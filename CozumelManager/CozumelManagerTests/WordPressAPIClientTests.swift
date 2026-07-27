import Foundation
import Testing
@testable import CozumelManager

@Suite(.serialized)
struct WordPressAPIClientTests {
    @Test func fetchPosts_decodesArrayResponse_andSendsBasicAuth() async throws {
        let json = Data("""
        [{"id": 24, "meta": {"mac_id": "prop-001"}}]
        """.utf8)
        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.absoluteString == "http://cozumel-homes.local/wp-json/wp/v2/rental-property?per_page=100&status=any")
            #expect(request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Basic ") == true)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json)
        }
        let client = URLSessionWordPressAPIClient(
            baseURL: URL(string: "http://cozumel-homes.local")!,
            username: "akrati32",
            applicationPassword: "abcd 1234",
            session: .mockSession()
        )
        let posts = try await client.fetchPosts(postType: "rental-property")
        #expect(posts.count == 1)
        #expect(posts[0].id == 24)
        #expect(posts[0].meta.mac_id == "prop-001")
    }

    @Test func createPost_postsToCollectionEndpoint_withEncodedPayload() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        let responseJSON = Data("""
        {"id": 99, "meta": {"mac_id": "new-1"}}
        """.utf8)
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            capturedBody = request.httpBodyStream.map { stream -> Data in
                stream.open()
                defer { stream.close() }
                var data = Data()
                let bufferSize = 1024
                var buffer = [UInt8](repeating: 0, count: bufferSize)
                while stream.hasBytesAvailable {
                    let read = stream.read(&buffer, maxLength: bufferSize)
                    if read > 0 { data.append(buffer, count: read) }
                }
                return data
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (response, responseJSON)
        }
        let client = URLSessionWordPressAPIClient(
            baseURL: URL(string: "http://cozumel-homes.local")!,
            username: "akrati32",
            applicationPassword: "abcd 1234",
            session: .mockSession()
        )
        let payload = WordPressPostPayload(title: "New Listing", content: nil, status: "draft", meta: ["mac_id": "new-1"])
        let post = try await client.createPost(postType: "forsale-property", payload: payload)
        #expect(post.id == 99)
        #expect(capturedRequest?.httpMethod == "POST")
        #expect(capturedRequest?.url?.absoluteString == "http://cozumel-homes.local/wp-json/wp/v2/forsale-property")
        // WordPressPostPayload is Encodable-only (no Decodable conformance to round-trip through);
        // just confirm a non-empty body was actually sent.
        #expect((capturedBody?.count ?? 0) > 0)
    }

    @Test func updatePost_targetsSinglePostEndpoint() async throws {
        var capturedRequest: URLRequest?
        let responseJSON = Data("""
        {"id": 24, "meta": {"mac_id": "prop-001"}}
        """.utf8)
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseJSON)
        }
        let client = URLSessionWordPressAPIClient(
            baseURL: URL(string: "http://cozumel-homes.local")!,
            username: "akrati32",
            applicationPassword: "abcd 1234",
            session: .mockSession()
        )
        let payload = WordPressPostPayload(title: "Nah Ha 101", content: nil, status: nil, meta: ["base_rate": "325"])
        let post = try await client.updatePost(postType: "rental-property", postId: 24, payload: payload)
        #expect(post.id == 24)
        #expect(capturedRequest?.url?.absoluteString == "http://cozumel-homes.local/wp-json/wp/v2/rental-property/24")
    }

    @Test func fetchPosts_throwsHTTPError_onNon2xxStatus() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let client = URLSessionWordPressAPIClient(
            baseURL: URL(string: "http://cozumel-homes.local")!,
            username: "akrati32",
            applicationPassword: "wrong",
            session: .mockSession()
        )
        await #expect(throws: WordPressAPIError.self) {
            _ = try await client.fetchPosts(postType: "rental-property")
        }
    }
}
