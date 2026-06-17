import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var selection = 0

    private let pages = [
        ("72Hour Fasting Leaderbord", "Join a 72-hour fasting challenge and compete with others.", "trophy.fill"),
        ("Track Your Progress", "See your timer, progress ring, milestones, and personal history.", "chart.xyaxis.line"),
        ("Compete Safely", "This app is for tracking and motivation only. It does not provide medical advice.", "shield.checkered")
    ]

    var body: some View {
        VStack(spacing: 24) {
            TabView(selection: $selection) {
                ForEach(pages.indices, id: \.self) { index in
                    VStack(spacing: 24) {
                        Spacer()
                        Image(systemName: pages[index].2)
                            .font(.system(size: 76))
                            .foregroundStyle(.blue.gradient)
                            .symbolEffect(.bounce, value: selection)
                        Text(pages[index].0)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text(pages[index].1)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        if index == 2 {
                            Text(safetyDisclaimer)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        Spacer()
                    }
                    .tag(index)
                    .padding(24)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            PrimaryButton(title: selection == 2 ? "Get Started" : "Continue", systemImage: "arrow.right") {
                if selection < 2 {
                    withAnimation { selection += 1 }
                } else {
                    viewModel.completeOnboarding()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }
}
