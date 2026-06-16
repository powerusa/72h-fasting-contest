import SwiftUI
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
        .task {
            await viewModel.bootstrap()
        }
    }
}
