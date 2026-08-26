import Foundation
import Testing
@testable import CozumelManager

private struct StubCredentialsStore: WordPressCredentialsProviding {
    let credentials: WordPressSyncCredentials?
    func load() -> WordPressSyncCredentials? { credentials }
}

struct WebsiteSyncCoordinatorTests {
    @Test func hasValidCredentials_returnsFalse_whenCredentialsMissing() {
        let store = StubCredentialsStore(credentials: nil)
        #expect(WebsiteSyncCoordinator.hasValidCredentials(credentialsStore: store) == false)
    }

    @Test func hasValidCredentials_returnsFalse_whenSiteURLIsInvalid() {
        let store = StubCredentialsStore(
            credentials: WordPressSyncCredentials(siteURL: "", username: "u", applicationPassword: "p")
        )
        #expect(WebsiteSyncCoordinator.hasValidCredentials(credentialsStore: store) == false)
    }

    @Test func hasValidCredentials_returnsTrue_whenValid() {
        let store = StubCredentialsStore(
            credentials: WordPressSyncCredentials(siteURL: "https://example.com", username: "u", applicationPassword: "p")
        )
        #expect(WebsiteSyncCoordinator.hasValidCredentials(credentialsStore: store) == true)
    }

    @Test func sync_returnsMissingCredentials_whenStoreHasNone() async {
        let store = StubCredentialsStore(credentials: nil)
        let attempt = await WebsiteSyncCoordinator.sync(
            properties: [], forSaleProperties: [], credentialsStore: store
        )
        #expect(attempt == .missingCredentials)
    }

    @Test func sync_returnsMissingCredentials_whenSiteURLIsInvalid() async {
        let store = StubCredentialsStore(
            credentials: WordPressSyncCredentials(siteURL: "", username: "u", applicationPassword: "p")
        )
        let attempt = await WebsiteSyncCoordinator.sync(
            properties: [], forSaleProperties: [], credentialsStore: store
        )
        #expect(attempt == .missingCredentials)
    }

    @Test func sync_delegatesToService_andReturnsResults() async {
        let credentials = WordPressSyncCredentials(siteURL: "https://example.com", username: "u", applicationPassword: "p")
        let store = StubCredentialsStore(credentials: credentials)
        let client = MockWordPressAPIClient()
        client.postsByType["rental-property"] = []
        client.postsByType["forsale-property"] = []
        let property = Property(id: "prop-001", name: "Nah Ha 101", neighborhood: "N", address: "A", baseRate: 100, status: .active)
        let attempt = await WebsiteSyncCoordinator.sync(
            properties: [property],
            forSaleProperties: [],
            credentialsStore: store,
            makeClient: { _, _ in client }
        )
        guard case .success(let results) = attempt else {
            Issue.record("Expected .success outcome")
            return
        }
        #expect(results == [SyncResult(propertyName: "Nah Ha 101", outcome: .created)])
    }
}
