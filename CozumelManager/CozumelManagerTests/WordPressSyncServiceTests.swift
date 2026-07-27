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
