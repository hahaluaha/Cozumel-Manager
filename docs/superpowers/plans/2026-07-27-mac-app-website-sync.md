# Mac App → WordPress Sync (Plan B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a manual "Sync to Website" action to the Mac app that pushes rental and for-sale property data to the companion WordPress site over its REST API.

**Architecture:** A new `WordPressAPIClient` protocol wraps WP REST calls (GET/POST for `rental-property` and `forsale-property`) behind a `URLSessionWordPressAPIClient` implementation, testable via a mock `URLProtocol`. A `WordPressSyncService` matches Mac-app properties to WP posts by `mac_id` meta and creates/updates accordingly, testable via a mock `WordPressAPIClient`. Credentials live in Keychain via `WordPressSyncCredentialsStore`. SwiftUI wiring (settings sheet, results sheet, toolbar button) lives in `Views/`, following the existing sheet/toolbar patterns already in `SidebarView.swift`.

**Tech Stack:** Swift, SwiftUI, `URLSession`, `Security` framework (Keychain), Swift Testing (`@Test`/`#expect`, matching the existing test suite).

## Global Constraints

- One-way sync only: Mac app → WordPress. WordPress is never read back into the Mac app. (spec: Sync Direction & Trigger)
- Trigger is a single manual "Sync to Website" button that syncs every rental and for-sale property in one pass — no per-property button, no automatic/scheduled sync. (spec: Sync Direction & Trigger)
- Target is `http://cozumel-homes.local` only for this pass — no production URL/HTTPS handling yet. (spec: Sync Direction & Trigger)
- New WordPress posts (no `mac_id` match) are created as **draft**, never auto-published. (spec: New-Post Behavior)
- On update, only the `status` **meta** field changes — the WordPress post's own publish state is never touched by sync. (spec: Status Mapping)
- Credentials (site URL, WP username, Application Password) are stored in macOS Keychain only — never in `properties.json`, never hardcoded. (spec: Credential Storage)
- Only fields with a source of truth in the Mac app's data model are synced: rentals get `neighborhood`, `address`, `base_rate`, `status`, `max_guests`; for-sale gets `description`→content, `asking_price`, `listing_url`, `notes`. `bedrooms`, `bathrooms`, `latitude`, `longitude`, `airbnb_ical_url`, `airbnb_listing_url`, `gallery_ids`, photos, video are never touched by sync. (spec: Field Mapping)
- One property's sync failure must not stop the rest — every property in the pass is attempted regardless of earlier failures. (spec: Error Handling)

---

### Task 1: `SyncResult` model

**Files:**
- Create: `CozumelManager/CozumelManager/Models/SyncResult.swift`
- Test: `CozumelManager/CozumelManagerTests/SyncResultTests.swift`

**Interfaces:**
- Produces: `enum SyncOutcome: Equatable { case created; case updated; case failed(String) }`, `struct SyncResult: Identifiable, Equatable { let id: UUID; let propertyName: String; let outcome: SyncOutcome }` — later tasks construct `SyncResult(propertyName:outcome:)` and compare results with `==` (comparing `propertyName`/`outcome` only, not `id`).

- [ ] **Step 1: Write the failing test**

```swift
import Foundation
import Testing
@testable import CozumelManager

struct SyncResultTests {
    @Test func equality_ignoresId_comparesNameAndOutcome() {
        let a = SyncResult(propertyName: "Nah Ha 101", outcome: .updated)
        let b = SyncResult(propertyName: "Nah Ha 101", outcome: .updated)
        #expect(a == b)
        #expect(a.id != b.id)
    }

    @Test func equality_differsOnDifferentOutcome() {
        let a = SyncResult(propertyName: "Nah Ha 101", outcome: .created)
        let b = SyncResult(propertyName: "Nah Ha 101", outcome: .updated)
        #expect(a != b)
    }

    @Test func failedOutcome_carriesReason() {
        let result = SyncResult(propertyName: "Casa Bohemia", outcome: .failed("401 Unauthorized"))
        guard case .failed(let reason) = result.outcome else {
            Issue.record("Expected .failed outcome")
            return
        }
        #expect(reason == "401 Unauthorized")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/fernandogonzalez/Documents/Cozumel_App_Final/CozumelManager && xcodebuild test -project CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/SyncResultTests 2>&1 | tail -30`
Expected: FAIL — `cannot find 'SyncResult' in scope` (or similar compile error, since the type doesn't exist yet)

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

enum SyncOutcome: Equatable {
    case created
    case updated
    case failed(String)
}

struct SyncResult: Identifiable, Equatable {
    let id = UUID()
    let propertyName: String
    let outcome: SyncOutcome

    static func == (lhs: SyncResult, rhs: SyncResult) -> Bool {
        lhs.propertyName == rhs.propertyName && lhs.outcome == rhs.outcome
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/fernandogonzalez/Documents/Cozumel_App_Final/CozumelManager && xcodebuild test -project CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/SyncResultTests 2>&1 | tail -30`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add CozumelManager/CozumelManager/Models/SyncResult.swift CozumelManager/CozumelManagerTests/SyncResultTests.swift
git commit -m "feat: add SyncResult model for Plan B sync"
```

---

### Task 2: `WordPressAPIClient` — REST client for WordPress

**Files:**
- Create: `CozumelManager/CozumelManager/Support/WordPressAPIClient.swift`
- Test: `CozumelManager/CozumelManagerTests/MockURLProtocol.swift`
- Test: `CozumelManager/CozumelManagerTests/WordPressAPIClientTests.swift`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces:
  - `struct WordPressPostPayload: Encodable { var title: String?; var content: String?; var status: String?; var meta: [String: String] }`
  - `struct WordPressPost: Decodable { let id: Int; let meta: Meta }` with nested `struct Meta: Decodable { let mac_id: String? }`
  - `enum WordPressAPIError: Error, Equatable { case invalidURL; case httpError(status: Int); case decodingFailed }`
  - `protocol WordPressAPIClient { func fetchPosts(postType: String) async throws -> [WordPressPost]; func createPost(postType: String, payload: WordPressPostPayload) async throws -> WordPressPost; func updatePost(postType: String, postId: Int, payload: WordPressPostPayload) async throws -> WordPressPost }`
  - `final class URLSessionWordPressAPIClient: WordPressAPIClient` with `init(baseURL: URL, username: String, applicationPassword: String, session: URLSession = .shared)`
  - Test-only: `final class MockURLProtocol: URLProtocol` with `static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?`, and `extension URLSession { static func mockSession() -> URLSession }` — Task 4's test file does not need this, but any future networking test can reuse it.

This task is used later by Task 4 (`WordPressSyncService` is constructed with a `WordPressAPIClient`) and Task 7 (SidebarView constructs a real `URLSessionWordPressAPIClient`).

- [ ] **Step 1: Write the test support file (mock URLProtocol)**

```swift
import Foundation

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("MockURLProtocol.requestHandler not set")
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

extension URLSession {
    static func mockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
```

- [ ] **Step 2: Write the failing tests**

```swift
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
        let decodedBody = try? JSONDecoder().decode(WordPressPostPayload.self, from: capturedBody ?? Data())
        #expect(decodedBody == nil) // WordPressPostPayload is Encodable-only; just confirm a body was actually sent
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
```

Note: `WordPressPostPayload` is `Encodable` only in Step 3 below, so the `createPost` test confirms a non-empty body was sent rather than round-tripping it through a decoder (there is no `Decodable` conformance to round-trip with).

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd /Users/fernandogonzalez/Documents/Cozumel_App_Final/CozumelManager && xcodebuild test -project CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/WordPressAPIClientTests 2>&1 | tail -30`
Expected: FAIL — `cannot find 'URLSessionWordPressAPIClient' in scope`

- [ ] **Step 4: Write minimal implementation**

```swift
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd /Users/fernandogonzalez/Documents/Cozumel_App_Final/CozumelManager && xcodebuild test -project CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/WordPressAPIClientTests 2>&1 | tail -30`
Expected: PASS (4 tests)

- [ ] **Step 6: Commit**

```bash
git add CozumelManager/CozumelManager/Support/WordPressAPIClient.swift CozumelManager/CozumelManagerTests/MockURLProtocol.swift CozumelManager/CozumelManagerTests/WordPressAPIClientTests.swift
git commit -m "feat: add WordPress REST API client for Plan B sync"
```

---

### Task 3: `WordPressSyncCredentialsStore` — Keychain-backed credential storage

**Files:**
- Create: `CozumelManager/CozumelManager/Support/WordPressSyncCredentialsStore.swift`
- Test: `CozumelManager/CozumelManagerTests/WordPressSyncCredentialsStoreTests.swift`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `struct WordPressSyncCredentials: Codable, Equatable { var siteURL: String; var username: String; var applicationPassword: String }`, `final class WordPressSyncCredentialsStore { init(service: String = "Team-Paraiso.CozumelManager.wordpress-sync"); func save(_ credentials: WordPressSyncCredentials) throws; func load() -> WordPressSyncCredentials?; func clear() }`. Task 6 (settings sheet) and Task 7 (SidebarView sync action) both construct `WordPressSyncCredentialsStore()` with the default service string and call `save`/`load`.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import CozumelManager

struct WordPressSyncCredentialsStoreTests {
    @Test func save_thenLoad_returnsSameCredentials() throws {
        let store = WordPressSyncCredentialsStore(service: "test.\(UUID().uuidString)")
        let creds = WordPressSyncCredentials(siteURL: "http://cozumel-homes.local", username: "akrati32", applicationPassword: "abcd 1234 efgh 5678")
        try store.save(creds)
        #expect(store.load() == creds)
        store.clear()
    }

    @Test func load_returnsNil_whenNothingSaved() {
        let store = WordPressSyncCredentialsStore(service: "test.\(UUID().uuidString)")
        #expect(store.load() == nil)
    }

    @Test func save_overwritesPreviousValue() throws {
        let store = WordPressSyncCredentialsStore(service: "test.\(UUID().uuidString)")
        try store.save(WordPressSyncCredentials(siteURL: "http://a.local", username: "a", applicationPassword: "a"))
        try store.save(WordPressSyncCredentials(siteURL: "http://b.local", username: "b", applicationPassword: "b"))
        #expect(store.load()?.siteURL == "http://b.local")
        store.clear()
    }

    @Test func clear_removesStoredCredentials() throws {
        let store = WordPressSyncCredentialsStore(service: "test.\(UUID().uuidString)")
        try store.save(WordPressSyncCredentials(siteURL: "http://a.local", username: "a", applicationPassword: "a"))
        store.clear()
        #expect(store.load() == nil)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/fernandogonzalez/Documents/Cozumel_App_Final/CozumelManager && xcodebuild test -project CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/WordPressSyncCredentialsStoreTests 2>&1 | tail -30`
Expected: FAIL — `cannot find 'WordPressSyncCredentialsStore' in scope`

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation
import Security

struct WordPressSyncCredentials: Codable, Equatable {
    var siteURL: String
    var username: String
    var applicationPassword: String
}

enum WordPressSyncCredentialsError: Error {
    case keychainError(OSStatus)
}

final class WordPressSyncCredentialsStore {
    private let service: String
    private let account = "wordpress-sync"

    init(service: String = "Team-Paraiso.CozumelManager.wordpress-sync") {
        self.service = service
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    func save(_ credentials: WordPressSyncCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        SecItemDelete(baseQuery as CFDictionary)
        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw WordPressSyncCredentialsError.keychainError(status)
        }
    }

    func load() -> WordPressSyncCredentials? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(WordPressSyncCredentials.self, from: data)
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/fernandogonzalez/Documents/Cozumel_App_Final/CozumelManager && xcodebuild test -project CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/WordPressSyncCredentialsStoreTests 2>&1 | tail -30`
Expected: PASS (4 tests). **If any test fails with `errSecMissingEntitlement` or a similar Keychain access error**: add `com.apple.security.keychain-access-groups` to `CozumelManager/CozumelManager/CozumelManager.entitlements` (per `CLAUDE.md`: add new entitlements to the `.entitlements` file, not build settings) with the app's own team-prefixed group, then re-run.

- [ ] **Step 5: Commit**

```bash
git add CozumelManager/CozumelManager/Support/WordPressSyncCredentialsStore.swift CozumelManager/CozumelManagerTests/WordPressSyncCredentialsStoreTests.swift
git commit -m "feat: add Keychain-backed credential storage for Plan B sync"
```

---

### Task 4: `WordPressSyncService` — matching and sync orchestration

**Files:**
- Create: `CozumelManager/CozumelManager/Support/WordPressSyncService.swift`
- Test: `CozumelManager/CozumelManagerTests/WordPressSyncServiceTests.swift`

**Interfaces:**
- Consumes: `WordPressAPIClient` protocol, `WordPressPost`, `WordPressPostPayload`, `WordPressAPIError` (Task 2); `SyncResult`, `SyncOutcome` (Task 1); `Property`, `PropertyStatus` (existing `Models/Property.swift`); `ForSaleProperty` (existing `Models/ForSaleProperty.swift`).
- Produces: `final class WordPressSyncService { init(apiClient: WordPressAPIClient); func sync(properties: [Property], forSaleProperties: [ForSaleProperty]) async -> [SyncResult] }`. Task 7 constructs this with a real `URLSessionWordPressAPIClient` and calls `sync(properties:forSaleProperties:)`.

- [ ] **Step 1: Write the failing tests**

```swift
import Foundation
import Testing
@testable import CozumelManager

final class MockWordPressAPIClient: WordPressAPIClient {
    var postsByType: [String: [WordPressPost]] = [:]
    var createdPayloads: [(postType: String, payload: WordPressPostPayload)] = []
    var updatedPayloads: [(postType: String, postId: Int, payload: WordPressPostPayload)] = []
    var failPostType: String?

    func fetchPosts(postType: String) async throws -> [WordPressPost] {
        postsByType[postType] ?? []
    }

    func createPost(postType: String, payload: WordPressPostPayload) async throws -> WordPressPost {
        if postType == failPostType { throw WordPressAPIError.httpError(status: 401) }
        createdPayloads.append((postType, payload))
        return WordPressPost(id: 999, meta: .init(mac_id: payload.meta["mac_id"]))
    }

    func updatePost(postType: String, postId: Int, payload: WordPressPostPayload) async throws -> WordPressPost {
        if postType == failPostType { throw WordPressAPIError.httpError(status: 401) }
        updatedPayloads.append((postType, postId, payload))
        return WordPressPost(id: postId, meta: .init(mac_id: payload.meta["mac_id"]))
    }
}

struct WordPressSyncServiceTests {
    private func makeProperty(id: String = "prop-001", name: String = "Nah Ha 101", status: PropertyStatus = .active) -> Property {
        Property(id: id, name: name, neighborhood: "North Shore", address: "123 Main St",
                  baseRate: 325, maxGuests: 6, status: status)
    }

    private func makeForSaleProperty(id: UUID = UUID(), name: String = "Cozumel House") -> ForSaleProperty {
        ForSaleProperty(id: id, name: name, description: "A nice house", askingPrice: 550000, listingURL: "https://example.com/listing")
    }

    @Test func sync_updatesExistingRental_matchedByMacId() async {
        let client = MockWordPressAPIClient()
        client.postsByType["rental-property"] = [WordPressPost(id: 24, meta: .init(mac_id: "prop-001"))]
        let service = WordPressSyncService(apiClient: client)
        let results = await service.sync(properties: [makeProperty()], forSaleProperties: [])
        #expect(results == [SyncResult(propertyName: "Nah Ha 101", outcome: .updated)])
        #expect(client.updatedPayloads.count == 1)
        #expect(client.updatedPayloads[0].postId == 24)
        #expect(client.updatedPayloads[0].payload.meta["base_rate"] == "325.0")
    }

    @Test func sync_createsNewRentalAsDraft_whenNoMacIdMatch() async {
        let client = MockWordPressAPIClient()
        client.postsByType["rental-property"] = []
        let service = WordPressSyncService(apiClient: client)
        let results = await service.sync(properties: [makeProperty()], forSaleProperties: [])
        #expect(results == [SyncResult(propertyName: "Nah Ha 101", outcome: .created)])
        #expect(client.createdPayloads.count == 1)
        #expect(client.createdPayloads[0].payload.status == "draft")
        #expect(client.createdPayloads[0].payload.meta["mac_id"] == "prop-001")
    }

    @Test func sync_reportsFailure_withoutStoppingOtherProperties() async {
        let client = MockWordPressAPIClient()
        client.postsByType["rental-property"] = []
        client.failPostType = "rental-property"
        let service = WordPressSyncService(apiClient: client)
        let props = [makeProperty(id: "prop-001", name: "Nah Ha 101"), makeProperty(id: "prop-002", name: "Casa Bohemia")]
        let results = await service.sync(properties: props, forSaleProperties: [])
        #expect(results.count == 2)
        for result in results {
            guard case .failed = result.outcome else {
                Issue.record("Expected .failed outcome for \(result.propertyName)")
                continue
            }
        }
    }

    @Test func sync_mapsStatusToMetaOnly_neverSetsPostStatusOnUpdate() async {
        let client = MockWordPressAPIClient()
        client.postsByType["rental-property"] = [WordPressPost(id: 24, meta: .init(mac_id: "prop-001"))]
        let service = WordPressSyncService(apiClient: client)
        let results = await service.sync(properties: [makeProperty(status: .inactive)], forSaleProperties: [])
        #expect(results == [SyncResult(propertyName: "Nah Ha 101", outcome: .updated)])
        #expect(client.updatedPayloads[0].payload.meta["status"] == "inactive")
        #expect(client.updatedPayloads[0].payload.status == nil)
    }

    @Test func sync_forSale_matchesByUUIDStringMacId_andSendsDescriptionAsContent() async {
        let client = MockWordPressAPIClient()
        let id = UUID()
        client.postsByType["forsale-property"] = [WordPressPost(id: 27, meta: .init(mac_id: id.uuidString))]
        let service = WordPressSyncService(apiClient: client)
        let results = await service.sync(properties: [], forSaleProperties: [makeForSaleProperty(id: id)])
        #expect(results == [SyncResult(propertyName: "Cozumel House", outcome: .updated)])
        #expect(client.updatedPayloads[0].payload.content == "A nice house")
        #expect(client.updatedPayloads[0].payload.meta["asking_price"] == "550000.0")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/fernandogonzalez/Documents/Cozumel_App_Final/CozumelManager && xcodebuild test -project CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/WordPressSyncServiceTests 2>&1 | tail -30`
Expected: FAIL — `cannot find 'WordPressSyncService' in scope`

- [ ] **Step 3: Write minimal implementation**

```swift
import Foundation

final class WordPressSyncService {
    private let apiClient: WordPressAPIClient

    init(apiClient: WordPressAPIClient) {
        self.apiClient = apiClient
    }

    func sync(properties: [Property], forSaleProperties: [ForSaleProperty]) async -> [SyncResult] {
        var results: [SyncResult] = []
        results.append(contentsOf: await syncRentals(properties))
        results.append(contentsOf: await syncForSale(forSaleProperties))
        return results
    }

    private func syncRentals(_ properties: [Property]) async -> [SyncResult] {
        guard let existing = try? await apiClient.fetchPosts(postType: "rental-property") else {
            return properties.map { SyncResult(propertyName: $0.name, outcome: .failed("Could not fetch existing rental posts")) }
        }
        var results: [SyncResult] = []
        for property in properties {
            let payload = WordPressPostPayload(
                title: property.name,
                content: nil,
                status: nil,
                meta: [
                    "mac_id": property.id,
                    "neighborhood": property.neighborhood,
                    "address": property.address,
                    "base_rate": String(property.baseRate),
                    "status": property.status.rawValue,
                    "max_guests": property.maxGuests.map(String.init) ?? ""
                ]
            )
            results.append(await syncPost(postType: "rental-property", macId: property.id, name: property.name, existing: existing, payload: payload))
        }
        return results
    }

    private func syncForSale(_ properties: [ForSaleProperty]) async -> [SyncResult] {
        guard let existing = try? await apiClient.fetchPosts(postType: "forsale-property") else {
            return properties.map { SyncResult(propertyName: $0.name, outcome: .failed("Could not fetch existing for-sale posts")) }
        }
        var results: [SyncResult] = []
        for property in properties {
            let macId = property.id.uuidString
            let payload = WordPressPostPayload(
                title: property.name,
                content: property.description,
                status: nil,
                meta: [
                    "mac_id": macId,
                    "asking_price": String(property.askingPrice),
                    "listing_url": property.listingURL,
                    "notes": property.notes
                ]
            )
            results.append(await syncPost(postType: "forsale-property", macId: macId, name: property.name, existing: existing, payload: payload))
        }
        return results
    }

    private func syncPost(postType: String, macId: String, name: String, existing: [WordPressPost], payload: WordPressPostPayload) async -> SyncResult {
        do {
            if let match = existing.first(where: { $0.meta.mac_id == macId }) {
                _ = try await apiClient.updatePost(postType: postType, postId: match.id, payload: payload)
                return SyncResult(propertyName: name, outcome: .updated)
            } else {
                var createPayload = payload
                createPayload.status = "draft"
                _ = try await apiClient.createPost(postType: postType, payload: createPayload)
                return SyncResult(propertyName: name, outcome: .created)
            }
        } catch {
            return SyncResult(propertyName: name, outcome: .failed("\(error)"))
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/fernandogonzalez/Documents/Cozumel_App_Final/CozumelManager && xcodebuild test -project CozumelManager.xcodeproj -scheme CozumelManager -destination 'platform=macOS' -only-testing:CozumelManagerTests/WordPressSyncServiceTests 2>&1 | tail -30`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add CozumelManager/CozumelManager/Support/WordPressSyncService.swift CozumelManager/CozumelManagerTests/WordPressSyncServiceTests.swift
git commit -m "feat: add WordPressSyncService matching/create/update orchestration"
```

---

### Task 5: `WebsiteSyncSettingsSheet` — credential entry UI

**Files:**
- Create: `CozumelManager/CozumelManager/Views/WebsiteSyncSettingsSheet.swift`

**Interfaces:**
- Consumes: `WordPressSyncCredentialsStore`, `WordPressSyncCredentials` (Task 3).
- Produces: `struct WebsiteSyncSettingsSheet: View { init(store: WordPressSyncCredentialsStore = WordPressSyncCredentialsStore()) }`. Task 7 presents this as a sheet from `SidebarView`.

No automated tests for this step — the existing test suite has no coverage of SwiftUI views (`AddPropertySheet`, `AddUserPlaceholderSheet`, etc. are all manually verified only), so this follows the established pattern. Manual verification happens in Task 7 once the sheet is wired into the toolbar.

- [ ] **Step 1: Write the view**

```swift
import SwiftUI

struct WebsiteSyncSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var siteURL: String
    @State private var username: String
    @State private var applicationPassword: String = ""
    private let store: WordPressSyncCredentialsStore

    init(store: WordPressSyncCredentialsStore = WordPressSyncCredentialsStore()) {
        self.store = store
        let existing = store.load()
        _siteURL = State(initialValue: existing?.siteURL ?? "http://cozumel-homes.local")
        _username = State(initialValue: existing?.username ?? "")
    }

    private var canSave: Bool {
        !siteURL.isEmpty && !username.isEmpty && !applicationPassword.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Website Sync Settings")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Generate an Application Password in wp-admin under Users → Profile, then paste it below.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Site URL", text: $siteURL)
                .textFieldStyle(.roundedBorder)
            TextField("WordPress Username", text: $username)
                .textFieldStyle(.roundedBorder)
            SecureField("Application Password", text: $applicationPassword)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    try? store.save(WordPressSyncCredentials(siteURL: siteURL, username: username, applicationPassword: applicationPassword))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `cd /Users/fernandogonzalez/Documents/Cozumel_App_Final/CozumelManager && xcodebuild -project CozumelManager.xcodeproj -scheme CozumelManager -configuration Debug -derivedDataPath /tmp/cozumel-build build 2>&1 | tail -30`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add CozumelManager/CozumelManager/Views/WebsiteSyncSettingsSheet.swift
git commit -m "feat: add website sync settings sheet"
```

---

### Task 6: `SyncResultsSheet` — sync result display UI

**Files:**
- Create: `CozumelManager/CozumelManager/Views/SyncResultsSheet.swift`

**Interfaces:**
- Consumes: `SyncResult`, `SyncOutcome` (Task 1).
- Produces: `struct SyncResultsSheet: View { let results: [SyncResult] }`. Task 7 presents this as a sheet from `SidebarView` after a sync run completes.

No automated tests — same reasoning as Task 5 (no existing view-test coverage in this codebase).

- [ ] **Step 1: Write the view**

```swift
import SwiftUI

struct SyncResultsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let results: [SyncResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Results")
                .font(.title2)
                .fontWeight(.semibold)
            List(results) { result in
                HStack {
                    Text(result.propertyName)
                    Spacer()
                    Text(label(for: result.outcome))
                        .foregroundStyle(color(for: result.outcome))
                }
            }
            .frame(minHeight: 200)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func label(for outcome: SyncOutcome) -> String {
        switch outcome {
        case .created: return "Created"
        case .updated: return "Updated"
        case .failed(let reason): return "Failed — \(reason)"
        }
    }

    private func color(for outcome: SyncOutcome) -> Color {
        switch outcome {
        case .created, .updated: return .green
        case .failed: return .red
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `cd /Users/fernandogonzalez/Documents/Cozumel_App_Final/CozumelManager && xcodebuild -project CozumelManager.xcodeproj -scheme CozumelManager -configuration Debug -derivedDataPath /tmp/cozumel-build build 2>&1 | tail -30`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add CozumelManager/CozumelManager/Views/SyncResultsSheet.swift
git commit -m "feat: add sync results display sheet"
```

---

### Task 7: Wire "Sync to Website" into `SidebarView`

**Files:**
- Modify: `CozumelManager/CozumelManager/Views/SidebarView.swift`

**Interfaces:**
- Consumes: `WordPressSyncCredentialsStore` (Task 3), `URLSessionWordPressAPIClient` (Task 2), `WordPressSyncService` (Task 4), `WebsiteSyncSettingsSheet` (Task 5), `SyncResultsSheet` (Task 6), `store.properties` / `forSaleStore.properties` (existing `@EnvironmentObject`s already present in `SidebarView`).
- Produces: nothing consumed by later tasks — this is the final integration point.

No automated tests — this task wires existing tested pieces (Tasks 1–4 have unit coverage; the orchestration itself has no new logic beyond what Task 4 already tests) into a SwiftUI view, consistent with the rest of `SidebarView`'s untested toolbar/sheet code. Verified manually against the running local WordPress site.

- [ ] **Step 1: Add sync state and toolbar menu item**

In `CozumelManager/CozumelManager/Views/SidebarView.swift`, add new `@State` properties alongside the existing ones (after line 19, `@State private var showDeleteForSaleAlert = false`):

```swift
    @State private var showSyncSettings = false
    @State private var showSyncResults = false
    @State private var syncResults: [SyncResult] = []
    @State private var isSyncing = false
```

Then add a new `ToolbarItem` inside the existing `.toolbar { ... }` block (after the "Add" `Menu` `ToolbarItem`, around line 73):

```swift
            ToolbarItem {
                Menu {
                    Button("Sync to Website") { performSync() }
                        .disabled(isSyncing)
                    Button("Website Sync Settings…") { showSyncSettings = true }
                } label: {
                    if isSyncing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }
```

- [ ] **Step 2: Add the sync action and sheets**

Add a private method to `SidebarView` (after the `body` property, before the closing brace of the struct):

```swift
    private func performSync() {
        guard let credentials = WordPressSyncCredentialsStore().load(),
              let baseURL = URL(string: credentials.siteURL) else {
            showSyncSettings = true
            return
        }
        isSyncing = true
        let client = URLSessionWordPressAPIClient(
            baseURL: baseURL,
            username: credentials.username,
            applicationPassword: credentials.applicationPassword
        )
        let service = WordPressSyncService(apiClient: client)
        let propertiesSnapshot = store.properties
        let forSalePropertiesSnapshot = forSaleStore.properties
        Task {
            let results = await service.sync(properties: propertiesSnapshot, forSaleProperties: forSalePropertiesSnapshot)
            await MainActor.run {
                syncResults = results
                isSyncing = false
                showSyncResults = true
            }
        }
    }
```

Then add two more `.sheet` modifiers alongside the existing three (`.sheet(isPresented: $showAddProperty)`, etc., after line 101's closing of the `showAddUser` sheet):

```swift
        .sheet(isPresented: $showSyncSettings) {
            WebsiteSyncSettingsSheet()
        }
        .sheet(isPresented: $showSyncResults) {
            SyncResultsSheet(results: syncResults)
        }
```

- [ ] **Step 3: Build**

Run: `cd /Users/fernandogonzalez/Documents/Cozumel_App_Final/CozumelManager && xcodebuild -project CozumelManager.xcodeproj -scheme CozumelManager -configuration Debug -derivedDataPath /tmp/cozumel-build build 2>&1 | tail -30`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Manual verification against the local WordPress site**

Confirm Local by Flywheel is running (`cozumel-homes.local` reachable — `curl -s -o /dev/null -w '%{http_code}\n' http://cozumel-homes.local/wp-json/wp/v2/rental-property` should print `200`). Generate a fresh Application Password in wp-admin (Users → Profile → Application Passwords) since any prior one was revoked earlier this session. Then, running the app (`Cmd+R` in Xcode, or launch the built `.app` from `/tmp/cozumel-build`):

1. Open the sidebar's new sync menu (the circular-arrows icon) → "Website Sync Settings…". Enter the site URL, username, and the fresh Application Password. Save.
2. Open the sync menu again → "Sync to Website". Confirm the button shows a progress spinner while running, then a results sheet appears listing all 3 rentals + 1 for-sale property.
3. In wp-admin, confirm Nah Ha 101 / Casa Bohemia / Cool Caribbean Views / Cozumel House for Sale's `base_rate`/`asking_price`/etc. meta fields match the Mac app's current values, and that none of them changed publish status.
4. In the Mac app, add a new test rental property with a name that doesn't exist in WordPress yet. Run sync again. Confirm a new **draft** `rental-property` post appears in wp-admin with the correct `mac_id`, and that it is NOT published. Delete this test property from the Mac app and the draft post from wp-admin afterward (cleanup, not part of the app's behavior).
5. In wp-admin, revoke the Application Password. Run sync again from the Mac app. Confirm the results sheet shows every property as "Failed — ..." rather than crashing or silently doing nothing.
6. Confirm fields outside the sync scope (`latitude`, `longitude`, `bedrooms`, `bathrooms`, `gallery_ids`, `airbnb_listing_url`) are unchanged in wp-admin after a sync run — they should still hold the values set manually earlier this session (e.g. Casa Dale's `20.4957323`/`-86.9519944`).

- [ ] **Step 5: Commit**

```bash
git add CozumelManager/CozumelManager/Views/SidebarView.swift
git commit -m "feat: wire Sync to Website button into SidebarView"
```

---

## Self-Review Notes

- **Spec coverage:** Sync direction/trigger → Task 7. Field mapping (rentals + for-sale) → Task 4. Credential storage → Task 3. New-post draft behavior → Task 4 (`createPayload.status = "draft"`), verified manually in Task 7 Step 4. Status mapping (meta-only, no publish-state change) → Task 4, tested explicitly in `sync_mapsStatusToMetaOnly_neverSetsPostStatusOnUpdate`. Error handling (one failure doesn't stop the rest) → Task 4, tested in `sync_reportsFailure_withoutStoppingOtherProperties`. Local-dev-only target → Task 7's manual verification targets `cozumel-homes.local` exclusively; no production URL logic was introduced. HTTPS-for-production note from the spec's security addendum is a future-work flag, not something this plan implements (correctly out of scope per the spec).
- **Type consistency check:** `WordPressPost.Meta.mac_id`, `WordPressPostPayload.meta`, `SyncResult.outcome`, and `WordPressSyncService.sync(properties:forSaleProperties:)` are used identically across Tasks 2, 4, and 7 — no signature drift.
- **No placeholders:** every step above contains complete, compilable code — none deferred to "similar to Task N."
