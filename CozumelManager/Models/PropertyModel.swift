import Foundation

struct Coordinates: Codable {
    let lat: Double?
    let lng: Double?
}

struct Property: Codable, Identifiable {
    let id: String
    let name: String
    let neighborhood: String
    let address: String
    let coordinates: Coordinates
    let base_rate: Double
    let cleaning_status: String
    let manager_notes: String
}

private struct PropertyList: Codable {
    let properties: [Property]
}

class PropertyStore: ObservableObject {
    @Published var properties: [Property] = []

    init() {
        load()
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "properties", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(PropertyList.self, from: data)
        else { return }
        properties = decoded.properties
    }
}
