import Foundation

enum OnlineError: LocalizedError {
    case missingConfiguration
    case invalidResponse
    case server(String)
    var errorDescription: String? {
        switch self {
        case .missingConfiguration: "Firebase puuttuu. Aseta FIREBASE_API_KEY ja FIREBASE_DATABASE_URL Xcode-schemen ympäristömuuttujiin."
        case .invalidResponse: "Palvelin palautti virheellisen vastauksen."
        case .server(let detail): detail
        }
    }
}

final class FirebaseService {
    static let shared = FirebaseService()
    private init() {}

    private var apiKey: String? { configuredValue("FIREBASE_API_KEY") }
    private var databaseURL: String? { configuredValue("FIREBASE_DATABASE_URL") }

    private func configuredValue(_ key: String) -> String? {
        let value = ProcessInfo.processInfo.environment[key] ?? Bundle.main.object(forInfoDictionaryKey: key) as? String
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }

    func authenticate(email: String, password: String, create: Bool) async throws -> String {
        guard let apiKey else { throw OnlineError.missingConfiguration }
        let method = create ? "signUp" : "signInWithPassword"
        let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:\(method)?key=\(apiKey)")!
        let data = try await post(url, body: ["email": email, "password": password, "returnSecureToken": true])
        guard let token = data["idToken"] as? String else { throw OnlineError.invalidResponse }
        return token
    }

    func createRoom(game: GameKind, player: PlayerInfo, token: String) async throws -> OnlineRoom {
        let code = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).uppercased()
        let room = OnlineRoom(code: code, game: game, hostID: player.id, players: [player.id: player], updatedAt: Date().timeIntervalSince1970)
        try await save(room, token: token)
        return room
    }

    func joinRoom(code: String, player: PlayerInfo, token: String) async throws -> OnlineRoom {
        var room = try await load(code: code.uppercased(), token: token)
        guard room.players.count < 6 else { throw OnlineError.server("Huone on täynnä (enintään 6 pelaajaa).") }
        room.players[player.id] = player
        room.updatedAt = Date().timeIntervalSince1970
        try await save(room, token: token)
        return room
    }

    func load(code: String, token: String) async throws -> OnlineRoom {
        let url = try roomURL(code, token: token)
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let room = try? JSONDecoder().decode(OnlineRoom.self, from: data) else { throw OnlineError.server("Huonetta ei löytynyt. Tarkista huonekoodi.") }
        return room
    }

    func save(_ room: OnlineRoom, token: String) async throws {
        let url = try roomURL(room.code, token: token)
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(room)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let status = response as? HTTPURLResponse, (200..<300).contains(status.statusCode) else { throw OnlineError.server("Huoneen tallennus epäonnistui. Tarkista Firebase-tietokannan säännöt.") }
    }

    private func roomURL(_ code: String, token: String) throws -> URL {
        guard let databaseURL, var components = URLComponents(string: "\(databaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/rooms/\(code).json") else { throw OnlineError.missingConfiguration }
        components.queryItems = [URLQueryItem(name: "auth", value: token)]
        guard let url = components.url else { throw OnlineError.invalidResponse }
        return url
    }

    private func post(_ url: URL, body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let status = response as? HTTPURLResponse else { throw OnlineError.invalidResponse }
        guard (200..<300).contains(status.statusCode) else {
            let details = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any]
            throw OnlineError.server(details?["message"] as? String ?? "Kirjautuminen epäonnistui.")
        }
        guard let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw OnlineError.invalidResponse }
        return decoded
    }
}
