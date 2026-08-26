import Foundation
import Testing
@testable import CozumelManager

final class MockWordPressAPIClient: WordPressAPIClient {
    var postsByType: [String: [WordPressPost]] = [:]
    var createdPayloads: [(postType: String, payload: WordPressPostPayload)] = []
    var updatedPayloads: [(postType: String, postId: Int, payload: WordPressPostPayload)] = []
    var failPostType: String?
    var failFetchPostType: String?

    func fetchPosts(postType: String) async throws -> [WordPressPost] {
        if postType == failFetchPostType { throw WordPressAPIError.httpError(status: 500) }
        return postsByType[postType] ?? []
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
    private func makeProperty(id: String = "prop-001", name: String = "Nah Ha 101", status: PropertyStatus = .active, unavailableDateRanges: [DateRange] = []) -> Property {
        Property(id: id, name: name, neighborhood: "North Shore", address: "123 Main St",
                  baseRate: 325, baseGuests: 2, maxGuests: 6, extraGuestFee: 25, status: status,
                  unavailableDateRanges: unavailableDateRanges)
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
        #expect(client.updatedPayloads[0].payload.meta["base_guests"] == "2")
        #expect(client.updatedPayloads[0].payload.meta["extra_guest_fee"] == "25.0")
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

    @Test func sync_reportsFailure_forEveryProperty_whenFetchPostsThrows() async {
        let client = MockWordPressAPIClient()
        client.failFetchPostType = "rental-property"
        client.postsByType["forsale-property"] = []
        let service = WordPressSyncService(apiClient: client)
        let props = [makeProperty(id: "prop-001", name: "Nah Ha 101"), makeProperty(id: "prop-002", name: "Casa Bohemia")]
        let results = await service.sync(properties: props, forSaleProperties: [makeForSaleProperty(name: "Cozumel House")])
        #expect(results.count == 3)
        for result in results.prefix(2) {
            guard case .failed = result.outcome else {
                Issue.record("Expected .failed outcome for \(result.propertyName)")
                continue
            }
        }
        let forSaleResult = results[2]
        #expect(forSaleResult.propertyName == "Cozumel House")
        guard case .failed = forSaleResult.outcome else { return }
        Issue.record("Expected for-sale property to be unaffected by rental-property fetch failure")
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

    @Test func sync_forSale_blankLocalFields_omitsKeysInsteadOfClearingThem() async {
        let client = MockWordPressAPIClient()
        let id = UUID()
        client.postsByType["forsale-property"] = [WordPressPost(id: 27, meta: .init(mac_id: id.uuidString))]
        let service = WordPressSyncService(apiClient: client)
        let blank = ForSaleProperty(id: id, name: "Cozumel House", description: "", askingPrice: 0, listingURL: "")
        _ = await service.sync(properties: [], forSaleProperties: [blank])
        let payload = client.updatedPayloads[0].payload
        #expect(payload.content == nil)
        #expect(payload.meta["asking_price"] == nil)
        #expect(payload.meta["listing_url"] == nil)
        #expect(payload.meta["notes"] == nil)
        #expect(payload.meta["mac_id"] == id.uuidString)
    }

    @Test func sync_rental_blankOrZeroLocalFields_omitsKeysInsteadOfClearingThem() async {
        let client = MockWordPressAPIClient()
        client.postsByType["rental-property"] = [WordPressPost(id: 24, meta: .init(mac_id: "prop-001"))]
        let service = WordPressSyncService(apiClient: client)
        let blank = Property(id: "prop-001", name: "Nah Ha 101", neighborhood: "", address: "",
                              baseRate: 0, status: .active)
        _ = await service.sync(properties: [blank], forSaleProperties: [])
        let payload = client.updatedPayloads[0].payload
        #expect(payload.meta["neighborhood"] == nil)
        #expect(payload.meta["address"] == nil)
        #expect(payload.meta["base_rate"] == nil)
        #expect(payload.meta["max_guests"] == nil)
        #expect(payload.meta["base_guests"] == nil)
        #expect(payload.meta["extra_guest_fee"] == nil)
        #expect(payload.meta["status"] == "active")
        #expect(payload.meta["mac_id"] == "prop-001")
    }

    @Test func sync_rental_sendsManualBlockedDatesAsJSON_withNote() async {
        let client = MockWordPressAPIClient()
        client.postsByType["rental-property"] = [WordPressPost(id: 24, meta: .init(mac_id: "prop-001"))]
        let service = WordPressSyncService(apiClient: client)
        var components = DateComponents(calendar: .current)
        components.year = 2026; components.month = 9; components.day = 10
        let start = Calendar.current.date(from: components)!
        components.day = 12
        let end = Calendar.current.date(from: components)!
        let range = DateRange(start: start, end: end, note: "Family friend — cash booking")
        let results = await service.sync(properties: [makeProperty(unavailableDateRanges: [range])], forSaleProperties: [])
        #expect(results == [SyncResult(propertyName: "Nah Ha 101", outcome: .updated)])
        let meta = client.updatedPayloads[0].payload.meta["manual_blocked_dates"]
        #expect(meta == "[{\"end\":\"2026-09-12\",\"note\":\"Family friend — cash booking\",\"start\":\"2026-09-10\"}]")
    }

    @Test func sync_rental_blockWithoutNote_omitsNoteKeyFromJSON() async {
        let client = MockWordPressAPIClient()
        client.postsByType["rental-property"] = [WordPressPost(id: 24, meta: .init(mac_id: "prop-001"))]
        let service = WordPressSyncService(apiClient: client)
        var components = DateComponents(calendar: .current)
        components.year = 2026; components.month = 9; components.day = 10
        let start = Calendar.current.date(from: components)!
        components.day = 12
        let end = Calendar.current.date(from: components)!
        let range = DateRange(start: start, end: end)
        _ = await service.sync(properties: [makeProperty(unavailableDateRanges: [range])], forSaleProperties: [])
        let meta = client.updatedPayloads[0].payload.meta["manual_blocked_dates"]
        #expect(meta == "[{\"end\":\"2026-09-12\",\"start\":\"2026-09-10\"}]")
    }

    @Test func sync_rental_noBlockedDates_sendsEmptyArray_notOmitted() async {
        let client = MockWordPressAPIClient()
        client.postsByType["rental-property"] = [WordPressPost(id: 24, meta: .init(mac_id: "prop-001"))]
        let service = WordPressSyncService(apiClient: client)
        _ = await service.sync(properties: [makeProperty(unavailableDateRanges: [])], forSaleProperties: [])
        let meta = client.updatedPayloads[0].payload.meta["manual_blocked_dates"]
        #expect(meta == "[]")
    }
}
