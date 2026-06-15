import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var filter: HistoryFilter = .all

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Filter", selection: $filter) {
                    ForEach(HistoryFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if viewModel.filteredHistory(filter).isEmpty {
                    EmptyStateView(title: "No attempts yet", message: "Your completed and stopped 72H attempts will appear here.", systemImage: "clock")
                        .padding()
                } else {
                    List(viewModel.filteredHistory(filter)) { session in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(session.startTime.formatted(date: .abbreviated, time: .shortened))
                                    .font(.headline)
                                Spacer()
                                StatusBadge(status: session.status)
                            }
                            HStack {
                                Label(session.elapsedSeconds.compactHoursString, systemImage: "timer")
                                Spacer()
                                Text(session.contestType.rawValue)
                                if let rank = session.rank {
                                    Text("#\(rank)")
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("History")
        }
    }
}
