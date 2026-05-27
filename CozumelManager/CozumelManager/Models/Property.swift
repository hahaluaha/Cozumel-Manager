import Foundation
import SwiftData

@Model
final class Property {
    var id: String
    var name: String
    var neighborhood: String
    var address: String
    var baseRate: Double
    var status: String

    init(id: String, name: String, neighborhood: String, address: String, baseRate: Double, status: String) {
        self.id = id
        self.name = name
        self.neighborhood = neighborhood
        self.address = address
        self.baseRate = baseRate
        self.status = status
    }

    var monthlyRevenue: Double { baseRate * 30 }
}
