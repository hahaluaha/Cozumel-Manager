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
}
