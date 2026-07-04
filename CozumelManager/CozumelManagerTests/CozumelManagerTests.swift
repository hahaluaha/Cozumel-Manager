import Foundation
import Testing
@testable import CozumelManager

struct PropertyModelTests {

    @Test func property_decodesLegacyJSON_withEmptyDefaults() throws {
        let json = """
        {"id":"p1","name":"Test","neighborhood":"N","address":"A","base_rate":100.0,"status":"active"}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let p = try decoder.decode(Property.self, from: json)
        #expect(p.unavailableDateRanges.isEmpty)
        #expect(p.photos.isEmpty)
        #expect(p.baseRate == 100.0)
        #expect(p.baseGuests == nil)
        #expect(p.maxGuests == nil)
        #expect(p.extraGuestFee == nil)
    }

    @Test func property_roundtrips_throughCodable() throws {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end   = Date(timeIntervalSinceReferenceDate: 86400)
        let original = Property(
            id: "p1", name: "Casa", neighborhood: "Centro", address: "Calle 1",
            baseRate: 250.0, status: .active,
            unavailableDateRanges: [DateRange(start: start, end: end)],
            photos: []
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Property.self, from: data)
        #expect(decoded.id == "p1")
        #expect(decoded.baseRate == 250.0)
        #expect(decoded.unavailableDateRanges.count == 1)
        #expect(decoded.status == .active)
    }

    @Test func dateRange_preserves_startAndEnd() {
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        let end   = Date(timeIntervalSinceReferenceDate: 2000)
        let r = DateRange(start: start, end: end)
        #expect(r.start == start)
        #expect(r.end == end)
    }

    @Test func property_roundtrips_guestPricingFields() throws {
        let original = Property(
            id: "prop-003", name: "Nah Ha 101", neighborhood: "North Shore", address: "Km 3.3",
            baseRate: 325.0, baseGuests: 2, maxGuests: 6, extraGuestFee: 25.0,
            status: .active
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Property.self, from: data)
        #expect(decoded.baseGuests == 2)
        #expect(decoded.maxGuests == 6)
        #expect(decoded.extraGuestFee == 25.0)
    }

    @Test func nightlyRate_returnsBaseRate_whenGuestFieldsNil() {
        let p = Property(id: "p1", name: "Casa", neighborhood: "N", address: "A", baseRate: 250.0, status: .active)
        #expect(p.nightlyRate(forGuests: 4) == 250.0)
    }

    @Test func nightlyRate_returnsBaseRate_whenGuestsAtOrBelowBase() {
        let p = Property(
            id: "prop-003", name: "Nah Ha 101", neighborhood: "N", address: "A",
            baseRate: 325.0, baseGuests: 2, maxGuests: 6, extraGuestFee: 25.0, status: .active
        )
        #expect(p.nightlyRate(forGuests: 2) == 325.0)
        #expect(p.nightlyRate(forGuests: 1) == 325.0)
    }

    @Test func nightlyRate_addsExtraGuestFee_forGuestsAboveBase() {
        let p = Property(
            id: "prop-003", name: "Nah Ha 101", neighborhood: "N", address: "A",
            baseRate: 325.0, baseGuests: 2, maxGuests: 6, extraGuestFee: 25.0, status: .active
        )
        #expect(p.nightlyRate(forGuests: 4) == 375.0)
        #expect(p.nightlyRate(forGuests: 6) == 425.0)
    }

    @Test func nightlyRate_capsAtMaxGuests() {
        let p = Property(
            id: "prop-003", name: "Nah Ha 101", neighborhood: "N", address: "A",
            baseRate: 325.0, baseGuests: 2, maxGuests: 6, extraGuestFee: 25.0, status: .active
        )
        #expect(p.nightlyRate(forGuests: 8) == 425.0)
    }
}

struct PropertyStoreTests {

    private func makeStore(properties: [Property]) -> PropertyStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("properties.json")

        struct Wrapper: Encodable { let properties: [Property] }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? encoder.encode(Wrapper(properties: properties)).write(to: url)

        return PropertyStore(storeURL: url)
    }

    @Test func store_loadsProperties_fromURL() {
        let p = Property(id: "p1", name: "Casa", neighborhood: "N", address: "A", baseRate: 100, status: .active)
        let store = makeStore(properties: [p])
        #expect(store.properties.count == 1)
        #expect(store.properties[0].name == "Casa")
    }

    @Test func store_update_replacesProperty() {
        let p = Property(id: "p1", name: "Old", neighborhood: "N", address: "A", baseRate: 100, status: .active)
        let store = makeStore(properties: [p])
        var updated = store.properties[0]
        updated.name = "New"
        store.update(updated)
        #expect(store.properties[0].name == "New")
    }

    @Test func store_add_appendsProperty() {
        let store = makeStore(properties: [])
        let p = Property(id: "p2", name: "New", neighborhood: "N", address: "A", baseRate: 200, status: .active)
        store.add(p)
        #expect(store.properties.count == 1)
        #expect(store.properties[0].id == "p2")
    }

    @Test func store_saveToDisk_persistsAcrossReload() throws {
        let p = Property(id: "p1", name: "Persist", neighborhood: "N", address: "A", baseRate: 100, status: .active)
        let store = makeStore(properties: [p])
        var updated = store.properties[0]
        updated.name = "Saved"
        store.update(updated)

        let store2 = PropertyStore(storeURL: store.storeURL)
        #expect(store2.properties[0].name == "Saved")
    }

    @Test func store_totalMonthlyRevenue_excludesInactive() {
        let active = Property(id: "p1", name: "A", neighborhood: "N", address: "A", baseRate: 100, status: .active)
        let inactive = Property(id: "p2", name: "B", neighborhood: "N", address: "B", baseRate: 200, status: .inactive)
        let store = makeStore(properties: [active, inactive])
        #expect(store.totalMonthlyRevenue == 100 * 22)
    }

    @Test func store_delete_removesPropertyById() {
        let p1 = Property(id: "p1", name: "A", neighborhood: "N", address: "A", baseRate: 100, status: .active)
        let p2 = Property(id: "p2", name: "B", neighborhood: "N", address: "B", baseRate: 200, status: .active)
        let store = makeStore(properties: [p1, p2])
        store.delete(id: "p1")
        #expect(store.properties.count == 1)
        #expect(store.properties[0].id == "p2")
    }

    @Test func store_delete_persistsRemovalToDisk() {
        let p1 = Property(id: "p1", name: "A", neighborhood: "N", address: "A", baseRate: 100, status: .active)
        let p2 = Property(id: "p2", name: "B", neighborhood: "N", address: "B", baseRate: 200, status: .active)
        let store = makeStore(properties: [p1, p2])
        store.delete(id: "p1")
        let reloaded = PropertyStore(storeURL: store.storeURL)
        #expect(reloaded.properties.count == 1)
        #expect(reloaded.properties[0].id == "p2")
    }
}
