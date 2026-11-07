import Foundation
import SwiftUI
import AudioToolbox

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
    var trickStrength: Int { rank == 1 ? 14 : rank }
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

    private enum CodingKeys: String, CodingKey { case id, name, handCount }

    init(id: String, name: String, handCount: Int = 0) {
        self.id = id
        self.name = name
        self.handCount = handCount
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        handCount = try values.decodeIfPresent(Int.self, forKey: .handCount) ?? 0
    }
}

struct OnlineRoom: Codable {
    var code: String
    var game: GameKind
    var hostID: String
    var players: [String: PlayerInfo]
    var updatedAt: TimeInterval
    var gameState: SharedGameState? = nil
    var kakkahousuFaceCardsMinimum: Int? = nil
}

struct KakkahousuRules: Codable, Equatable {
    var faceCardsMinimum: Int = 7
    var handSize: Int = 5

    private enum CodingKeys: String, CodingKey { case faceCardsMinimum, handSize }
    init(faceCardsMinimum: Int = 7, handSize: Int = 5) { self.faceCardsMinimum = faceCardsMinimum; self.handSize = handSize }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        faceCardsMinimum = try values.decodeIfPresent(Int.self, forKey: .faceCardsMinimum) ?? 7
        handSize = try values.decodeIfPresent(Int.self, forKey: .handSize) ?? 5
    }
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
    var kakkahousuRules: KakkahousuRules = KakkahousuRules()
    var maijaPhase: MaijaPhase = .attack
    var maijaAttackerID: String? = nil
    var maijaDefenderID: String? = nil
    var maijaTrump: Suit? = nil
    var maijaTrumpCard: PlayingCard? = nil
    var maijaDiscardCount: Int = 0

    private enum CodingKeys: String, CodingKey {
        case kind, playerOrder, activePlayerID, hands, drawPile, tableCards, isOver, winnerID, kakkahousuRules
        case maijaPhase, maijaAttackerID, maijaDefenderID, maijaTrump, maijaTrumpCard, maijaDiscardCount
    }

    init(kind: GameKind, playerOrder: [String], activePlayerID: String, hands: [String: [PlayingCard]], drawPile: [PlayingCard], tableCards: [PlayingCard], isOver: Bool = false, winnerID: String? = nil, kakkahousuRules: KakkahousuRules = KakkahousuRules(), maijaPhase: MaijaPhase = .attack, maijaAttackerID: String? = nil, maijaDefenderID: String? = nil, maijaTrump: Suit? = nil, maijaTrumpCard: PlayingCard? = nil, maijaDiscardCount: Int = 0) {
        self.kind = kind
        self.playerOrder = playerOrder
        self.activePlayerID = activePlayerID
        self.hands = hands
        self.drawPile = drawPile
        self.tableCards = tableCards
        self.isOver = isOver
        self.winnerID = winnerID
        self.kakkahousuRules = kakkahousuRules
        self.maijaPhase = maijaPhase
        self.maijaAttackerID = maijaAttackerID
        self.maijaDefenderID = maijaDefenderID
        self.maijaTrump = maijaTrump
        self.maijaTrumpCard = maijaTrumpCard
        self.maijaDiscardCount = maijaDiscardCount
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        kind = try values.decode(GameKind.self, forKey: .kind)
        playerOrder = try values.decodeIfPresent([String].self, forKey: .playerOrder) ?? []
        activePlayerID = try values.decodeIfPresent(String.self, forKey: .activePlayerID) ?? playerOrder.first ?? ""
        hands = try values.decodeIfPresent([String: [PlayingCard]].self, forKey: .hands) ?? [:]
        drawPile = try values.decodeIfPresent([PlayingCard].self, forKey: .drawPile) ?? []
        tableCards = try values.decodeIfPresent([PlayingCard].self, forKey: .tableCards) ?? []
        isOver = try values.decodeIfPresent(Bool.self, forKey: .isOver) ?? false
        winnerID = try values.decodeIfPresent(String.self, forKey: .winnerID)
        kakkahousuRules = try values.decodeIfPresent(KakkahousuRules.self, forKey: .kakkahousuRules) ?? KakkahousuRules()
        maijaPhase = try values.decodeIfPresent(MaijaPhase.self, forKey: .maijaPhase) ?? .attack
        maijaAttackerID = try values.decodeIfPresent(String.self, forKey: .maijaAttackerID)
        maijaDefenderID = try values.decodeIfPresent(String.self, forKey: .maijaDefenderID)
        maijaTrump = try values.decodeIfPresent(Suit.self, forKey: .maijaTrump)
        maijaTrumpCard = try values.decodeIfPresent(PlayingCard.self, forKey: .maijaTrumpCard)
        maijaDiscardCount = try values.decodeIfPresent(Int.self, forKey: .maijaDiscardCount) ?? 0
    }
}

enum MaijaPhase: String, Codable { case attack, defense }

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
    @Published var faceCardsMinimum = 7
    @Published var maijaTrumpSuit: Suit?
    @Published var isMaijaDefense = false
    private var playerOrder: [String] = []
    private var playerID: String?
    private var keepTurnAfterPlay = false
    private var nextActivePlayerID: String?
    private var maijaPhase: MaijaPhase = .attack
    private var maijaAttackerID: String?
    private var maijaDefenderID: String?
    private var maijaTrump: Suit?
    private var maijaTrumpCard: PlayingCard?
    private var maijaDiscardCount = 0
    private var remoteHandCounts: [String: Int] = [:]

    func start(_ kind: GameKind, rules: KakkahousuRules = KakkahousuRules()) {
        game = kind
        let all = PlayingCard.deck
        let clean = kind == .mustaMaija ? all.filter { !$0.isBlackMaija } + [PlayingCard(suit: .spades, rank: 12)] : all
        var cards = clean.shuffled()
        faceCardsMinimum = rules.faceCardsMinimum
        let initial = rules.handSize
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
        maijaPhase = .attack
        maijaAttackerID = nil
        maijaDefenderID = nil
        maijaTrump = nil
        maijaTrumpCard = nil
        maijaDiscardCount = 0
        remoteHandCounts = [:]
    }

    func startOnline(_ kind: GameKind, playerIDs: [String], hostID: String, rules: KakkahousuRules = KakkahousuRules()) -> SharedGameState {
        game = kind
        faceCardsMinimum = rules.faceCardsMinimum
        let order = [hostID] + playerIDs.filter { $0 != hostID }.sorted()
        var deck = PlayingCard.deck.shuffled()
        var hands: [String: [PlayingCard]] = [:]
        for _ in 0..<5 {
            for id in order { if !deck.isEmpty { hands[id, default: []].append(deck.removeFirst()) } }
        }
        var trump: Suit?
        var trumpCard: PlayingCard?
        if kind == .mustaMaija, let index = deck.indices.reversed().first(where: { deck[$0].suit != .spades }) {
            trumpCard = deck[index]
            trump = trumpCard?.suit
            deck = Array(deck[..<index])
        }
        let firstPlayerID: String
        if kind == .kakkahousu {
            firstPlayerID = order.min { first, second in
                let firstLowest = (hands[first] ?? []).map(kakkahousuStrength).min() ?? Int.max
                let secondLowest = (hands[second] ?? []).map(kakkahousuStrength).min() ?? Int.max
                return firstLowest < secondLowest
            } ?? hostID
        } else { firstPlayerID = order.count > 1 ? order[1] : hostID }
        let firstIndex = order.firstIndex(of: firstPlayerID) ?? 0
        playerOrder = order
        playerID = hostID
        drawPile = deck
        deckCount = deck.count + (trumpCard == nil ? 0 : 1)
        hand = hands[hostID] ?? []
        tableCards = []
        selected = []
        turn = true
        isOver = false
        notice = "Pelaa vuorollasi."
        maijaPhase = .attack
        maijaAttackerID = firstPlayerID
        maijaDefenderID = order.count > 1 ? order[(firstIndex + 1) % order.count] : nil
        maijaTrump = trump
        maijaTrumpCard = trumpCard
        maijaDiscardCount = 0
        maijaTrumpSuit = trump
        isMaijaDefense = false
        remoteHandCounts = hands.mapValues(\.count)
        return SharedGameState(kind: kind, playerOrder: order, activePlayerID: firstPlayerID, hands: hands, drawPile: deck, tableCards: [], isOver: false, winnerID: nil, kakkahousuRules: rules, maijaPhase: .attack, maijaAttackerID: firstPlayerID, maijaDefenderID: maijaDefenderID, maijaTrump: trump, maijaTrumpCard: trumpCard, maijaDiscardCount: 0)
    }

    func apply(_ state: SharedGameState, for id: String) {
        let previousDeckCount = deckCount
        let newDeckCount = state.drawPile.count + (state.maijaTrumpCard == nil ? 0 : 1)
        let didDrawCards = playerID != nil && newDeckCount < previousDeckCount
        let didChangeTable = playerID != nil && state.tableCards != tableCards
        game = state.kind
        playerOrder = state.playerOrder
        playerID = id
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            hand = state.hands[id] ?? []
            tableCards = state.tableCards
        }
        drawPile = state.drawPile
        deckCount = newDeckCount
        isOver = state.isOver
        faceCardsMinimum = state.kakkahousuRules.faceCardsMinimum
        maijaPhase = state.maijaPhase
        maijaAttackerID = state.maijaAttackerID
        maijaDefenderID = state.maijaDefenderID
        maijaTrump = state.maijaTrump
        maijaTrumpSuit = state.maijaTrump
        isMaijaDefense = state.maijaPhase == .defense
        maijaTrumpCard = state.maijaTrumpCard
        maijaDiscardCount = state.maijaDiscardCount
        remoteHandCounts = state.hands.mapValues(\.count)
        selected.removeAll()
        turn = state.activePlayerID == id
        notice = state.isOver ? (state.winnerID == id ? "Sinä voitit kierroksen!" : "Kierros päättyi.") : (turn ? "Sinun vuorosi." : "Odotetaan vastustajan vuoroa.")
        if didDrawCards || didChangeTable { AudioServicesPlaySystemSound(1104) }
    }

    func snapshot(from state: SharedGameState, advanceTurn: Bool) -> SharedGameState {
        var updated = state
        guard let id = playerID else { return state }
        updated.hands[id] = hand
        remoteHandCounts[id] = hand.count
        updated.drawPile = drawPile
        updated.tableCards = tableCards
        updated.maijaPhase = maijaPhase
        updated.maijaAttackerID = maijaAttackerID
        updated.maijaDefenderID = maijaDefenderID
        updated.maijaTrump = maijaTrump
        updated.maijaTrumpCard = maijaTrumpCard
        updated.maijaDiscardCount = maijaDiscardCount
        if updated.drawPile.isEmpty && updated.maijaTrumpCard == nil {
            if updated.kind == .kakkahousu, hand.isEmpty {
                updated.isOver = true
                updated.winnerID = id
            } else if updated.kind == .mustaMaija {
                let stillInGame = updated.playerOrder.filter { !(updated.hands[$0] ?? []).isEmpty }
                if stillInGame.count <= 1 {
                    updated.isOver = true
                    let loser = stillInGame.first
                    updated.winnerID = updated.playerOrder.first(where: { $0 != loser })
                }
            }
        }
        if let nextActivePlayerID {
            updated.activePlayerID = nextActivePlayerID
            self.nextActivePlayerID = nil
        } else if advanceTurn, !keepTurnAfterPlay, let index = updated.playerOrder.firstIndex(of: id), !updated.playerOrder.isEmpty {
            let candidates = updated.playerOrder.indices.map { updated.playerOrder[($0 + index + 1) % updated.playerOrder.count] }
            if updated.kind == .mustaMaija, updated.drawPile.isEmpty, updated.maijaTrumpCard == nil {
                updated.activePlayerID = candidates.first(where: { !(updated.hands[$0] ?? []).isEmpty }) ?? id
            } else if updated.kind == .kakkahousu, updated.drawPile.isEmpty {
                updated.activePlayerID = candidates.first(where: { !(updated.hands[$0] ?? []).isEmpty }) ?? id
            } else {
                updated.activePlayerID = candidates.first ?? id
            }
        }
        turn = updated.activePlayerID == id
        keepTurnAfterPlay = false
        return updated
    }

    func toggle(_ card: PlayingCard) { if selected.contains(card.id) { selected.remove(card.id) } else { selected.insert(card.id) } }

    func playSelected() {
        actionSucceeded = false
        guard turn else { notice = "Odota omaa vuoroasi."; return }
        let chosen = hand.filter { selected.contains($0.id) }
        guard !chosen.isEmpty else { notice = "Valitse ensin kortti."; return }
        if game == .kakkahousu {
            guard chosen.count <= 4 else { notice = "Voit pelata enintään neljä samanarvoista korttia."; return }
            guard chosen.allSatisfy({ $0.rank == chosen[0].rank }) else { notice = "Pelaa samanarvoisia kortteja."; return }
            guard isLegalKakkahousuPlay(chosen[0]) else { notice = "Tämä kortti ei käy pöydän päälle."; return }
        } else {
            if maijaPhase == .attack {
                guard let defender = maijaDefenderID, let defenderCount = currentHandsCount[defender], chosen.count <= defenderCount else { notice = "Hyökkäyskortteja ei voi olla puolustajan käsiä enempää."; return }
                guard !chosen.contains(where: \.isBlackMaija) else { notice = "Patarouvaa ei saa pelata hyökkäykseen."; return }
                guard chosen.allSatisfy({ $0.suit == chosen[0].suit }) else { notice = "Pelaa hyökkäykseen saman maan kortteja."; return }
            } else {
                guard canBeatSelectedMaijaCards(with: chosen) else { notice = "Valitut kortit eivät kaada hyökkäyskortteja."; return }
            }
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
            hand.removeAll { selected.contains($0.id) }
            if game == .kakkahousu {
                let top = tableCards.last?.rank
                let rank = chosen[0].rank
                let clearsPile = (chosen.count == 4 && rank != 2) || (rank == 10 && top.map { (3...9).contains($0) } == true) || (rank == 1 && top.map { (11...13).contains($0) } == true)
                if clearsPile { tableCards.removeAll(); keepTurnAfterPlay = true }
                else { tableCards.append(contentsOf: chosen) }
                replenishHand(to: 5)
            } else {
                if maijaPhase == .attack {
                    maijaAttackerID = playerID
                    tableCards = chosen
                    maijaPhase = .defense
                    isMaijaDefense = true
                    nextActivePlayerID = maijaDefenderID
                    replenishHand(to: 5)
                } else {
                    var remainingAttacks = tableCards
                    for response in chosen {
                        if let index = remainingAttacks.firstIndex(where: { canBeat(response, attack: $0) }) { remainingAttacks.remove(at: index) }
                    }
                    maijaDiscardCount += chosen.count * 2
                    hand.append(contentsOf: remainingAttacks)
                    tableCards.removeAll()
                    maijaPhase = .attack
                    isMaijaDefense = false
                    let allBeaten = remainingAttacks.isEmpty
                    maijaAttackerID = allBeaten ? nextMaijaPlayer(after: maijaAttackerID) : nextMaijaPlayer(after: playerID)
                    maijaDefenderID = nextMaijaPlayer(after: maijaAttackerID)
                    nextActivePlayerID = maijaAttackerID
                    replenishHand(to: 5)
                }
            }
            selected.removeAll()
            notice = game == .kakkahousu ? (tableCards.isEmpty ? "Pino kaatui — pelaa uudelleen." : "Kortit pöytään.") : (maijaPhase == .defense ? "Hyökkäys pöydässä — puolustajan vuoro." : "Hyökkäys kaadettu — aloita seuraava.")
            if hand.isEmpty && deckCount == 0 { isOver = true; notice = "Kierros päättyi!" }
            actionSucceeded = true
        }
    }

    func draw() {
        actionSucceeded = false
        guard turn else { notice = "Odota omaa vuoroasi."; return }
        guard deckCount > 0 || maijaTrumpCard != nil else { notice = "Pakka on tyhjä."; return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            let amount = min(game == .kakkahousu ? max(0, 5 - hand.count) : 1, deckCount + (maijaTrumpCard == nil ? 0 : 1))
            guard amount > 0 else { notice = "Käsi on jo täysi."; return }
            var drawn = Array(drawPile.prefix(min(amount, drawPile.count)))
            if drawn.count < amount, let trumpCard = maijaTrumpCard { drawn.append(trumpCard); maijaTrumpCard = nil }
            hand.append(contentsOf: drawn)
            drawPile.removeFirst(min(amount, drawPile.count))
            deckCount = drawPile.count + (maijaTrumpCard == nil ? 0 : 1)
            notice = amount == 1 ? "Kortti nostettu." : "\(amount) korttia nostettu."
            actionSucceeded = true
        }
    }

    func pickupTable() {
        guard turn else { notice = "Odota omaa vuoroasi."; return }
        actionSucceeded = true
        hand.append(contentsOf: tableCards)
        tableCards.removeAll()
        if game == .mustaMaija, maijaPhase == .defense {
            maijaPhase = .attack
            isMaijaDefense = false
            let defender = playerID
            replenishHand(to: 5)
            maijaAttackerID = nextMaijaPlayer(after: defender)
            maijaDefenderID = nextMaijaPlayer(after: maijaAttackerID)
            nextActivePlayerID = maijaAttackerID
            notice = "Kortit nostettu — seuraavan hyökkäysvuoro."
        } else { notice = "Pöytä nostettu käteen." }
    }

    private func isLegalKakkahousuPlay(_ card: PlayingCard) -> Bool {
        guard let top = tableCards.last?.rank else { return true }
        let rank = card.rank
        if rank == 2 { return top != 10 && top != 1 }
        if top == 2 { return rank == 2 }
        if top == 10 { return rank == 10 }
        if top == 1 { return rank == 1 }
        if rank == 10 { return (3...9).contains(top) }
        if rank == 1 { return (11...13).contains(top) }
        if (11...13).contains(rank) {
            return top >= faceCardsMinimum && rank >= top
        }
        return (3...9).contains(rank) && (3...9).contains(top) && rank >= top
    }

    private func kakkahousuStrength(_ card: PlayingCard) -> Int {
        if card.rank == 2 { return 15 }
        if card.rank == 1 { return 14 }
        return card.rank
    }

    private func replenishHand(to count: Int) {
        let available = drawPile.count + (maijaTrumpCard == nil ? 0 : 1)
        let amount = min(max(0, count - hand.count), available)
        guard amount > 0 else { return }
        var drawn = Array(drawPile.prefix(min(amount, drawPile.count)))
        if drawn.count < amount, let trumpCard = maijaTrumpCard { drawn.append(trumpCard); maijaTrumpCard = nil }
        hand.append(contentsOf: drawn)
        drawPile.removeFirst(min(amount, drawPile.count))
        deckCount = drawPile.count + (maijaTrumpCard == nil ? 0 : 1)
    }

    private var currentHandsCount: [String: Int] { remoteHandCounts }

    private func canBeatSelectedMaijaCards(with responses: [PlayingCard]) -> Bool {
        guard !responses.isEmpty, responses.count <= tableCards.count else { return false }
        var remainingAttacks = tableCards
        for response in responses {
            guard let index = remainingAttacks.firstIndex(where: { canBeat(response, attack: $0) }) else { return false }
            remainingAttacks.remove(at: index)
        }
        return true
    }

    private func canBeat(_ response: PlayingCard, attack: PlayingCard) -> Bool {
        guard let trump = maijaTrump else { return false }
        guard !response.isBlackMaija, !attack.isBlackMaija else { return false }
        if response.suit == trump {
            return attack.suit != trump || response.trickStrength > attack.trickStrength
        }
        return response.suit == attack.suit && response.trickStrength > attack.trickStrength
    }

    private func nextMaijaPlayer(after id: String?) -> String? {
        guard !playerOrder.isEmpty, let id, let index = playerOrder.firstIndex(of: id) else { return playerOrder.first }
        let stockRemains = deckCount > 0 || maijaTrumpCard != nil
        for offset in 1...playerOrder.count {
            let candidate = playerOrder[(index + offset) % playerOrder.count]
            let count = candidate == playerID ? hand.count : (remoteHandCounts[candidate] ?? 0)
            if stockRemains || count > 0 { return candidate }
        }
        return id
    }
}
