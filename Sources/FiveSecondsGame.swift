import AVFoundation
import Speech
import SwiftUI
import UIKit

enum FiveSecondsColor: String, CaseIterable, Identifiable, Codable {
    case white, red, yellow, green, blue, black
    var id: String { rawValue }
    var title: String {
        switch self {
        case .white: "Valkoinen"
        case .red: "Punainen"
        case .yellow: "Keltainen"
        case .green: "Vihreä"
        case .blue: "Sininen"
        case .black: "Musta"
        }
    }
    var color: Color {
        switch self {
        case .white: Color.white
        case .red: Color(red: 0.78, green: 0.12, blue: 0.15)
        case .yellow: Color(red: 0.98, green: 0.76, blue: 0.12)
        case .green: Color(red: 0.12, green: 0.55, blue: 0.30)
        case .blue: Color(red: 0.12, green: 0.40, blue: 0.76)
        case .black: Color.black
        }
    }
    var foreground: Color { self == .white || self == .yellow ? .black : .white }
}

enum FiveSecondsStage: String, Codable { case draw, reading, answering, judging, finished }
enum FiveSecondsAction: String, Codable { case skip, swap }

struct FiveSecondsState: Codable, Equatable {
    var roundID: String = UUID().uuidString
    var playerOrder: [String]
    var positions: [String: Int]
    var readerID: String
    var responderID: String
    var judgeID: String? = nil
    var question: String? = nil
    var stage: FiveSecondsStage = .draw
    var answerStartedAt: TimeInterval? = nil
    var transcript: String = ""
    var specialCard: FiveSecondsAction? = nil
    var specialCardsEnabled: Bool = false
    var isOver: Bool = false
    var winnerID: String? = nil

    static func newGame(playerIDs: [String], hostID: String, specialCardsEnabled: Bool) -> FiveSecondsState {
        let order = [hostID] + playerIDs.filter { $0 != hostID }.sorted()
        let next = order.count > 1 ? order[1] : hostID
        return FiveSecondsState(
            playerOrder: order,
            positions: Dictionary(uniqueKeysWithValues: order.map { ($0, 0) }),
            readerID: hostID,
            responderID: next,
            judgeID: hostID,
            specialCardsEnabled: specialCardsEnabled
        )
    }

    var nextResponderID: String {
        guard let index = playerOrder.firstIndex(of: responderID), !playerOrder.isEmpty else { return readerID }
        return playerOrder[(index + 1) % playerOrder.count]
    }

    mutating func drawQuestion(from prompts: [String]) {
        guard stage == .draw, !isOver, !prompts.isEmpty else { return }
        if specialCardsEnabled, Int.random(in: 0..<10) == 0 {
            specialCard = Bool.random() ? .skip : .swap
            question = nil
            stage = .judging
            return
        }
        specialCard = nil
        question = prompts.randomElement()
        transcript = ""
        answerStartedAt = nil
        stage = .reading
    }

    mutating func startAnswering(at time: TimeInterval = Date().timeIntervalSince1970) {
        guard stage == .reading else { return }
        answerStartedAt = time
        stage = .answering
    }

    mutating func finishAnswer(_ words: String) {
        guard stage == .answering else { return }
        transcript = words.trimmingCharacters(in: .whitespacesAndNewlines)
        stage = .judging
    }

    mutating func resolveAnswer(correct: Bool) {
        guard stage == .judging, !isOver else { return }
        let previousResponder = responderID
        if correct {
            positions[responderID] = min(12, (positions[responderID] ?? 0) + 1)
            if positions[responderID] == 12 {
                isOver = true
                winnerID = responderID
                stage = .finished
                return
            }
            readerID = responderID
            responderID = nextResponderID
            judgeID = readerID
        } else {
            judgeID = previousResponder
            responderID = nextResponderID
            transcript = ""
            answerStartedAt = nil
            stage = .reading
            return
        }
        question = nil
        transcript = ""
        answerStartedAt = nil
        specialCard = nil
        stage = .draw
    }

    mutating func resolveSpecialCard() {
        guard let specialCard, stage == .judging else { return }
        switch specialCard {
        case .skip:
            responderID = nextResponderID
        case .swap:
            let first = positions[readerID] ?? 0
            positions[readerID] = positions[responderID] ?? 0
            positions[responderID] = first
            let oldReader = readerID
            readerID = responderID
            responderID = oldReader
        }
        judgeID = readerID
        self.specialCard = nil
        question = nil
        stage = .draw
    }
}

enum FiveSecondsPrompts {
    static let all: [String] = {
        guard let url = Bundle.main.url(forResource: "five_seconds_questions", withExtension: "txt"),
              let source = try? String(contentsOf: url, encoding: .utf8) else { return ["Nimeä kolme eläintä", "Nimeä kolme väriä", "Nimeä kolme ruokaa"] }
        return source.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }()
}

@MainActor
final class FiveSecondsSpeech: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isListening = false
    @Published private(set) var permissionGranted = false
    @Published private(set) var permissionMessage: String?
    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "fi-FI"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func requestPermissions() async {
        let microphone = await AVAudioApplication.requestRecordPermission()
        let speech: SFSpeechRecognizerAuthorizationStatus
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            speech = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
        } else {
            speech = SFSpeechRecognizer.authorizationStatus()
        }
        permissionGranted = microphone && speech == .authorized && recognizer != nil
        if !permissionGranted {
            permissionMessage = "Puheentunnistus tarvitsee mikrofonin ja puheentunnistuksen luvat. Voit silti pelata, ja muut pelaajat arvioivat vastauksen."
        }
    }

    func start() {
        guard permissionGranted, let recognizer, recognizer.isAvailable, !isListening else { return }
        transcript = ""
        task?.cancel()
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            request = SFSpeechAudioBufferRecognitionRequest()
            guard let request else { return }
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            let input = engine.inputNode
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
                request.append(buffer)
            }
            engine.prepare()
            try engine.start()
            isListening = true
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    if let result { self?.transcript = result.bestTranscription.formattedString }
                    if error != nil { self?.stop() }
                }
            }
        } catch {
            permissionMessage = "Mikrofonia ei voitu käynnistää. Tarkista sovelluksen asetukset."
            stop()
        }
    }

    func stop() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        task = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

struct FiveSecondsTableView: View {
    let state: FiveSecondsState
    let playerID: String
    let players: [String: PlayerInfo]
    let onDraw: () -> Void
    let onStartAnswering: () -> Void
    let onFinishAnswer: (String) -> Void
    let onJudge: (Bool) -> Void
    let onSpecial: () -> Void
    let onLeave: () -> Void

    @StateObject private var speech = FiveSecondsSpeech()
    @State private var hasRequestedPermissions = false
    @State private var cardIsMoving = false

    private let track: [CGPoint] = [
        CGPoint(x: 0.22, y: 0.88), CGPoint(x: 0.40, y: 0.91), CGPoint(x: 0.60, y: 0.86),
        CGPoint(x: 0.79, y: 0.80), CGPoint(x: 0.84, y: 0.66), CGPoint(x: 0.70, y: 0.60),
        CGPoint(x: 0.53, y: 0.53), CGPoint(x: 0.37, y: 0.51), CGPoint(x: 0.20, y: 0.43),
        CGPoint(x: 0.19, y: 0.30), CGPoint(x: 0.28, y: 0.18), CGPoint(x: 0.55, y: 0.13),
        CGPoint(x: 0.77, y: 0.13)
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 0.91, green: 0.90, blue: 0.87).ignoresSafeArea()
                VStack(spacing: 8) {
                    header
                    board
                        .frame(maxHeight: proxy.size.height * 0.49)
                    if state.stage == .reading || state.stage == .answering || state.stage == .judging || state.stage == .finished {
                        questionPanel
                            .frame(maxHeight: proxy.size.height * 0.29)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    } else {
                        drawDeck
                            .frame(maxHeight: proxy.size.height * 0.28)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    Spacer(minLength: 2)
                    bottomStatus
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom == 0 ? 12 : 4, 4))
                .frame(maxWidth: 620, maxHeight: .infinity)
                .frame(maxWidth: .infinity)
                if cardIsMoving {
                    FiveSecondsPromptCard(text: state.question ?? "")
                        .frame(width: min(proxy.size.width * 0.66, 270))
                        .rotationEffect(.degrees(-7))
                        .shadow(color: .black.opacity(0.24), radius: 18, y: 12)
                        .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.49)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .animation(.spring(response: 0.48, dampingFraction: 0.82), value: state.stage)
            .animation(.spring(response: 0.55, dampingFraction: 0.76), value: state.positions)
        }
        .task {
            guard !hasRequestedPermissions else { return }
            hasRequestedPermissions = true
            await speech.requestPermissions()
        }
        .task(id: state.roundID + (state.question ?? "") + state.responderID + state.stage.rawValue) {
            guard state.stage == .reading, state.responderID == playerID else { return }
            let readingDelay = min(3.0, max(2.0, 1.8 + Double(state.question?.count ?? 0) / 80))
            try? await Task.sleep(for: .seconds(readingDelay))
            guard !Task.isCancelled else { return }
            onStartAnswering()
        }
        .task(id: state.answerStartedAt) {
            guard state.stage == .answering, let started = state.answerStartedAt else { return }
            if state.responderID == playerID { speech.start() }
            let remaining = max(0, started + 5 - Date().timeIntervalSince1970)
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            if state.responderID == playerID {
                speech.stop()
                onFinishAnswer(speech.transcript)
            }
        }
        .onChange(of: state.answerStartedAt) { _, startedAt in
            guard startedAt != nil else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        .onChange(of: state.stage) { _, stage in
            if stage == .judging { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        }
        .onDisappear { speech.stop() }
    }

    private var header: some View {
        HStack {
            Button(action: onLeave) {
                Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                    .frame(width: 40, height: 40).background(.white.opacity(0.88), in: Circle())
            }
            .buttonStyle(.plain).foregroundStyle(.black)
            VStack(alignment: .leading, spacing: 2) {
                Text("5 Sekuntia").font(.system(size: 17, weight: .bold))
                Text("Huone \(players.count) pelaajalla").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            }
            Spacer()
            if state.isOver, let winner = players[state.winnerID ?? ""] {
                Text("🏆 \(winner.name)").font(.system(size: 13, weight: .bold))
            }
        }
        .padding(.horizontal, 2)
    }

    private var board: some View {
        GeometryReader { geo in
            ZStack {
                Image("FiveSecondsBoard")
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
                ForEach(state.playerOrder, id: \.self) { id in
                    if let index = state.positions[id], track.indices.contains(index),
                       let rawColor = players[id]?.pieceColor, let pieceColor = FiveSecondsColor(rawValue: rawColor) {
                        let point = track[index]
                        let sameSpace = state.playerOrder.filter { state.positions[$0] == index }.firstIndex(of: id) ?? 0
                        Circle()
                            .fill(pieceColor.color.gradient)
                            .frame(width: 25, height: 25)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                            .overlay(Text(String(players[id]?.name.prefix(1) ?? "?" )).font(.system(size: 11, weight: .heavy)).foregroundStyle(pieceColor.foreground))
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                            .position(x: geo.size.width * point.x + CGFloat(sameSpace * 9 - 4), y: geo.size.height * point.y + CGFloat(sameSpace * 8 - 4))
                            .accessibilityLabel("\(players[id]?.name ?? "Pelaaja"), ruutu \(index)")
                    }
                }
            }
        }
        .aspectRatio(618.0 / 1410.0, contentMode: .fit)
        .padding(.horizontal, 8)
    }

    private var drawDeck: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15).fill(Color.black.gradient)
                    Image("CardBack").resizable().scaledToFit().padding(14)
                }
                .frame(width: 100, height: 150)
                .shadow(color: .black.opacity(0.24), radius: 12, y: 7)
                .offset(y: cardIsMoving ? -80 : 0)
                .gesture(DragGesture(minimumDistance: 12).onEnded { value in
                    guard value.translation.height < -35, state.readerID == playerID, state.stage == .draw else { return }
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) { cardIsMoving = true }
                    onDraw()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { cardIsMoving = false }
                })
                .accessibilityLabel("Vedä kortti pakasta ylös nostaaksesi kysymyksen")
                VStack(alignment: .leading, spacing: 7) {
                    Text(state.readerID == playerID ? "SINUN VUOROSI" : "KYSYJÄ")
                        .font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(.secondary)
                    Text(players[state.readerID]?.name ?? "Pelaaja")
                        .font(.system(size: 18, weight: .bold))
                    Text("Vedä pakasta kortti ylös")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                    if state.readerID == playerID {
                        Button(action: onDraw) {
                            Label("Nosta kysymys", systemImage: "arrow.up")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(Color.black, in: Capsule()).foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 20))
            Text("Kolme vastausta ennen viiden sekunnin loppua")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
    }

    private var questionPanel: some View {
        VStack(spacing: 8) {
            if let action = state.specialCard {
                VStack(spacing: 8) {
                    Image(systemName: action == .skip ? "forward.end.fill" : "arrow.left.arrow.right")
                        .font(.system(size: 28, weight: .bold)).foregroundStyle(.red)
                    Text(action == .skip ? "OHITUS" : "VAIHTO")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                    if state.readerID == playerID {
                        Button("Käytä kortti") { onSpecial() }
                            .font(.system(size: 14, weight: .bold))
                            .padding(.horizontal, 22).padding(.vertical, 10)
                            .background(.black, in: Capsule()).foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.white, in: RoundedRectangle(cornerRadius: 18))
            } else {
                FiveSecondsPromptCard(text: state.question ?? "")
                    .frame(maxWidth: 195)
                    .overlay(alignment: .bottom) {
                        if state.stage == .reading {
                            Text("\(players[state.responderID]?.name ?? "Pelaaja") vastaa")
                                .font(.system(size: 12, weight: .semibold)).padding(.bottom, 19)
                        }
                    }
                if state.stage == .answering, let started = state.answerStartedAt {
                    FiveSecondsTimer(startedAt: started)
                        .frame(width: 52, height: 150)
                    HStack(spacing: 6) {
                        Image(systemName: speech.isListening && state.responderID == playerID ? "mic.fill" : "mic")
                            .foregroundStyle(speech.isListening ? .red : .secondary)
                        Text(state.responderID == playerID ? (speech.isListening ? "Kuuntelen…" : "Puhu nyt") : "\(players[state.responderID]?.name ?? "Pelaaja") vastaa")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .contentTransition(.symbolEffect(.replace))
                }
                if state.stage == .judging {
                    if !state.transcript.isEmpty {
                        Text("\"\(state.transcript)\"")
                            .font(.system(size: 13, weight: .medium)).multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    } else {
                        Text("Vastausta ei saatu litteroitua.")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    if state.judgeID == playerID {
                        HStack(spacing: 10) {
                            Button { onJudge(false) } label: { Label("Ei vielä", systemImage: "xmark") }
                                .buttonStyle(FiveSecondsDecisionStyle(positive: false))
                            Button { onJudge(true) } label: { Label("Onnistui", systemImage: "checkmark") }
                                .buttonStyle(FiveSecondsDecisionStyle(positive: true))
                        }
                    } else {
                        Text("Odotetaan pelaajan \(players[state.judgeID ?? state.readerID]?.name ?? "kysyjän") arviota")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    }
                }
            }
            if let message = speech.permissionMessage, state.responderID == playerID {
                Text(message).font(.system(size: 10)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20))
    }

    private var bottomStatus: some View {
        HStack(spacing: 6) {
            ForEach(state.playerOrder, id: \.self) { id in
                let color = FiveSecondsColor(rawValue: players[id]?.pieceColor ?? "")?.color ?? .gray
                HStack(spacing: 5) {
                    Circle().fill(color).frame(width: 9, height: 9).overlay(Circle().stroke(.black.opacity(0.18), lineWidth: 0.7))
                    Text(players[id]?.name ?? "Pelaaja").lineLimit(1)
                    Text("\(state.positions[id] ?? 0)/12").monospacedDigit()
                }
                .font(.system(size: 10, weight: id == state.responderID ? .bold : .medium))
                .padding(.horizontal, 8).padding(.vertical, 7)
                .background(id == state.responderID ? .white : .white.opacity(0.58), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 3)
    }
}

private struct FiveSecondsPromptCard: View {
    let text: String
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image("FiveSecondsQuestionTemplate")
                    .resizable().scaledToFit()
                Text(text)
                    .font(.system(size: min(geo.size.width * 0.105, 23), weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, geo.size.width * 0.12)
                    .frame(maxWidth: .infinity, maxHeight: geo.size.height * 0.53)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.53)
            }
            .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
        }
        .aspectRatio(826.0 / 1263.0, contentMode: .fit)
    }
}

private struct FiveSecondsTimer: View {
    let startedAt: TimeInterval
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.03)) { timeline in
            let remaining = max(0, 5 - timeline.date.timeIntervalSince1970 + startedAt)
            GeometryReader { geo in
                let progress = min(1, max(0, 1 - remaining / 5))
                ZStack(alignment: .bottom) {
                    Capsule().fill(Color.black.opacity(0.08))
                    Capsule().fill(remaining > 2.5 ? Color.yellow : Color.red)
                        .frame(height: geo.size.height * CGFloat(remaining / 5))
                    Circle().fill(remaining > 2.5 ? Color.yellow : Color.red)
                        .frame(width: 13, height: 13)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                        .rotationEffect(.degrees(timeline.date.timeIntervalSince1970 * 260))
                        .position(x: geo.size.width / 2, y: geo.size.height * progress)
                    Text("\(Int(ceil(remaining)))")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(remaining <= 2.5 ? .red : .black)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
            }
            .padding(4)
            .background(.white, in: Capsule())
        }
    }
}

private struct FiveSecondsDecisionStyle: ButtonStyle {
    let positive: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .padding(.horizontal, 14).padding(.vertical, 11)
            .foregroundStyle(positive ? .white : .black)
            .background(positive ? Color.black : Color.black.opacity(0.08), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.68), value: configuration.isPressed)
    }
}
