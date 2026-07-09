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

    @Test func store_revertsExpiredHold_toPending_onLoad() throws {
        let url = makeTempStoreURL()
        let expired = makeStoreRequest(status: .approved, holdExpiresAt: Date(timeIntervalSinceNow: -3600))
        try writeFixture([expired], to: url)
        let store = BookingRequestStore(storeURL: url)
        #expect(store.requests[0].status == .pending)
        #expect(store.requests[0].holdExpiresAt == nil)
    }

    @Test func store_keepsActiveHold_untilExpiry() throws {
        let url = makeTempStoreURL()
        let active = makeStoreRequest(status: .approved, holdExpiresAt: Date(timeIntervalSinceNow: 3600))
        try writeFixture([active], to: url)
        let store = BookingRequestStore(storeURL: url)
        #expect(store.requests[0].status == .approved)
        #expect(store.requests[0].holdExpiresAt != nil)
    }

    @Test func store_revertedHold_persistsToDisk() throws {
        let url = makeTempStoreURL()
        let expired = makeStoreRequest(status: .approved, holdExpiresAt: Date(timeIntervalSinceNow: -3600))
        try writeFixture([expired], to: url)
        _ = BookingRequestStore(storeURL: url)

        let reloaded = BookingRequestStore(storeURL: url)
        #expect(reloaded.requests[0].status == .pending)
    }

    @Test func conflictingRequests_findsOverlap_withHeldRequest_sameProperty() {
        let store = BookingRequestStore(storeURL: makeTempStoreURL())
        let held = makeStoreRequest(id: "held", status: .approved)
        let candidate = makeStoreRequest(id: "candidate", status: .pending)
        store.requests = [held, candidate]
        let conflicts = store.conflictingRequests(for: candidate)
        #expect(conflicts.map(\.id) == ["held"])
    }

    @Test func conflictingRequests_ignoresDifferentProperty() {
        let store = BookingRequestStore(storeURL: makeTempStoreURL())
        let held = makeStoreRequest(id: "held", propertyId: "prop-999", status: .approved)
        let candidate = makeStoreRequest(id: "candidate", propertyId: "prop-003", status: .pending)
        store.requests = [held, candidate]
        #expect(store.conflictingRequests(for: candidate).isEmpty)
    }

    @Test func conflictingRequests_ignoresPendingRequests() {
        let store = BookingRequestStore(storeURL: makeTempStoreURL())
        let otherPending = makeStoreRequest(id: "other-pending", status: .pending)
        let candidate = makeStoreRequest(id: "candidate", status: .pending)
        store.requests = [otherPending, candidate]
        #expect(store.conflictingRequests(for: candidate).isEmpty)
    }

    @Test func conflictingRequests_excludesSelf() {
        let store = BookingRequestStore(storeURL: makeTempStoreURL())
        let candidate = makeStoreRequest(id: "candidate", status: .approved)
        store.requests = [candidate]
        #expect(store.conflictingRequests(for: candidate).isEmpty)
    }

    @Test func store_reloadsAutomatically_whenFileChangesExternally() async throws {
        let url = makeTempStoreURL()
        try writeFixture([], to: url)
        let store = BookingRequestStore(storeURL: url)
        #expect(store.requests.isEmpty)

        try writeFixture([makeStoreRequest(id: "external")], to: url)

        var found = false
        for _ in 0..<30 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if store.requests.count == 1 {
                found = true
                break
            }
        }
        #expect(found)
        #expect(store.requests.first?.id == "external")
    }

    @Test func approve_setsStatusApproved_andHoldExpiry48HoursOut() {
        let store = BookingRequestStore(storeURL: makeTempStoreURL())
        store.requests = [makeStoreRequest(id: "r1", status: .pending)]
        store.approve("r1")
        let updated = store.requests[0]
        #expect(updated.status == .approved)
        let hoursOut = updated.holdExpiresAt!.timeIntervalSinceNow / 3600
        #expect(hoursOut > 47.9 && hoursOut < 48.1)
    }

    @Test func deny_setsStatusDenied() {
        let store = BookingRequestStore(storeURL: makeTempStoreURL())
        store.requests = [makeStoreRequest(id: "r1", status: .pending)]
        store.deny("r1")
        #expect(store.requests[0].status == .denied)
    }

    @Test func sendInvoice_setsLineItems_totalsAmount_andStatusInvoiceSending() {
        let store = BookingRequestStore(storeURL: makeTempStoreURL())
        store.requests = [makeStoreRequest(id: "r1", status: .approved)]
        let items = [
            InvoiceLineItem(itemDescription: "Nightly rate", quantity: 3, unitAmount: 325.0),
            InvoiceLineItem(itemDescription: "Cleaning fee", quantity: 1, unitAmount: 75.0)
        ]
        store.sendInvoice(for: "r1", lineItems: items)
        let updated = store.requests[0]
        #expect(updated.status == .invoiceSending)
        #expect(updated.invoiceAmount == 1050.0)
        #expect(updated.invoiceLineItems.count == 2)
    }
}
