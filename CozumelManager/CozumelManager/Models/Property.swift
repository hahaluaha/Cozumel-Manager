import Foundation

enum PropertyStatus: String, Codable {
    case active
    case inactive
    case maintenance
}

struct Property: Identifiable, Hashable {
    let id: String
    let name: String
    let neighborhood: String
    let address: String
    let baseRate: Double
    let status: PropertyStatus

    // ~73% occupancy — only active properties generate revenue
    var monthlyRevenue: Double { status == .active ? baseRate * 22 : 0 }

    static func == (lhs: Property, rhs: Property) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
