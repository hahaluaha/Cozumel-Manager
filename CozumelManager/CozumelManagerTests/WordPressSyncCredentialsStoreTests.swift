import Foundation
import Testing
@testable import CozumelManager

struct WordPressSyncCredentialsStoreTests {
    @Test func save_thenLoad_returnsSameCredentials() throws {
        let store = WordPressSyncCredentialsStore(service: "test.\(UUID().uuidString)")
        let creds = WordPressSyncCredentials(siteURL: "http://cozumel-homes.local", username: "akrati32", applicationPassword: "abcd 1234 efgh 5678")
        try store.save(creds)
        #expect(store.load() == creds)
        store.clear()
    }

    @Test func load_returnsNil_whenNothingSaved() {
        let store = WordPressSyncCredentialsStore(service: "test.\(UUID().uuidString)")
        #expect(store.load() == nil)
    }

    @Test func save_overwritesPreviousValue() throws {
        let store = WordPressSyncCredentialsStore(service: "test.\(UUID().uuidString)")
        try store.save(WordPressSyncCredentials(siteURL: "http://a.local", username: "a", applicationPassword: "a"))
        try store.save(WordPressSyncCredentials(siteURL: "http://b.local", username: "b", applicationPassword: "b"))
        #expect(store.load()?.siteURL == "http://b.local")
        store.clear()
    }

    @Test func clear_removesStoredCredentials() throws {
        let store = WordPressSyncCredentialsStore(service: "test.\(UUID().uuidString)")
        try store.save(WordPressSyncCredentials(siteURL: "http://a.local", username: "a", applicationPassword: "a"))
        store.clear()
        #expect(store.load() == nil)
    }
}
