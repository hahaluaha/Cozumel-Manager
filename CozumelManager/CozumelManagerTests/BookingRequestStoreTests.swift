import Foundation
import Testing
@testable import CozumelManager

func makeStoreRequest(
    id: String = "r1",
    propertyId: String = "prop-003",
    start: Date = Date(timeIntervalSinceReferenceDate: 0),
    end: Date = Date(timeIntervalSinceReferenceDate: 86400 * 3),
    guestCount: Int = 2,
    submittedAt: Date = Date(timeIntervalSinceReferenceDate: 0),
    status: BookingStatus = .pending,
    holdExpiresAt: Date? = nil
) -> BookingRequest {
    BookingRequest(
        id: id, fullName: "Guest", email: "guest@example.com",
        state: "CA", country: "USA", propertyId: propertyId,
        startDate: start, endDate: end, guestCount: guestCount,
        notes: "", submittedAt: submittedAt, status: status,
        holdExpiresAt: holdExpiresAt
    )
}

private struct BookingRequestListWire: Encodable {
    var requests: [BookingRequest]
}

private func writeFixture(_ requests: [BookingRequest], to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(BookingRequestListWire(requests: requests))
    try data.write(to: url)
}

private func makeTempStoreURL() -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("booking-requests.json")
}

struct BookingRequestStoreTests {

    @Test func store_loadsRequests_fromURL() throws {
        let url = makeTempStoreURL()
        try writeFixture([makeStoreRequest()], to: url)
        let store = BookingRequestStore(storeURL: url)
        #expect(store.requests.count == 1)
        #expect(store.requests[0].id == "r1")
    }

    @Test func store_saveToDisk_persistsAcrossReload() throws {
        let url = makeTempStoreURL()
        try writeFixture([], to: url)
        let store = BookingRequestStore(storeURL: url)
        store.requests = [makeStoreRequest()]
        store.saveToDisk()

        let reloaded = BookingRequestStore(storeURL: url)
        #expect(reloaded.requests.count == 1)
        #expect(reloaded.requests[0].id == "r1")
    }
}
