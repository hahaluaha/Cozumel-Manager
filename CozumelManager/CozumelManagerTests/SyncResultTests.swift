import Foundation
import Testing
@testable import CozumelManager

struct SyncResultTests {
    @Test func equality_ignoresId_comparesNameAndOutcome() {
        let a = SyncResult(propertyName: "Nah Ha 101", outcome: .updated)
        let b = SyncResult(propertyName: "Nah Ha 101", outcome: .updated)
        #expect(a == b)
        #expect(a.id != b.id)
    }

    @Test func equality_differsOnDifferentOutcome() {
        let a = SyncResult(propertyName: "Nah Ha 101", outcome: .created)
        let b = SyncResult(propertyName: "Nah Ha 101", outcome: .updated)
        #expect(a != b)
    }

    @Test func failedOutcome_carriesReason() {
        let result = SyncResult(propertyName: "Casa Bohemia", outcome: .failed("401 Unauthorized"))
        guard case .failed(let reason) = result.outcome else {
            Issue.record("Expected .failed outcome")
            return
        }
        #expect(reason == "401 Unauthorized")
    }
}
