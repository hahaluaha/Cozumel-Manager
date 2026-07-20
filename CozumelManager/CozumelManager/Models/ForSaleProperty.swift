import Foundation

struct ForSaleProperty: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var description: String
    var askingPrice: Double
    var listingURL: String
    var photos: [URL]
    var notes: String
    var videoURL: URL?

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        askingPrice: Double,
        listingURL: String = "",
        photos: [URL] = [],
        notes: String = "",
        videoURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.askingPrice = askingPrice
        self.listingURL = listingURL
        self.photos = photos
        self.notes = notes
        self.videoURL = videoURL
    }

    static func == (lhs: ForSaleProperty, rhs: ForSaleProperty) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
