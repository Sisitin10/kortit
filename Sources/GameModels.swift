import Foundation
import SwiftUI

enum Suit: String, CaseIterable, Codable, Identifiable {
    case spades, clubs, diamonds, hearts
    var id: String { rawValue }
    var glyph: String {
        switch self { case .spades: "♠"; case .clubs: "♣"; case .diamonds: "♦"; case .hearts: "♥" }
    }
    var isRed: Bool { self == .hearts || self == .diamonds }
}

struct PlayingCard: Identifiable, Codable, Hashable {
    let id: String
    let suit: Suit
    let rank: Int
    init(suit: Suit, rank: Int) { self.suit = suit; self.rank = rank; id = "\(suit.rawValue)-\(rank)" }
    var label: String {
        switch rank { case 1: "A"; case 11: "J"; case 12: "Q"; case 13: "K"; default: "\(rank)" }
    }
    static var deck: [PlayingCard] { Suit.allCases.flatMap { suit in (1...13).map { PlayingCard(suit: suit, rank: $0) } }.shuffled() }
    var isBlackMaija: Bool { suit == .spades && rank == 12 }
}

enum GameKind: String, CaseIterable, Codable, Identifiable {
    case kakkahousu = "Kakkahousu"
    case mustaMaija = "Musta Maija"
    var id: String { rawValue }
    var subtitle: String { self == .kakkahousu ? "Pelaa, nosta ja vältä viimeistä kättä." : "Vältä Mustaa Maijaa viimeiseen asti." }
}

struct PlayerInfo: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var handCount: Int = 0
}

struct OnlineRoom: Codable {
    var code: String
    var game: GameKind
    var hostID: String
    var players: [String: PlayerInfo]
    var updatedAt: TimeInterval
    var gameState: SharedGameState? = nil
}

struct SharedGameState: Codable {
    var kind: GameKind
    var playerOrder: [String]
    var activePlayerID: String
    var hands: [String: [PlayingCard]]
    var drawPile: [PlayingCard]
    var tableCards: [PlayingCard]
    var isOver: Bool = false
    var winnerID: String? = nil
}

@MainActor
final class CardGame: ObservableObject {
    @Published var game: GameKind = .kakkahousu
    @Published var hand: [PlayingCard] = []
    @Published var deckCount = 0
    private var drawPile: [PlayingCard] = []
    @Published var tableCards: [PlayingCard] = []
    @Published var selected: Set<String> = []
    @Published var turn = true
    @Published var notice = "Aloita uusi peli"
    @Published var isOver = false
    @Published var actionSucceeded = false
    private var playerOrder: [String] = []
    private var playerID: String?

    func start(_ kind: GameKind) {
        game = kind
        let all = PlayingCard.deck
        let clean = kind == .mustaMaija ? all.filter { !$0.isBlackMaija } + [PlayingCard(suit: .spades, rank: 12)] : all
        var cards = clean.shuffled()
        let initial = kind == .kakkahousu ? 5 : 5
        hand = Array(cards.prefix(initial)); cards.removeFirst(initial)
        drawPile = cards
        deckCount = drawPile.count
        tableCards = []
        selected = []
        turn = true
        isOver = false
        notice = kind == .kakkahousu ? "Pelaa pöytään samanarvoisia kortteja." : "Pelaa kortti. Vältä ♠Q:ta!"
        playerOrder = []
        playerID = nil
    }

    func startOnline(_ kind: GameKind, playerIDs: [String], hostID: String) -> SharedGameState {
        game = kind
        let order = [hostID] + playerIDs.filter { $0 != hostID }.sorted()
        var deck = PlayingCard.deck.shuffled()
        var hands: [String: [PlayingCard]] = [:]
        for _ in 0..<5 {
            for id in order { if !deck.isEmpty { hands[id, default: []].append(deck.removeFirst()) } }
        }
        playerOrder = order
        playerID = hostID
        drawPile = deck
        deckCount = deck.count
        hand = hands[hostID] ?? []
        tableCards = []
        selected = []
        turn = true
        isOver = false
        notice = "Pelaa vuorollasi."
        return SharedGameState(kind: kind, playerOrder: order, activePlayerID: hostID, hands: hands, drawPile: deck, tableCards: [], isOver: false, winnerID: nil)
    }

    func apply(_ state: SharedGameState, for id: String) {
        game = state.kind
        playerOrder = state.playerOrder
        playerID = id
        hand = state.hands[id] ?? []
        drawPile = state.drawPile
        deckCount = state.drawPile.count
        tableCards = state.tableCards
        isOver = state.isOver
        selected.removeAll()
        turn = state.activePlayerID == id
        notice = state.isOver ? (state.winnerID == id ? "Sinä voitit kierroksen!" : "Kierros päättyi.") : (turn ? "Sinun vuorosi." : "Odotetaan vastustajan vuoroa.")
    }

    func snapshot(from state: SharedGameState, advanceTurn: Bool) -> SharedGameState {
        var updated = state
        guard let id = playerID else { return state }
        updated.hands[id] = hand
        updated.drawPile = drawPile
        updated.tableCards = tableCards
        if updated.drawPile.isEmpty {
            if updated.kind == .kakkahousu, hand.isEmpty {
                updated.isOver = true
                updated.winnerID = id
            } else if updated.kind == .mustaMaija && updated.hands.values.allSatisfy({ $0.allSatisfy(\.isBlackMaija) }) {
                updated.isOver = true
                updated.winnerID = updated.hands.first(where: { !$0.value.contains(where: \.isBlackMaija) })?.key
            }
        }
        if advanceTurn, let index = updated.playerOrder.firstIndex(of: id), !updated.playerOrder.isEmpty {
            updated.activePlayerID = updated.playerOrder[(index + 1) % updated.playerOrder.count]
        }
        return updated
    }

    func toggle(_ card: PlayingCard) { if selected.contains(card.id) { selected.remove(card.id) } else { selected.insert(card.id) } }

    func playSelected() {
        actionSucceeded = false
        let chosen = hand.filter { selected.contains($0.id) }
        guard !chosen.isEmpty else { notice = "Valitse ensin kortti."; return }
        if game == .mustaMaija && chosen.contains(where: { $0.isBlackMaija }) { notice = "Musta Maijaa ei voi pelata pois kädestä."; return }
        if game == .kakkahousu {
            guard chosen.count <= 4 else { notice = "Voit pelata enintään neljä samanarvoista korttia."; return }
            guard chosen.allSatisfy({ $0.rank == chosen[0].rank }) else { notice = "Pelaa samanarvoisia kortteja."; return }
            if let top = tableCards.last, chosen[0].rank < top.rank { notice = "Kortin täytyy olla vähintään pöydän arvoinen."; return }
        } else if chosen.count != 1 { notice = "Pelaa yksi kortti kerrallaan."; return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
            hand.removeAll { selected.contains($0.id) }
            tableCards.append(contentsOf: chosen)
            selected.removeAll()
            notice = game == .kakkahousu ? "Kortit pöytään! Nosta takaisin viiteen." : (chosen[0].isBlackMaija ? "Musta Maija jäi käteen!" : "Kortti pelattu.")
            if hand.isEmpty && deckCount == 0 { isOver = true; notice = "Kierros päättyi!" }
            actionSucceeded = true
        }
    }

    func draw() {
        actionSucceeded = false
        guard deckCount > 0 else { notice = "Pakka on tyhjä."; return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            let amount = min(game == .kakkahousu ? max(0, 5 - hand.count) : 1, deckCount)
            guard amount > 0 else { notice = "Käsi on jo täysi."; return }
            let drawn = Array(drawPile.prefix(amount))
            hand.append(contentsOf: drawn)
            drawPile.removeFirst(amount)
            deckCount -= amount
            notice = amount == 1 ? "Kortti nostettu." : "\(amount) korttia nostettu."
            actionSucceeded = true
        }
    }

    func pickupTable() {
        actionSucceeded = true
        hand.append(contentsOf: tableCards)
        tableCards.removeAll()
        notice = "Pöytä nostettu käteen."
    }
}
