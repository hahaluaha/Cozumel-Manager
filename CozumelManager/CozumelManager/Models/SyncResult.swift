import Foundation

enum SyncOutcome: Equatable {
    case created
    case updated
    case failed(String)
}

struct SyncResult: Identifiable, Equatable {
    let id = UUID()
    let propertyName: String
    let outcome: SyncOutcome

    static func == (lhs: SyncResult, rhs: SyncResult) -> Bool {
        lhs.propertyName == rhs.propertyName && lhs.outcome == rhs.outcome
    }
}
