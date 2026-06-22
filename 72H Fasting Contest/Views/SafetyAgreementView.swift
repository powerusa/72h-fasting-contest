import SwiftUI

struct SafetyAgreementView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var checks = [false, false, false, false]
    var onAccepted: (() -> Void)?

    private let rows = [
        "I understand this app is for tracking and motivation only.",
        "I understand this app does not provide medical advice.",
        "I will stop fasting if I feel unwell.",
        "I will consult a healthcare professional if I have a medical condition."
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(safetyDisclaimer)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    ForEach(rows.indices, id: \.self) { index in
                        SafetyCheckboxRow(title: rows[index], isChecked: $checks[index])
                    }

                    PrimaryButton(title: "Accept and Continue", systemImage: "checkmark") {
                        viewModel.acceptSafetyAgreement()
                        dismiss()
                        if let onAccepted {
                            onAccepted()
                        } else {
                            Task { await viewModel.startFast() }
                        }
                    }
                    .opacity(checks.allSatisfy(\.self) ? 1 : 0.45)
                    .disabled(!checks.allSatisfy(\.self))
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Safety Agreement")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
