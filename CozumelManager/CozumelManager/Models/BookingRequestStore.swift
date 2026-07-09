import Foundation
import Combine

private struct BookingRequestList: Codable {
    var requests: [BookingRequest]
}

class BookingRequestStore: ObservableObject {
    @Published var requests: [BookingRequest] = []

    let storeURL: URL

    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? BookingRequestStore.defaultStoreURL()
        load()
    }

    private static func defaultStoreURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appDir = appSupport.appendingPathComponent("CozumelManager")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("booking-requests.json")
    }

    private func migrateFromBundle() {
        guard let src = Bundle.main.url(forResource: "booking-requests", withExtension: "json") else { return }
        try? FileManager.default.copyItem(at: src, to: storeURL)
    }

    func load() {
        if !FileManager.default.fileExists(atPath: storeURL.path) {
            migrateFromBundle()
        }
        guard let data = try? Data(contentsOf: storeURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let list = try? decoder.decode(BookingRequestList.self, from: data) else { return }
        requests = list.requests
    }

    func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(BookingRequestList(requests: requests)) else { return }
        try? data.write(to: storeURL)
    }
}
