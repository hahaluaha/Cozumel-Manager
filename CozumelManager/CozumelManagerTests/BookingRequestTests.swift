import Foundation
import Testing
@testable import CozumelManager

private func makeRequest(
    id: String = "r1",
    propertyId: String = "prop-003",
    start: Date = Date(timeIntervalSinceReferenceDate: 0),
    end: Date = Date(timeIntervalSinceReferenceDate: 86400 * 3),
    guestCount: Int = 2,
    submittedAt: Date = Date(timeIntervalSinceReferenceDate: 0),
    status: BookingStatus = .pending
) -> BookingRequest {
    BookingRequest(
        id: id, fullName: "Guest", email: "guest@example.com",
        state: "CA", country: "USA", propertyId: propertyId,
        startDate: start, endDate: end, guestCount: guestCount,
        notes: "", submittedAt: submittedAt, status: status
    )
}

struct BookingRequestTests {

    @Test func bookingRequest_roundtrips_throughCodable() throws {
        let original = makeRequest()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BookingRequest.self, from: data)
        #expect(decoded.id == "r1")
        #expect(decoded.fullName == "Guest")
        #expect(decoded.status == .pending)
        #expect(decoded.invoiceLineItems.isEmpty)
        #expect(decoded.holdExpiresAt == nil)
    }

    @Test func bookingRequest_decodesSnakeCaseKeys() throws {
        let json = """
        {"id":"r1","full_name":"Guest","email":"g@example.com","state":"CA","country":"USA",
         "property_id":"prop-003","start_date":"2026-08-01T00:00:00Z","end_date":"2026-08-04T00:00:00Z",
         "guest_count":2,"notes":"","submitted_at":"2026-07-01T00:00:00Z","status":"invoice_sending"}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(BookingRequest.self, from: json)
        #expect(decoded.propertyId == "prop-003")
        #expect(decoded.guestCount == 2)
        #expect(decoded.status == .invoiceSending)
    }

    @Test func invoiceLineItem_total_multipliesQuantityByAmount() {
        let item = InvoiceLineItem(itemDescription: "Nightly rate", quantity: 3, unitAmount: 325.0)
        #expect(item.total == 975.0)
    }

    @Test func dateRangesOverlap_trueForOverlappingRanges() {
        let aStart = Date(timeIntervalSinceReferenceDate: 0)
        let aEnd = Date(timeIntervalSinceReferenceDate: 10)
        let bStart = Date(timeIntervalSinceReferenceDate: 5)
        let bEnd = Date(timeIntervalSinceReferenceDate: 15)
        #expect(BookingRequest.dateRangesOverlap(aStart, aEnd, bStart, bEnd))
    }

    @Test func dateRangesOverlap_falseForAdjacentRanges() {
        let aStart = Date(timeIntervalSinceReferenceDate: 0)
        let aEnd = Date(timeIntervalSinceReferenceDate: 10)
        let bStart = Date(timeIntervalSinceReferenceDate: 10)
        let bEnd = Date(timeIntervalSinceReferenceDate: 20)
        #expect(!BookingRequest.dateRangesOverlap(aStart, aEnd, bStart, bEnd))
    }

    @Test func sortedForList_pendingFirst_oldestPendingOnTop_restNewestFirst() {
        let oldPending = makeRequest(id: "p-old", submittedAt: Date(timeIntervalSinceReferenceDate: 0), status: .pending)
        let newPending = makeRequest(id: "p-new", submittedAt: Date(timeIntervalSinceReferenceDate: 1000), status: .pending)
        let oldApproved = makeRequest(id: "a-old", submittedAt: Date(timeIntervalSinceReferenceDate: 100), status: .approved)
        let newApproved = makeRequest(id: "a-new", submittedAt: Date(timeIntervalSinceReferenceDate: 2000), status: .approved)

        let sorted = BookingRequest.sortedForList([newApproved, oldPending, oldApproved, newPending])
        #expect(sorted.map(\.id) == ["p-old", "p-new", "a-new", "a-old"])
    }

    @Test func autoLineItems_computesNightsTimesNightlyRate() {
        let property = Property(
            id: "prop-003", name: "Nah Ha 101", neighborhood: "N", address: "A",
            baseRate: 325.0, baseGuests: 2, maxGuests: 6, extraGuestFee: 25.0, status: .active
        )
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end = start.addingTimeInterval(86400 * 3)
        let request = makeRequest(start: start, end: end, guestCount: 4)
        let items = BookingRequest.autoLineItems(for: request, property: property)
        #expect(items.count == 1)
        #expect(items[0].quantity == 3)
        #expect(items[0].unitAmount == 375.0)
        #expect(items[0].total == 1125.0)
    }

    @Test func autoLineItems_returnsEmpty_whenNightsIsZeroOrNegative() {
        let property = Property(id: "p1", name: "Casa", neighborhood: "N", address: "A", baseRate: 250.0, status: .active)
        let sameDay = Date(timeIntervalSinceReferenceDate: 0)
        let request = makeRequest(start: sameDay, end: sameDay)
        #expect(BookingRequest.autoLineItems(for: request, property: property).isEmpty)
    }
}
