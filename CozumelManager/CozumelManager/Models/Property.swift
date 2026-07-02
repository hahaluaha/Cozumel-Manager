import Foundation

enum PropertyStatus: String, Codable {
    case active
    case inactive
    case maintenance
}

struct DateRange: Codable, Identifiable {
    var id: UUID
    var start: Date
    var end: Date

    init(id: UUID = UUID(), start: Date, end: Date) {
        self.id = id
        self.start = start
        self.end = end
    }
}

struct Property: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var neighborhood: String
    var address: String
    var baseRate: Double
    var monthlyPrice: Double?
    var status: PropertyStatus
    var unavailableDateRanges: [DateRange]
    var photos: [URL]

    init(id: String, name: String, neighborhood: String, address: String,
         baseRate: Double, monthlyPrice: Double? = nil, status: PropertyStatus,
         unavailableDateRanges: [DateRange] = [], photos: [URL] = []) {
        self.id = id
        self.name = name
        self.neighborhood = neighborhood
        self.address = address
        self.baseRate = baseRate
        self.monthlyPrice = monthlyPrice
        self.status = status
        self.unavailableDateRanges = unavailableDateRanges
        self.photos = photos
    }

    var monthlyRevenue: Double {
        guard status == .active else { return 0 }
        return monthlyPrice ?? baseRate * 22
    }

    static func == (lhs: Property, rhs: Property) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    enum CodingKeys: String, CodingKey {
        case id, name, neighborhood, address, status, photos
        case baseRate = "base_rate"
        case monthlyPrice = "monthly_price"
        case unavailableDateRanges = "unavailable_date_ranges"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        neighborhood = try c.decode(String.self, forKey: .neighborhood)
        address = try c.decode(String.self, forKey: .address)
        baseRate = try c.decode(Double.self, forKey: .baseRate)
        monthlyPrice = try? c.decode(Double.self, forKey: .monthlyPrice)
        status = try c.decode(PropertyStatus.self, forKey: .status)
        unavailableDateRanges = (try? c.decode([DateRange].self, forKey: .unavailableDateRanges)) ?? []
        photos = (try? c.decode([URL].self, forKey: .photos)) ?? []
    }
}
