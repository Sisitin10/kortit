import SwiftUI

@main
struct ChromeHeartsApp: App {
    @StateObject private var session = PlayerSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
                .preferredColorScheme(.dark)
        }
    }
}

@MainActor
final class PlayerSession: ObservableObject {
    @Published var displayName = UserDefaults.standard.string(forKey: "displayName") ?? "Pelaaja"
    @Published var email = ""
    @Published var idToken: String?
    @Published var message: String?
    @Published var isBusy = false

    var isSignedIn: Bool { idToken != nil }

    func signIn(createAccount: Bool, password: String) async {
        guard !email.isEmpty, !password.isEmpty else { message = "Lisää sähköposti ja salasana."; return }
        isBusy = true
        defer { isBusy = false }
        do {
            idToken = try await FirebaseService.shared.authenticate(email: email, password: password, create: createAccount)
            UserDefaults.standard.set(displayName, forKey: "displayName")
            message = "Kirjautuminen onnistui."
        } catch { message = error.localizedDescription }
    }

    func playAsGuest() {
        displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Pelaaja" : displayName
        UserDefaults.standard.set(displayName, forKey: "displayName")
    }
}
