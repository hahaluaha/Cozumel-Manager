import Foundation

final class WordPressSyncService {
    private let apiClient: WordPressAPIClient

    init(apiClient: WordPressAPIClient) {
        self.apiClient = apiClient
    }

    func sync(properties: [Property], forSaleProperties: [ForSaleProperty]) async -> [SyncResult] {
        var results: [SyncResult] = []
        results.append(contentsOf: await syncRentals(properties))
        results.append(contentsOf: await syncForSale(forSaleProperties))
        return results
    }

    private func syncRentals(_ properties: [Property]) async -> [SyncResult] {
        guard let existing = try? await apiClient.fetchPosts(postType: "rental-property") else {
            return properties.map { SyncResult(propertyName: $0.name, outcome: .failed("Could not fetch existing rental posts")) }
        }
        var results: [SyncResult] = []
        for property in properties {
            var meta: [String: String] = [
                "mac_id": property.id,
                "status": property.status.rawValue
            ]
            if !property.neighborhood.isEmpty {
                meta["neighborhood"] = property.neighborhood
            }
            if !property.address.isEmpty {
                meta["address"] = property.address
            }
            if property.baseRate != 0 {
                meta["base_rate"] = String(property.baseRate)
            }
            if let maxGuests = property.maxGuests {
                meta["max_guests"] = String(maxGuests)
            }
            if let baseGuests = property.baseGuests {
                meta["base_guests"] = String(baseGuests)
            }
            if let extraGuestFee = property.extraGuestFee {
                meta["extra_guest_fee"] = String(extraGuestFee)
            }
            let payload = WordPressPostPayload(
                title: property.name,
                content: nil,
                status: nil,
                meta: meta
            )
            results.append(await syncPost(postType: "rental-property", macId: property.id, name: property.name, existing: existing, payload: payload))
        }
        return results
    }

    private func syncForSale(_ properties: [ForSaleProperty]) async -> [SyncResult] {
        guard let existing = try? await apiClient.fetchPosts(postType: "forsale-property") else {
            return properties.map { SyncResult(propertyName: $0.name, outcome: .failed("Could not fetch existing for-sale posts")) }
        }
        var results: [SyncResult] = []
        for property in properties {
            let macId = property.id.uuidString
            var meta: [String: String] = ["mac_id": macId]
            if property.askingPrice != 0 {
                meta["asking_price"] = String(property.askingPrice)
            }
            if !property.listingURL.isEmpty {
                meta["listing_url"] = property.listingURL
            }
            if !property.notes.isEmpty {
                meta["notes"] = property.notes
            }
            let payload = WordPressPostPayload(
                title: property.name,
                content: property.description.isEmpty ? nil : property.description,
                status: nil,
                meta: meta
            )
            results.append(await syncPost(postType: "forsale-property", macId: macId, name: property.name, existing: existing, payload: payload))
        }
        return results
    }

    private func syncPost(postType: String, macId: String, name: String, existing: [WordPressPost], payload: WordPressPostPayload) async -> SyncResult {
        do {
            if let match = existing.first(where: { $0.meta.mac_id == macId }) {
                _ = try await apiClient.updatePost(postType: postType, postId: match.id, payload: payload)
                return SyncResult(propertyName: name, outcome: .updated)
            } else {
                var createPayload = payload
                createPayload.status = "draft"
                _ = try await apiClient.createPost(postType: postType, payload: createPayload)
                return SyncResult(propertyName: name, outcome: .created)
            }
        } catch {
            return SyncResult(propertyName: name, outcome: .failed("\(error)"))
        }
    }
}
