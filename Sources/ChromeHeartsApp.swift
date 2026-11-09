import SwiftUI
import Security

@main
struct ChromeHeartsApp: App {
    @StateObject private var session = PlayerSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
        }
    }
}

@MainActor
final class PlayerSession: ObservableObject {
    @Published var displayName = UserDefaults.standard.string(forKey: "displayName") ?? "Pelaaja"
    @Published var email = UserDefaults.standard.string(forKey: "accountEmail") ?? ""
    @Published var idToken: String?
    @Published var message: String?
    @Published var isBusy = false
    @Published private(set) var isRestoringSession = true
    private var didRestoreSession = false

    var isSignedIn: Bool { idToken != nil }

    func restoreSession() async {
        guard !didRestoreSession else { return }
        didRestoreSession = true
        defer { isRestoringSession = false }
        guard let refreshToken = AuthTokenStore.load() else { return }
        do {
            let auth = try await FirebaseService.shared.refreshSession(refreshToken: refreshToken)
            idToken = auth.idToken
            AuthTokenStore.save(auth.refreshToken)
            if let restoredEmail = auth.email, restoredEmail.contains("@") {
                email = restoredEmail
                UserDefaults.standard.set(restoredEmail, forKey: "accountEmail")
            }
        } catch {
            AuthTokenStore.clear()
            idToken = nil
            message = "Kirjautumisistunto vanheni. Kirjaudu uudelleen."
        }
    }

    func signIn(createAccount: Bool, password: String) async {
        guard !email.isEmpty, !password.isEmpty else { message = "Lisää sähköposti ja salasana."; return }
        isBusy = true
        defer { isBusy = false }
        do {
            let auth = try await FirebaseService.shared.authenticate(email: email, password: password, create: createAccount)
            idToken = auth.idToken
            AuthTokenStore.save(auth.refreshToken)
            if let authenticatedEmail = auth.email { email = authenticatedEmail }
            UserDefaults.standard.set(displayName, forKey: "displayName")
            UserDefaults.standard.set(email, forKey: "accountEmail")
            message = "Kirjautuminen onnistui."
        } catch { message = error.localizedDescription }
    }

    func playAsGuest() {
        AuthTokenStore.clear()
        idToken = nil
        displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Pelaaja" : displayName
        UserDefaults.standard.set(displayName, forKey: "displayName")
    }
}

private enum AuthTokenStore {
    private static let service = "fi.chromehearts.cards.firebase-auth"
    private static let account = "refresh-token"

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ token: String) {
        clear()
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(token.utf8)
        ]
        SecItemAdd(item as CFDictionary, nil)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
