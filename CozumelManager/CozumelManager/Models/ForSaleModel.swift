import Foundation
import Combine

private struct ForSalePropertyList: Codable {
    var properties: [ForSaleProperty]
}

class ForSaleStore: ObservableObject {
    @Published var properties: [ForSaleProperty] = []

    let storeURL: URL

    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? ForSaleStore.defaultStoreURL()
        load()
    }

    private static func defaultStoreURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appDir = appSupport.appendingPathComponent("CozumelManager")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("forSaleProperties.json")
    }

    private func load() {
        if !FileManager.default.fileExists(atPath: storeURL.path) {
            migrateFromBundle()
        }
        guard let data = try? Data(contentsOf: storeURL) else { return }
        guard let list = try? JSONDecoder().decode(ForSalePropertyList.self, from: data) else { return }
        properties = list.properties
    }

    private func migrateFromBundle() {
        guard let src = Bundle.main.url(forResource: "forSaleProperties", withExtension: "json") else { return }
        try? FileManager.default.copyItem(at: src, to: storeURL)
    }

    func add(_ property: ForSaleProperty) {
        properties.append(property)
        saveToDisk()
    }

    func update(_ property: ForSaleProperty) {
        guard let i = properties.firstIndex(where: { $0.id == property.id }) else { return }
        properties[i] = property
        saveToDisk()
    }

    func delete(id: UUID) {
        properties.removeAll { $0.id == id }
        saveToDisk()
    }

    func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(ForSalePropertyList(properties: properties)) else { return }
        try? data.write(to: storeURL)
    }
}
