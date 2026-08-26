import Foundation

protocol WordPressCredentialsProviding {
    func load() -> WordPressSyncCredentials?
}

extension WordPressSyncCredentialsStore: WordPressCredentialsProviding {}

enum WebsiteSyncAttempt: Equatable {
    case success([SyncResult])
    case missingCredentials
}

enum WebsiteSyncCoordinator {
    static func hasValidCredentials(
        credentialsStore: WordPressCredentialsProviding = WordPressSyncCredentialsStore()
    ) -> Bool {
        guard let credentials = credentialsStore.load(),
              URL(string: credentials.siteURL) != nil else {
            return false
        }
        return true
    }

    static func sync(
        properties: [Property],
        forSaleProperties: [ForSaleProperty],
        credentialsStore: WordPressCredentialsProviding = WordPressSyncCredentialsStore(),
        makeClient: (WordPressSyncCredentials, URL) -> WordPressAPIClient = { credentials, baseURL in
            URLSessionWordPressAPIClient(
                baseURL: baseURL,
                username: credentials.username,
                applicationPassword: credentials.applicationPassword
            )
        }
    ) async -> WebsiteSyncAttempt {
        guard let credentials = credentialsStore.load(),
              let baseURL = URL(string: credentials.siteURL) else {
            return .missingCredentials
        }
        let client = makeClient(credentials, baseURL)
        let service = WordPressSyncService(apiClient: client)
        let results = await service.sync(properties: properties, forSaleProperties: forSaleProperties)
        return .success(results)
    }
}
