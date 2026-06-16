import Foundation
import FirebaseAuth
import FirebaseCore

enum BackendError: LocalizedError {
    case firebaseNotConfigured
    case noAuthenticatedUser
    case activeSessionAlreadyExists
    case contestCodeNotFound
    case missingServerTimestamp
    case noInternetForLeaderboard

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured:
            return "Firebase is not configured. Add GoogleService-Info.plist to connect leaderboard and contests."
        case .noAuthenticatedUser:
            return "Could not sign in anonymously. Check your internet connection and Firebase Authentication settings."
        case .activeSessionAlreadyExists:
            return "You already have an active 72H fast."
        case .contestCodeNotFound:
            return "Contest code not found."
        case .missingServerTimestamp:
            return "Firebase did not return the server start time yet. Try again in a moment."
        case .noInternetForLeaderboard:
            return "Internet connection is required for leaderboard."
        }
    }
}

final class AuthService {
    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    func signInAnonymouslyIfNeeded() async throws -> String {
        guard FirebaseBootstrap.isConfigured else {
            throw BackendError.firebaseNotConfigured
        }

        if let userId = Auth.auth().currentUser?.uid {
            print("Firebase Auth existing uid:", userId)
            return userId
        }

        let result = try await Auth.auth().signInAnonymously()
        print("Firebase Auth anonymous sign-in uid:", result.user.uid)
        return result.user.uid
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}
