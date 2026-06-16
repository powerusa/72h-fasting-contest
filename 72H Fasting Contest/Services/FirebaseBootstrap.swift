import Foundation
import FirebaseCore

enum FirebaseBootstrap {
    static func configureIfPossible() {
        guard FirebaseApp.app() == nil else { return }

        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            print("Firebase disabled: add GoogleService-Info.plist to the app target.")
            return
        }

        FirebaseApp.configure()
        logConfiguration()
    }

    static var isConfigured: Bool {
        FirebaseApp.app() != nil
    }

    static func logConfiguration() {
        guard let app = FirebaseApp.app() else {
            print("Firebase debug: not configured")
            print("Firebase debug bundleID:", Bundle.main.bundleIdentifier ?? "-")
            return
        }

        print("Firebase debug appName:", app.name)
        print("Firebase debug projectID:", app.options.projectID ?? "-")
        print("Firebase debug appID:", app.options.googleAppID)
        print("Firebase debug bundleID:", Bundle.main.bundleIdentifier ?? "-")
    }

    static func debugInfo(authUID: String?, displayName: String?, fastingSessionsLoaded: Int, lastListenerError: String?, leaderboardQueryType: String, listenerConnected: Bool) -> FirebaseDebugInfo {
        guard let app = FirebaseApp.app() else {
            return FirebaseDebugInfo(
                isConfigured: false,
                bundleID: Bundle.main.bundleIdentifier ?? "-",
                authUID: authUID ?? "-",
                displayName: displayName ?? "-",
                fastingSessionsLoaded: fastingSessionsLoaded,
                lastListenerError: lastListenerError ?? "-",
                leaderboardQueryType: leaderboardQueryType,
                listenerConnected: listenerConnected
            )
        }

        return FirebaseDebugInfo(
            isConfigured: true,
            appName: app.name,
            projectID: app.options.projectID ?? "-",
            appID: app.options.googleAppID,
            bundleID: Bundle.main.bundleIdentifier ?? "-",
            authUID: authUID ?? "-",
            displayName: displayName ?? "-",
            fastingSessionsLoaded: fastingSessionsLoaded,
            lastListenerError: lastListenerError ?? "-",
            leaderboardQueryType: leaderboardQueryType,
            listenerConnected: listenerConnected
        )
    }
}
