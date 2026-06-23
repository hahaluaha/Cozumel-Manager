import Foundation
import Combine

private struct PropertyList: Codable {
    var properties: [Property]
}

class PropertyStore: ObservableObject {
    @Published var properties: [Property] = []
    @Published var loadError: String?

    let storeURL: URL

    var totalMonthlyRevenue: Double {
        properties.reduce(0) { $0 + $1.monthlyRevenue }
    }

    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? PropertyStore.defaultStoreURL()
        load()
    }

    private static func defaultStoreURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appDir = appSupport.appendingPathComponent("CozumelManager")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("properties.json")
    }

    private func load() {
        if !FileManager.default.fileExists(atPath: storeURL.path) {
            migrateFromBundle()
        }
        guard let data = try? Data(contentsOf: storeURL) else {
            loadError = "Could not load properties data."
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let list = try? decoder.decode(PropertyList.self, from: data) else {
            loadError = "Could not parse properties data."
            return
        }
        properties = list.properties
    }

    private func migrateFromBundle() {
        guard let src = Bundle.main.url(forResource: "properties", withExtension: "json") else { return }
        try? FileManager.default.copyItem(at: src, to: storeURL)
    }

    func update(_ property: Property) {
        guard let i = properties.firstIndex(where: { $0.id == property.id }) else {
            assertionFailure("update called with unknown property id: \(property.id)")
            return
        }
        properties[i] = property
        saveToDisk()
    }

    func add(_ property: Property) {
        properties.append(property)
        saveToDisk()
    }

    func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(PropertyList(properties: properties)) else { return }
        try? data.write(to: storeURL)
    }
}
