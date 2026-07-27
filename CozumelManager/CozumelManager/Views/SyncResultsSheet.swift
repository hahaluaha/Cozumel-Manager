import SwiftUI

struct SyncResultsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let results: [SyncResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Results")
                .font(.title2)
                .fontWeight(.semibold)
            List(results) { result in
                HStack {
                    Text(result.propertyName)
                    Spacer()
                    Text(label(for: result.outcome))
                        .foregroundStyle(color(for: result.outcome))
                }
            }
            .frame(minHeight: 200)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func label(for outcome: SyncOutcome) -> String {
        switch outcome {
        case .created: return "Created"
        case .updated: return "Updated"
        case .failed(let reason): return "Failed — \(reason)"
        }
    }

    private func color(for outcome: SyncOutcome) -> Color {
        switch outcome {
        case .created, .updated: return .green
        case .failed: return .red
        }
    }
}
