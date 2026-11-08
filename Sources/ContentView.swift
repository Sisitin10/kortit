import SwiftUI
import AudioToolbox
import UIKit

private enum Screen: Equatable { case home, room, table }

private enum AppPalette {
    static let ink = Color(red: 0.13, green: 0.13, blue: 0.13)
    static let muted = Color(red: 0.42, green: 0.41, blue: 0.39)
    static let accent = Color(red: 0.40, green: 0.13, blue: 0.16)
    static let paper = Color(red: 0.94, green: 0.945, blue: 0.95)
}

struct ContentView: View {
    @EnvironmentObject private var session: PlayerSession
    @StateObject private var game = CardGame()
    @State private var screen: Screen = .home
    @State private var activeTab = 0
    @State private var selectedGame: GameKind = .kakkahousu
    @State private var room: OnlineRoom?
    @State private var playerID = UUID().uuidString
    @State private var roomCode = ""
    @State private var faceCardsMinimum = 7
    @State private var showNewGame = false
    @State private var showScanner = false
    @State private var showSignIn = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if screen == .table {
                tableView
            } else {
                TabView(selection: $activeTab) {
            gameTab
                .tabItem { Label("Pelit", systemImage: "suit.spade.fill") }
                .tag(0)
            accountTab
                .tabItem { Label("Tili", systemImage: "person.crop.circle") }
                .tag(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppCanvas().ignoresSafeArea())
        .overlay {
            if screen != .table, showNewGame {
                gameModeOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(2)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showNewGame)
        .tint(AppPalette.ink)
        .sheet(isPresented: $showSignIn) { signInSheet }
        .sheet(isPresented: $showScanner) {
            QRScanner { code in
                roomCode = code
                showScanner = false
                Task { await joinRoom() }
            }
            .ignoresSafeArea()
        }
        .alert("Korttipelit", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .onOpenURL { url in
            guard let code = url.pathComponents.last, code != "/" else { return }
            roomCode = code.uppercased()
            activeTab = 0
            screen = .room
            Task { await joinRoom() }
        }
        .task { await session.restoreSession() }
        .preferredColorScheme(.light)
    }

    private var gameTab: some View {
        ZStack {
            AppCanvas()
            switch screen {
            case .home: home.transition(.opacity)
            case .room:
                if room == nil {
                    joinRoomView.transition(.opacity)
                } else {
                    roomLobby.transition(.opacity)
                }
            case .table: EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.24), value: screen)
        .alert("Kierros päättyi", isPresented: $game.isOver) {
            Button("Uusi jako") { Task { await restartGame() } }
            Button("Valmis", role: .cancel) { screen = .home; room = nil }
        } message: { Text(game.notice) }
    }

    private var home: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 11) {
                        BrandMark(size: 28, color: AppPalette.ink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Korttipelit").font(.system(size: 17, weight: .semibold))
                            Text("Kakkahousu · Musta Maija").font(.system(size: 12, weight: .regular)).foregroundStyle(AppPalette.muted)
                        }
                        Spacer()
                    }
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Valitse peli").font(.system(size: 27, weight: .semibold))
                        Text("Klassikot omalla korttipakalla.").font(.system(size: 15)).foregroundStyle(AppPalette.muted)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 14) {
                        ForEach(GameKind.allCases) { kind in
                            Button {
                                selectedGame = kind
                                showNewGame = true
                            } label: {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Text(kind == .kakkahousu ? "KLASSIKKO 01" : "KLASSIKKO 02")
                                            .font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(AppPalette.muted)
                                        Spacer()
                                        Text(kind == .kakkahousu ? "♠" : "♣")
                                            .font(.system(size: 24, weight: .regular)).foregroundStyle(AppPalette.accent)
                                    }
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(kind.rawValue).font(.system(size: 22, weight: .semibold))
                                        Text(kind.subtitle).font(.system(size: 14)).foregroundStyle(AppPalette.muted)
                                    }
                                    HStack(spacing: 7) {
                                        Text("PELAA").font(.system(size: 10, weight: .semibold)).tracking(1)
                                        Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold))
                                    }
                                    .foregroundStyle(AppPalette.accent)
                                }
                                .foregroundStyle(AppPalette.ink)
                                .padding(18)
                                .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
                                .cleanSurface(cornerRadius: 16)
                            }
                            .buttonStyle(.plain)
                            .scaleEffect(showNewGame && selectedGame == kind ? 0.985 : 1)
                            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: showNewGame)
                        }
                    }

                    Button {
                        room = nil
                        screen = .room
                    } label: {
                        HStack(spacing: 13) {
                            Image(systemName: "qrcode.viewfinder").font(.system(size: 19, weight: .medium)).foregroundStyle(AppPalette.accent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Liity huoneeseen").font(.system(size: 15, weight: .semibold))
                                Text("Huonekoodilla tai QR-koodilla").font(.system(size: 12)).foregroundStyle(AppPalette.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(AppPalette.muted)
                        }
                        .foregroundStyle(AppPalette.ink)
                        .padding(16)
                        .cleanSurface(cornerRadius: 16)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
            }
        }
    }

    private var gameModeOverlay: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
                .onTapGesture { showNewGame = false }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(selectedGame.rawValue)
                        .font(.system(size: 21, weight: .semibold))
                    Text("Valitse, miten haluat pelata.")
                        .font(.system(size: 14))
                        .foregroundStyle(AppPalette.muted)
                }
                .padding(.bottom, 4)

                if selectedGame == .kakkahousu {
                    modeChoice("Harjoittele yksin", detail: "Pelaa heti ilman huonetta", icon: "person") {
                        showNewGame = false
                        game.start(selectedGame, rules: KakkahousuRules(faceCardsMinimum: faceCardsMinimum))
                        room = nil
                        screen = .table
                    }
                }

                modeChoice("Luo online-huone", detail: "Kutsu ystävät koodilla tai QR:llä", icon: "person.2") {
                    showNewGame = false
                    Task { await createRoom() }
                }
                modeChoice("Liity huoneeseen", detail: "Käytä huonekoodia tai QR-kutsua", icon: "qrcode") {
                    showNewGame = false
                    room = nil
                    screen = .room
                }
            }
            .padding(20)
            .frame(maxWidth: 360)
            .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.black.opacity(0.08), lineWidth: 1))
            .padding(.horizontal, 28)
            .shadow(color: .black.opacity(0.14), radius: 28, y: 12)
            .accessibilityAddTraits(.isModal)
        }
    }

    private func modeChoice(_ title: String, detail: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppPalette.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(AppPalette.ink)
                    Text(detail).font(.system(size: 12)).foregroundStyle(AppPalette.muted)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(AppPalette.muted)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(AppPalette.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: showNewGame)
    }

    private var joinRoomView: some View {
        VStack(spacing: 0) {
            pageHeader("Liity peliin") { screen = .home; room = nil }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 17) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Pelikutsu").font(.system(size: 21, weight: .semibold))
                        Text("Syötä koodi tai skannaa hostin QR-koodi.").font(.system(size: 13)).foregroundStyle(AppPalette.muted)
                    }

                    HStack(spacing: 10) {
                        TextField("Huonekoodi", text: $roomCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .tracking(2)
                            .padding(.horizontal, 14)
                            .frame(height: 52)
                            .background(AppPalette.paper, in: RoundedRectangle(cornerRadius: 12))
                        Button { showScanner = true } label: {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(AppPalette.ink)
                                .frame(width: 52, height: 52)
                                .cleanSurface(cornerRadius: 12)
                        }
                        .buttonStyle(.plain)
                    }

                    Button { Task { await joinRoom() } } label: { primaryButton("Liity huoneeseen", icon: "arrow.right") }
                        .disabled(roomCode.count < 4 || session.isBusy)

                    Divider().overlay(Color.black.opacity(0.06)).padding(.vertical, 3)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Luo uusi huone").font(.system(size: 16, weight: .semibold))
                        ForEach(GameKind.allCases) { kind in
                            Button { selectedGame = kind } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selectedGame == kind ? "largecircle.fill.circle" : "circle")
                                        .foregroundStyle(selectedGame == kind ? AppPalette.accent : AppPalette.muted)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(kind.rawValue).font(.system(size: 14, weight: .medium))
                                        Text(kind.subtitle).font(.system(size: 12)).foregroundStyle(AppPalette.muted)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(AppPalette.ink)
                        }
                    }

                    if selectedGame == .kakkahousu { rulesPicker }
                    Button { Task { await createRoom() } } label: { primaryButton("Luo huone", icon: "plus") }
                        .disabled(session.isBusy)
                    if !session.isSignedIn {
                        Text("Online-peli vaatii kirjautumisen. Voit kirjautua Tili-välilehdellä.")
                            .font(.system(size: 12)).foregroundStyle(AppPalette.muted)
                    }
                }
                .padding(20)
                .cleanSurface(cornerRadius: 18)
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
            }
        }
    }

    private var roomLobby: some View {
        VStack(spacing: 0) {
            pageHeader("Huone") { screen = .home; room = nil }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    Text(room?.game.rawValue ?? "Peli")
                        .font(.system(size: 19, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let code = room?.code, let image = QRCode.make(from: "chromehearts://join/\(code)") {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 144, height: 144)
                            .padding(8)
                            .background(.white, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.08), lineWidth: 1))
                    }
                    Text(room?.code ?? "------")
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .tracking(4)
                    Text("Jaa koodi tai QR-kutsu pelaajille.")
                        .font(.system(size: 13)).foregroundStyle(AppPalette.muted)
                    VStack(spacing: 8) {
                        ForEach(Array((room?.players.values.sorted { $0.id < $1.id } ?? [])), id: \.id) { player in
                            HStack(spacing: 10) {
                                Image(systemName: "person.crop.circle.fill").font(.system(size: 19)).foregroundStyle(AppPalette.muted)
                                Text(player.name).font(.system(size: 14, weight: .medium))
                                Spacer()
                                if player.id == room?.hostID {
                                    Text("Host").font(.system(size: 12, weight: .medium)).foregroundStyle(AppPalette.accent)
                                }
                            }
                            .padding(.vertical, 9)
                            .overlay(alignment: .bottom) { Divider().overlay(Color.black.opacity(0.05)) }
                        }
                    }
                    if room?.hostID == playerID, room?.game == .kakkahousu { rulesPicker }
                    Button { Task { await beginGame() } } label: {
                        primaryButton(room?.hostID == playerID ? "Aloita peli" : "Odotetaan hostia", icon: "play.fill")
                    }
                    .disabled(room?.hostID != playerID || (room?.players.count ?? 0) < 2)
                    if (room?.players.count ?? 0) < 2 {
                        Text("Peli alkaa, kun vähintään yksi pelaaja liittyy.")
                            .font(.system(size: 12)).foregroundStyle(AppPalette.muted)
                    }
                }
                .padding(20)
                .cleanSurface(cornerRadius: 18)
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
            }
        }
        .task(id: room?.code) { await pollRoom() }
    }

    private var tableView: some View {
        GeometryReader { proxy in
            let tableCardWidth = min(120, proxy.size.width * 0.31)
            let tableCardHeight = tableCardWidth / 0.64
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button { screen = room == nil ? .home : .room } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppPalette.ink)
                            .frame(width: 40, height: 40)
                            .cleanSurface(cornerRadius: 12)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 3) {
                        Text((room?.game ?? game.game).rawValue).font(.system(size: 16, weight: .semibold))
                        Text(room.map { "Huone \($0.code)" } ?? "Harjoituspeli")
                            .font(.system(size: 12)).foregroundStyle(AppPalette.muted)
                    }
                    Spacer()
                    Button { Task { await restartGame() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppPalette.ink)
                            .frame(width: 40, height: 40)
                            .cleanSurface(cornerRadius: 12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)

                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 6) {
                        Button {
                            game.draw()
                            if game.actionSucceeded {
                                if room == nil { AudioServicesPlaySystemSound(1104) }
                                Task { await publishGame(advanceTurn: false) }
                            }
                        } label: {
                            CardBackView().frame(width: tableCardWidth, height: tableCardHeight)
                        }
                        .buttonStyle(.plain)
                        .disabled(!game.turn)
                    }

                    Spacer(minLength: 0)

                    ZStack {
                        ForEach(game.tableCards.suffix(6)) { card in
                            let seed = card.id.utf8.reduce(0) { $0 + Int($1) }
                            PlayingCardView(card: card)
                                .frame(width: tableCardWidth)
                                .rotationEffect(.degrees(Double(seed % 7 - 3)))
                                .offset(x: CGFloat(seed % 5 - 2) * 4, y: CGFloat(seed % 4) * 4)
                                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .scale).combined(with: .opacity), removal: .opacity))
                        }
                        if game.tableCards.isEmpty, let trump = game.maijaTrumpCard {
                            PlayingCardView(card: trump).frame(width: tableCardWidth)
                        }
                    }
                    .frame(width: tableCardWidth + 32, height: tableCardHeight + 22)
                    .contentShape(Rectangle())
                    .onTapGesture { playOrPickUpTable() }
                    .dropDestination(for: String.self) { cardIDs, _ in playDroppedCards(cardIDs) }
                    .animation(.spring(response: 0.38, dampingFraction: 0.78), value: game.tableCards)

                    Spacer(minLength: 0)

                }
                .padding(.horizontal, 18)
                .padding(.top, max(16, proxy.size.height * 0.025))

                Text(game.notice)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppPalette.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Spacer(minLength: 6)

                ScrollView(.horizontal, showsIndicators: false) {
                    let overlap = min(32, proxy.size.width * 0.082)
                    let cardWidth = min(104, max(80, (proxy.size.width - 40 + overlap * CGFloat(max(game.hand.count - 1, 0))) / CGFloat(max(game.hand.count, 1))))
                    HStack(spacing: -overlap) {
                        ForEach(game.hand) { card in
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) { game.toggle(card) }
                            } label: {
                                PlayingCardView(card: card)
                                    .frame(width: cardWidth)
                                    .offset(y: game.selected.contains(card.id) ? -16 : 0)
                                    .rotationEffect(.degrees(handAngle(for: card) * 2.5))
                                    .zIndex(game.selected.contains(card.id) ? 1 : 0)
                            }
                            .buttonStyle(.plain)
                            .draggable(card.id)
                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
                        }
                    }
                    .frame(minWidth: proxy.size.width - 40, alignment: .center)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                }
                .frame(height: min(205, proxy.size.height * 0.30))
                .animation(.spring(response: 0.32, dampingFraction: 0.82), value: game.selected)
                .padding(.bottom, max(12, proxy.safeAreaInsets.bottom))
            }
            .foregroundStyle(AppPalette.ink)
            .task(id: room?.code) { await pollGame() }
        }
    }

    private var accountTab: some View {
        ZStack {
            AppCanvas()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 11) {
                        BrandMark(size: 28, color: AppPalette.ink)
                        Text("Tili").font(.system(size: 23, weight: .semibold))
                    }
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 14) {
                        Text(session.isSignedIn ? "Kirjautunut" : "Kirjaudu online-peliä varten")
                            .font(.system(size: 17, weight: .semibold))
                        if session.isSignedIn {
                            Text(session.displayName).font(.system(size: 14)).foregroundStyle(AppPalette.muted)
                        } else {
                            Text("Tili tarvitaan huoneiden luomiseen ja niihin liittymiseen.")
                                .font(.system(size: 13)).foregroundStyle(AppPalette.muted)
                            TextField("Näyttönimi", text: $session.displayName)
                                .textContentType(.name)
                                .padding(13)
                                .background(AppPalette.paper, in: RoundedRectangle(cornerRadius: 12))
                            TextField("Sähköposti", text: $session.email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(13)
                                .background(AppPalette.paper, in: RoundedRectangle(cornerRadius: 12))
                        }
                        if let message = session.message {
                            Text(message).font(.system(size: 13)).foregroundStyle(AppPalette.muted)
                        }
                        Button { showSignIn = true } label: {
                            primaryButton(session.isSignedIn ? "Avaa kirjautuminen" : "Kirjaudu tai luo tili", icon: "person.crop.circle")
                        }
                        Button("Jatka vieraana") { session.playAsGuest() }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppPalette.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 2)
                    }
                    .padding(18)
                    .cleanSurface(cornerRadius: 18)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    private var rulesPicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Kuvakortit sallittu päälle").font(.system(size: 13, weight: .medium))
            Picker("Kuvakortit", selection: $faceCardsMinimum) {
                Text("7").tag(7)
                Text("8").tag(8)
                Text("9").tag(9)
            }
            .pickerStyle(.segmented)
        }
        .padding(13)
        .background(AppPalette.paper, in: RoundedRectangle(cornerRadius: 12))
        .onChange(of: faceCardsMinimum) { _, value in Task { await updateRoomRules(value) } }
    }

    private var signInSheet: some View {
        SignInPanel().environmentObject(session).presentationDetents([.medium, .large]).presentationDragIndicator(.visible).preferredColorScheme(.light)
    }

    private func pageHeader(_ title: String, back: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.ink)
                    .frame(width: 40, height: 40)
                    .cleanSurface(cornerRadius: 12)
            }
            .buttonStyle(.plain)
            Text(title).font(.system(size: 18, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private func primaryButton(_ title: String, icon: String) -> some View {
        HStack(spacing: 9) {
            Text(title).font(.system(size: 15, weight: .semibold))
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(AppPalette.ink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func handAngle(for card: PlayingCard) -> Double {
        guard game.hand.count > 1, let index = game.hand.firstIndex(of: card) else { return 0 }
        return Double(index - game.hand.count / 2) * 1.7
    }

    private func playOrPickUpTable() {
        guard game.turn else { return }
        guard !game.selected.isEmpty || !game.tableCards.isEmpty else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
            if game.selected.isEmpty {
                if !game.tableCards.isEmpty { game.pickupTable() }
            } else {
                game.playSelected()
            }
        }
        guard game.actionSucceeded else { return }
        if room == nil { AudioServicesPlaySystemSound(1104) }
        Task { await publishGame(advanceTurn: true) }
    }

    private func playDroppedCards(_ cardIDs: [String]) -> Bool {
        guard game.turn else { return false }
        let handIDs = Set(game.hand.map(\.id))
        game.selected.formUnion(cardIDs.filter { handIDs.contains($0) })
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { game.playSelected() }
        guard game.actionSucceeded else { return false }
        if room == nil { AudioServicesPlaySystemSound(1104) }
        Task { await publishGame(advanceTurn: true) }
        return true
    }

    private func createRoom() async {
        guard let token = session.idToken else { errorMessage = "Kirjaudu sähköpostilla ennen online-huoneen luontia."; activeTab = 1; showSignIn = true; return }
        do {
            let person = PlayerInfo(id: playerID, name: session.displayName)
            room = try await FirebaseService.shared.createRoom(game: selectedGame, player: person, token: token, rules: KakkahousuRules(faceCardsMinimum: faceCardsMinimum))
            screen = .room
        } catch { errorMessage = error.localizedDescription }
    }

    private func joinRoom() async {
        guard let token = session.idToken else { errorMessage = "Kirjaudu sähköpostilla ennen online-peliin liittymistä."; activeTab = 1; showSignIn = true; return }
        do {
            let person = PlayerInfo(id: playerID, name: session.displayName)
            room = try await FirebaseService.shared.joinRoom(code: roomCode, player: person, token: token)
            faceCardsMinimum = room?.kakkahousuFaceCardsMinimum ?? 7
            screen = .room
        } catch { errorMessage = error.localizedDescription }
    }

    private func pollRoom() async {
        guard let current = room, let token = session.idToken else { return }
        for await latest in FirebaseService.shared.observeRoom(code: current.code, token: token) {
            if Task.isCancelled || screen != .room { break }
            room = latest
            faceCardsMinimum = latest.kakkahousuFaceCardsMinimum ?? 7
            if let state = latest.gameState { game.apply(state, for: playerID); screen = .table }
        }
    }

    private func updateRoomRules(_ value: Int) async {
        guard var current = room, current.hostID == playerID, let token = session.idToken, current.gameState == nil else { return }
        current.kakkahousuFaceCardsMinimum = value
        current.updatedAt = Date().timeIntervalSince1970
        do { try await FirebaseService.shared.save(current, token: token); room = current }
        catch { errorMessage = error.localizedDescription }
    }

    private func beginGame() async {
        guard var current = room, let token = session.idToken, current.hostID == playerID else { return }
        let rules = KakkahousuRules(faceCardsMinimum: current.kakkahousuFaceCardsMinimum ?? faceCardsMinimum)
        let state = game.startOnline(current.game, playerIDs: Array(current.players.keys), hostID: current.hostID, rules: rules)
        current.gameState = state
        for id in Array(current.players.keys) { current.players[id]?.handCount = state.hands[id]?.count ?? 0 }
        current.updatedAt = Date().timeIntervalSince1970
        do {
            try await FirebaseService.shared.save(current, token: token)
            room = current
            game.apply(state, for: playerID)
            screen = .table
        } catch { errorMessage = error.localizedDescription }
    }

    private func publishGame(advanceTurn: Bool) async {
        guard var current = room, let state = current.gameState, let token = session.idToken else { return }
        current.gameState = game.snapshot(from: state, advanceTurn: advanceTurn)
        for id in Array(current.players.keys) { current.players[id]?.handCount = current.gameState?.hands[id]?.count ?? 0 }
        current.updatedAt = Date().timeIntervalSince1970
        do { try await FirebaseService.shared.save(current, token: token); room = current }
        catch { errorMessage = error.localizedDescription }
    }

    private func restartGame() async {
        guard let current = room else { game.start(game.game, rules: KakkahousuRules(faceCardsMinimum: faceCardsMinimum)); return }
        guard current.hostID == playerID else { errorMessage = "Vain pelinjohtaja voi aloittaa uuden jaon."; return }
        await beginGame()
    }

    private func pollGame() async {
        guard let current = room, let token = session.idToken else { return }
        for await latest in FirebaseService.shared.observeRoom(code: current.code, token: token) {
            if Task.isCancelled || screen != .table { break }
            if let state = latest.gameState, latest.updatedAt >= current.updatedAt {
                game.apply(state, for: playerID)
                room = latest
            }
        }
    }
}

private struct SignInPanel: View {
    @EnvironmentObject private var session: PlayerSession
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var create = false

    var body: some View {
        ZStack {
            AppCanvas()
            ScrollView {
                VStack(spacing: 14) {
                    Text(create ? "Luo tili" : "Kirjaudu")
                        .font(.system(size: 22, weight: .semibold))
                    TextField("Näyttönimi", text: $session.displayName)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .padding(13)
                        .background(AppPalette.paper, in: RoundedRectangle(cornerRadius: 12))
                    TextField("Sähköposti", text: $session.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(13)
                        .background(AppPalette.paper, in: RoundedRectangle(cornerRadius: 12))
                    SecureField("Salasana", text: $password)
                        .textContentType(create ? .newPassword : .password)
                        .padding(13)
                        .background(AppPalette.paper, in: RoundedRectangle(cornerRadius: 12))
                    if let message = session.message {
                        Text(message).font(.system(size: 13)).foregroundStyle(AppPalette.muted)
                    }
                    Button {
                        Task {
                            await session.signIn(createAccount: create, password: password)
                            if session.isSignedIn { dismiss() }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(create ? "Luo tili" : "Kirjaudu")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppPalette.ink, in: RoundedRectangle(cornerRadius: 14))
                    }
                    Button(create ? "Minulla on jo tili" : "Luo uusi tili") { create.toggle() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.muted)
                    Button("Jatka vieraana") { session.playAsGuest(); dismiss() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.muted)
                }
                .padding(20)
                .cleanSurface(cornerRadius: 18)
                .padding(18)
            }
        }
    }
}
