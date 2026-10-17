import SwiftUI
import Combine
import FirebaseCore

@main
struct FastingContestApp: App {
    @StateObject private var viewModel = AppViewModel()

    init() {
        FirebaseBootstrap.configureIfPossible()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(viewModel)
        }
    }
}

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        Group {
            if !viewModel.hasCompletedOnboarding {
                OnboardingView()
            } else if viewModel.profile == nil {
                ProfileSetupView()
            } else {
                RootTabView()
            }
        }
        .onReceive(timer) { _ in
            if scenePhase == .active { viewModel.tick() }
        }
        .task {
            await viewModel.bootstrap()
        }
    }
}
