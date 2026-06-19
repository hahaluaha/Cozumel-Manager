import Foundation
import Combine

private struct PropertyDTO: Codable {
    let id: String
    let name: String
    let neighborhood: String
    let address: String
    let base_rate: Double
    let status: String
}

private struct PropertyList: Codable {
    let properties: [PropertyDTO]
}

class PropertyStore: ObservableObject {
    @Published var properties: [Property] = []
    @Published var loadError: String?

    var totalMonthlyRevenue: Double {
        properties.reduce(0) { $0 + $1.monthlyRevenue }
    }

    init() {
        load()
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "properties", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(PropertyList.self, from: data)
        else {
            loadError = "Could not load properties data."
            return
        }

        properties = decoded.properties.map { dto in
            let status: PropertyStatus
            if let s = PropertyStatus(rawValue: dto.status) {
                status = s
            } else {
                assertionFailure("Unknown property status '\(dto.status)' for property \(dto.id)")
                status = .active
            }
            return Property(
                id: dto.id,
                name: dto.name,
                neighborhood: dto.neighborhood,
                address: dto.address,
                baseRate: dto.base_rate,
                status: status
            )
        }
    }
}
