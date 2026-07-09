import Foundation
import Combine

private struct BookingRequestList: Codable {
    var requests: [BookingRequest]
}

class BookingRequestStore: ObservableObject {
    @Published var requests: [BookingRequest] = []

    let storeURL: URL
    private var watcherSource: DispatchSourceFileSystemObject?

    init(storeURL: URL? = nil) {
        self.storeURL = storeURL ?? BookingRequestStore.defaultStoreURL()
        load()
        startWatching()
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
        revertExpiredHolds()
    }

    func revertExpiredHolds() {
        let now = Date()
        var changed = false
        for i in requests.indices {
            if requests[i].status == .approved,
               let expiry = requests[i].holdExpiresAt,
               expiry < now {
                requests[i].status = .pending
                requests[i].holdExpiresAt = nil
                changed = true
            }
        }
        if changed { saveToDisk() }
    }

    func conflictingRequests(for request: BookingRequest) -> [BookingRequest] {
        let holdingStatuses: Set<BookingStatus> = [.approved, .invoiceSending, .invoiced, .paid]
        return requests.filter { other in
            other.id != request.id &&
            other.propertyId == request.propertyId &&
            holdingStatuses.contains(other.status) &&
            BookingRequest.dateRangesOverlap(request.startDate, request.endDate, other.startDate, other.endDate)
        }
    }

    func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(BookingRequestList(requests: requests)) else { return }
        try? data.write(to: storeURL)
    }

    func startWatching() {
        stopWatching()
        let fd = open(storeURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in
            self?.load()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        watcherSource = source
    }

    func stopWatching() {
        watcherSource?.cancel()
        watcherSource = nil
    }

    deinit {
        watcherSource?.cancel()
    }
}
