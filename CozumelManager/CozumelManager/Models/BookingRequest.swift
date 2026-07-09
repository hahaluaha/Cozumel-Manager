import Foundation

enum BookingStatus: String, Codable {
    case pending
    case approved
    case denied
    case invoiceSending = "invoice_sending"
    case invoiced
    case paid
}

struct InvoiceLineItem: Identifiable, Codable, Hashable {
    var id: UUID
    var itemDescription: String
    var quantity: Int
    var unitAmount: Double

    init(id: UUID = UUID(), itemDescription: String, quantity: Int, unitAmount: Double) {
        self.id = id
        self.itemDescription = itemDescription
        self.quantity = quantity
        self.unitAmount = unitAmount
    }

    var total: Double { Double(quantity) * unitAmount }

    enum CodingKeys: String, CodingKey {
        case id
        case itemDescription = "description"
        case quantity
        case unitAmount = "unit_amount"
    }
}

struct BookingRequest: Identifiable, Codable, Hashable {
    var id: String
    var fullName: String
    var email: String
    var state: String
    var country: String
    var propertyId: String
    var startDate: Date
    var endDate: Date
    var guestCount: Int
    var notes: String
    var submittedAt: Date
    var status: BookingStatus
    var invoiceAmount: Double?
    var invoiceLineItems: [InvoiceLineItem]
    var stripePaymentLink: String?
    var stripePaymentStatus: String?
    var invoiceError: String?
    var holdExpiresAt: Date?

    init(
        id: String, fullName: String, email: String, state: String, country: String,
        propertyId: String, startDate: Date, endDate: Date, guestCount: Int, notes: String,
        submittedAt: Date, status: BookingStatus = .pending,
        invoiceAmount: Double? = nil, invoiceLineItems: [InvoiceLineItem] = [],
        stripePaymentLink: String? = nil, stripePaymentStatus: String? = nil,
        invoiceError: String? = nil, holdExpiresAt: Date? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.state = state
        self.country = country
        self.propertyId = propertyId
        self.startDate = startDate
        self.endDate = endDate
        self.guestCount = guestCount
        self.notes = notes
        self.submittedAt = submittedAt
        self.status = status
        self.invoiceAmount = invoiceAmount
        self.invoiceLineItems = invoiceLineItems
        self.stripePaymentLink = stripePaymentLink
        self.stripePaymentStatus = stripePaymentStatus
        self.invoiceError = invoiceError
        self.holdExpiresAt = holdExpiresAt
    }

    enum CodingKeys: String, CodingKey {
        case id, email, state, country, notes, status
        case fullName = "full_name"
        case propertyId = "property_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case guestCount = "guest_count"
        case submittedAt = "submitted_at"
        case invoiceAmount = "invoice_amount"
        case invoiceLineItems = "invoice_line_items"
        case stripePaymentLink = "stripe_payment_link"
        case stripePaymentStatus = "stripe_payment_status"
        case invoiceError = "invoice_error"
        case holdExpiresAt = "hold_expires_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        fullName = try c.decode(String.self, forKey: .fullName)
        email = try c.decode(String.self, forKey: .email)
        state = try c.decode(String.self, forKey: .state)
        country = try c.decode(String.self, forKey: .country)
        propertyId = try c.decode(String.self, forKey: .propertyId)
        startDate = try c.decode(Date.self, forKey: .startDate)
        endDate = try c.decode(Date.self, forKey: .endDate)
        guestCount = try c.decode(Int.self, forKey: .guestCount)
        notes = try c.decode(String.self, forKey: .notes)
        submittedAt = try c.decode(Date.self, forKey: .submittedAt)
        status = try c.decode(BookingStatus.self, forKey: .status)
        invoiceAmount = try? c.decode(Double.self, forKey: .invoiceAmount)
        invoiceLineItems = (try? c.decode([InvoiceLineItem].self, forKey: .invoiceLineItems)) ?? []
        stripePaymentLink = try? c.decode(String.self, forKey: .stripePaymentLink)
        stripePaymentStatus = try? c.decode(String.self, forKey: .stripePaymentStatus)
        invoiceError = try? c.decode(String.self, forKey: .invoiceError)
        holdExpiresAt = try? c.decode(Date.self, forKey: .holdExpiresAt)
    }

    static func dateRangesOverlap(_ aStart: Date, _ aEnd: Date, _ bStart: Date, _ bEnd: Date) -> Bool {
        aStart < bEnd && bStart < aEnd
    }

    static func sortedForList(_ requests: [BookingRequest]) -> [BookingRequest] {
        let pending = requests.filter { $0.status == .pending }
            .sorted { $0.submittedAt < $1.submittedAt }
        let rest = requests.filter { $0.status != .pending }
            .sorted { $0.submittedAt > $1.submittedAt }
        return pending + rest
    }

    static func autoLineItems(for request: BookingRequest, property: Property) -> [InvoiceLineItem] {
        let nights = Calendar.current.dateComponents([.day], from: request.startDate, to: request.endDate).day ?? 0
        guard nights > 0 else { return [] }
        let rate = property.nightlyRate(forGuests: request.guestCount)
        return [InvoiceLineItem(itemDescription: "Nightly rate", quantity: nights, unitAmount: rate)]
    }
}
