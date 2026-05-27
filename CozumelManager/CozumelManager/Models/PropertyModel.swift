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
        else { return }

        properties = decoded.properties.map {
            Property(
                id: $0.id,
                name: $0.name,
                neighborhood: $0.neighborhood,
                address: $0.address,
                baseRate: $0.base_rate,
                status: $0.status
            )
        }
    }
}
