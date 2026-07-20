import Foundation
import Testing
@testable import CozumelManager

struct ForSalePropertyTests {

    @Test func forSaleProperty_defaultsVideoURLToNil() {
        let p = ForSaleProperty(name: "Cozumel House", askingPrice: 350_000)
        #expect(p.videoURL == nil)
    }

    @Test func forSaleProperty_roundtrips_videoURL() throws {
        let original = ForSaleProperty(
            name: "Cozumel House", askingPrice: 350_000,
            videoURL: URL(fileURLWithPath: "/tmp/house.mp4")
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ForSaleProperty.self, from: data)
        #expect(decoded.videoURL == URL(fileURLWithPath: "/tmp/house.mp4"))
    }

    @Test func forSaleProperty_decodesLegacyJSON_withNilVideoURL() throws {
        let json = """
        {"id":"\(UUID().uuidString)","name":"Cozumel House","description":"","askingPrice":350000,"listingURL":"","photos":[],"notes":""}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ForSaleProperty.self, from: json)
        #expect(decoded.videoURL == nil)
    }
}
