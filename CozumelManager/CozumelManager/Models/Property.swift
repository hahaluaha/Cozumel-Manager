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

    // ~73% occupancy — realistic vacation rental estimate
    var monthlyRevenue: Double { baseRate * 22 }
}
