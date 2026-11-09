import SwiftUI
import AudioToolbox
import AVFoundation
import UIKit
import PhotosUI

private enum Screen: Equatable { case home, host, createRoom, room, table }

private enum AppPalette {
    static let ink = Color.primary
    static let muted = Color.secondary
    static let accent = Color(red: 0.40, green: 0.13, blue: 0.16)
    static let paper = Color(uiColor: .tertiarySystemBackground)
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
    @State private var showScanner = false
    @State private var showSignIn = false
    @State private var errorMessage: String?
    @AppStorage("appearanceDarkMode") private var darkMode = false
    @AppStorage("brandPatternEnabled") private var brandPatternEnabled = false
    @AppStorage("quickHostEnabled") private var quickHostEnabled = false
    @AppStorage("gamesWon") private var gamesWon = 0
    @AppStorage("gamesLost") private var gamesLost = 0
    @AppStorage("profilePhotoData") private var profilePhotoData = ""
    @State private var showQuickHostSettings = false
    @State private var selectedProfilePhoto: PhotosPickerItem?
    @State private var cardSwapPlayer: AVAudioPlayer?

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
                .tabItem { Label("Asetukset", systemImage: "gearshape") }
                .tag(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppCanvas().ignoresSafeArea())
        .tint(AppPalette.ink)
        .sheet(isPresented: $showSignIn) { signInSheet }
        .sheet(isPresented: $showScanner) { scannerSheet }
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
        .task {
            await session.restoreSession()
            if let url = Bundle.main.url(forResource: "card-swap", withExtension: "mp3") {
                cardSwapPlayer = try? AVAudioPlayer(contentsOf: url)
                cardSwapPlayer?.prepareToPlay()
            }
        }
        .onChange(of: game.drawSoundSequence) { _, _ in
            cardSwapPlayer?.currentTime = 0
            cardSwapPlayer?.play()
        }
        .onChange(of: game.isOver) { _, over in
            guard over else { return }
            if game.notice.localizedCaseInsensitiveContains("voitit") { gamesWon += 1 } else { gamesLost += 1 }
        }
        .preferredColorScheme(darkMode ? .dark : .light)
    }

    private var gameTab: some View {
        ZStack {
            AppCanvas()
            if brandPatternEnabled { BrandPatternBackground() }
            switch screen {
            case .home: home.transition(.opacity)
            case .host: hostMenu.transition(.move(edge: .trailing).combined(with: .opacity))
            case .createRoom: createRoomView.transition(.move(edge: .trailing).combined(with: .opacity))
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
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 12) {
                        BrandMark(size: 30, color: AppPalette.ink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Korttipelit").font(.system(size: 18, weight: .semibold))
                            Text("Klassikot korttipöydässä").font(.system(size: 12)).foregroundStyle(AppPalette.muted)
                        }
                        Spacer()
                        Button { showQuickHostSettings = true } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .medium))
                                .frame(width: 42, height: 42)
                                .appGlass(cornerRadius: 21)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Lisää pikakuvake")
                    }
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Pelikutsut").font(.system(size: 29, weight: .semibold))
                        Text("Valitse pöytä ja kutsu ystävät mukaan.").font(.system(size: 14)).foregroundStyle(AppPalette.muted)
                    }

                    HStack(spacing: 12) {
                        statTile(title: "VOITOT", value: gamesWon, color: Color(red: 0.12, green: 0.48, blue: 0.28), icon: "trophy")
                        statTile(title: "TAPPIOIT", value: gamesLost, color: Color(red: 0.66, green: 0.16, blue: 0.20), icon: "flag")
                    }

                    VStack(spacing: 12) {
                        Button {
                            if quickHostEnabled {
                                selectedGame = .kakkahousu
                                faceCardsMinimum = 7
                                Task { await createRoom() }
                            } else {
                                withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) { screen = .host }
                            }
                        } label: {
                            homeAction(title: quickHostEnabled ? "Pikaisäntä · Kakkahousu" : "Isännöi peliä", detail: quickHostEnabled ? "Kakkahousu · 7 kortin sääntö" : "Valitse peli ja huoneen säännöt", icon: "person.2.fill", prominent: true)
                        }
                        .buttonStyle(.plain)

                        Button {
                            room = nil
                            roomCode = ""
                            showScanner = true
                        } label: {
                            homeAction(title: "Liity peliin", detail: "Skannaa QR-koodi tai käytä huonekoodia", icon: "qrcode.viewfinder", prominent: false)
                        }
                        .buttonStyle(.plain)
                    }

                    if quickHostEnabled {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill").foregroundStyle(AppPalette.accent)
                            Text("PIKAKUTSU").font(.system(size: 10, weight: .semibold)).tracking(1.4)
                            Text("Kakkahousu · 7 kortin sääntö").font(.system(size: 12)).foregroundStyle(AppPalette.muted)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cleanSurface(cornerRadius: 14)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
            }
        }
        .sheet(isPresented: $showQuickHostSettings) { quickHostSheet }
    }

    private var hostMenu: some View {
        VStack(alignment: .leading, spacing: 22) {
            pageHeader("Isännöi peliä") { withAnimation { screen = .home } }
            VStack(alignment: .leading, spacing: 5) {
                Text("Valitse peli").font(.system(size: 28, weight: .semibold))
                Text("Luo huone ja jaa kutsu QR-koodilla.").font(.system(size: 14)).foregroundStyle(AppPalette.muted)
            }
            ForEach(GameKind.allCases) { kind in
                Button {
                    selectedGame = kind
                    room = nil
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) { screen = .createRoom }
                } label: {
                    homeAction(title: kind.rawValue, detail: kind.subtitle, icon: kind == .kakkahousu ? "suit.spade.fill" : "suit.club.fill", prominent: false)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .frame(maxWidth: 540, maxHeight: .infinity, alignment: .top)
        .frame(maxWidth: .infinity)
    }

    private func statTile(title: String, value: Int, color: Color, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 15, weight: .medium)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 9, weight: .semibold)).tracking(1.1).foregroundStyle(AppPalette.muted)
                Text("\(value)").font(.system(size: 24, weight: .semibold, design: .rounded)).foregroundStyle(color)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cleanSurface(cornerRadius: 15)
    }

    private func homeAction(title: String, detail: String, icon: String, prominent: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 19, weight: .medium))
                .foregroundStyle(prominent ? Color.white : AppPalette.accent)
                .frame(width: 42, height: 42)
                .background(prominent ? Color.white.opacity(0.13) : AppPalette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(prominent ? Color.white.opacity(0.74) : AppPalette.muted)
            }
            Spacer(minLength: 3)
            Image(systemName: "arrow.right").font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(prominent ? Color.white : AppPalette.ink)
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 76)
        .background {
            if prominent { RoundedRectangle(cornerRadius: 17, style: .continuous).fill(Color.black) }
            else { RoundedRectangle(cornerRadius: 17, style: .continuous).fill(Color(uiColor: .secondarySystemBackground)) }
        }
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Color.primary.opacity(prominent ? 0 : 0.07), lineWidth: 1))
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

    private var createRoomView: some View {
        VStack(spacing: 0) {
            pageHeader("Uusi huone") { withAnimation { screen = .host } }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Valitse pelin säännöt")
                        .font(.system(size: 25, weight: .semibold))
                    ForEach(GameKind.allCases) { kind in
                        Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedGame = kind } } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedGame == kind ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(selectedGame == kind ? AppPalette.accent : AppPalette.muted)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(kind.rawValue).font(.system(size: 16, weight: .semibold))
                                    Text(kind.subtitle).font(.system(size: 12)).foregroundStyle(AppPalette.muted)
                                }
                                Spacer()
                            }
                            .padding(15).cleanSurface(cornerRadius: 14)
                        }.buttonStyle(.plain).foregroundStyle(AppPalette.ink)
                    }
                    if selectedGame == .kakkahousu { rulesPicker }
                    Button { Task { await createRoom() } } label: { primaryButton("Luo huone", icon: "plus") }
                        .disabled(session.isBusy)
                    if !session.isSignedIn {
                        Text("Kirjaudu sisään avataksesi online-huoneen.")
                            .font(.system(size: 12)).foregroundStyle(AppPalette.muted)
                    }
                }
                .padding(20).cleanSurface(cornerRadius: 18)
                .padding(.horizontal, 18).padding(.vertical, 18)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
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
                            drawFromDeck()
                        } label: {
                            ZStack {
                                if game.game == .mustaMaija, let trump = game.maijaTrumpCard {
                                    if game.faceDownDeckCount > 0 {
                                        PlayingCardView(card: trump)
                                            .frame(width: tableCardWidth, height: tableCardHeight)
                                            .rotationEffect(.degrees(90))
                                            .offset(y: tableCardHeight * 0.3)
                                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                                    } else {
                                        PlayingCardView(card: trump)
                                            .frame(width: tableCardWidth, height: tableCardHeight)
                                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                                    }
                                }
                                if game.faceDownDeckCount > 0 {
                                    CardBackView().frame(width: tableCardWidth, height: tableCardHeight)
                                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                                }
                            }
                            .frame(width: tableCardWidth, height: tableCardHeight)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!game.canDrawFromDeck)
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
                    }
                    .frame(width: tableCardWidth, height: tableCardHeight)
                    .contentShape(Rectangle())
                    .onTapGesture { playOrPickUpTable() }
                    .dropDestination(for: String.self) { cardIDs, _ in playDroppedCards(cardIDs) }
                    .animation(.spring(response: 0.38, dampingFraction: 0.78), value: game.tableCards)

                    Spacer(minLength: 0)

                }
                .padding(.horizontal, 18)
                .padding(.top, max(16, proxy.size.height * 0.025))

                VStack(spacing: 7) {
                    Text(game.notice)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppPalette.ink)
                        .multilineTextAlignment(.center)
                    if game.shouldPromptToDraw {
                        Button { drawFromDeck() } label: {
                            Label("Nosta kortti", systemImage: "arrow.down.to.line")
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                .appGlass(cornerRadius: 17)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppPalette.ink)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
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
                .animation(.spring(response: 0.34, dampingFraction: 0.8), value: game.shouldPromptToDraw)
                .padding(.bottom, max(12, proxy.safeAreaInsets.bottom))
            }
            .foregroundStyle(AppPalette.ink)
            .background {
                ZStack {
                    AppCanvas()
                    if brandPatternEnabled { BrandPatternBackground() }
                }
            }
            .task(id: room?.code) { await pollGame() }
        }
    }

    private var accountTab: some View {
        ZStack {
            AppCanvas()
            if brandPatternEnabled { BrandPatternBackground() }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Asetukset").font(.system(size: 29, weight: .semibold)).padding(.top, 14)
                    HStack(spacing: 14) {
                        PhotosPicker(selection: $selectedProfilePhoto, matching: .images) {
                            profileAvatar(size: 58)
                        }.buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.displayName).font(.system(size: 17, weight: .semibold))
                            Text(session.isSignedIn ? session.email : "Vieraspelaaja")
                                .font(.system(size: 12)).foregroundStyle(AppPalette.muted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(AppPalette.muted)
                    }
                    .padding(15).cleanSurface(cornerRadius: 16)
                    .onTapGesture { if !session.isSignedIn { showSignIn = true } }

                    VStack(alignment: .leading, spacing: 0) {
                        settingsRow("Tumma tila", detail: "Myös korttien kuvat käännetään", icon: "moon.fill") {
                            Toggle("Tumma tila", isOn: $darkMode).labelsHidden()
                        }
                        Divider().padding(.leading, 46)
                        settingsRow("Kuviotausta", detail: "Häivytetty logo pelipöydän taustalla", icon: "sparkles") {
                            Toggle("Kuviotausta", isOn: $brandPatternEnabled).labelsHidden()
                        }
                    }
                    .padding(.horizontal, 14).cleanSurface(cornerRadius: 16)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("PELAAJAN TILI").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(AppPalette.muted)
                        if session.isSignedIn {
                            Text("Kirjautuminen on tallennettu tälle laitteelle.")
                                .font(.system(size: 13)).foregroundStyle(AppPalette.muted)
                            Button("Kirjaudu ulos", role: .destructive) { session.playAsGuest() }
                                .font(.system(size: 14, weight: .medium))
                        } else {
                            Text("Kirjaudu sisään luodaksesi online-huoneita ja liittyäksesi niihin.")
                                .font(.system(size: 13)).foregroundStyle(AppPalette.muted)
                            Button { showSignIn = true } label: { primaryButton("Kirjaudu tai luo tili", icon: "person.crop.circle") }
                            Button("Jatka vieraana") { session.playAsGuest() }
                                .font(.system(size: 13, weight: .medium)).foregroundStyle(AppPalette.muted)
                        }
                        if let message = session.message { Text(message).font(.system(size: 12)).foregroundStyle(AppPalette.muted) }
                    }
                    .padding(16).cleanSurface(cornerRadius: 16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .onChange(of: selectedProfilePhoto) { _, item in
            Task {
                guard let item,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let jpeg = image.jpegData(compressionQuality: 0.78) else { return }
                profilePhotoData = jpeg.base64EncodedString()
            }
        }
    }

    private func profileAvatar(size: CGFloat) -> some View {
        Group {
            if let data = Data(base64Encoded: profilePhotoData), let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundStyle(AppPalette.muted.opacity(0.55)).padding(8)
            }
        }
        .frame(width: size, height: size).background(AppPalette.paper)
        .clipShape(Circle()).overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }

    private func settingsRow<Accessory: View>(_ title: String, detail: String, icon: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15, weight: .medium)).foregroundStyle(AppPalette.accent).frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .medium))
                Text(detail).font(.system(size: 11)).foregroundStyle(AppPalette.muted)
            }
            Spacer(minLength: 6)
            accessory()
        }
        .padding(.vertical, 13)
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

    private var quickHostSheet: some View {
        NavigationStack {
            Form {
                Section("Pikakuvake") {
                    Toggle("Pikaisännöi Kakkahousu", isOn: $quickHostEnabled)
                    Text("Lisää aloitusnäkymään yhden kosketuksen toiminnon, joka avaa Kakkahousu-huoneen 7 kortin säännöllä.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Aloitusnäkymän kuvake")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Valmis") { showQuickHostSettings = false } }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var scannerSheet: some View {
        ZStack {
            QRScanner { code in
                roomCode = code
                showScanner = false
                Task { await joinRoom() }
            }
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Liity peliin").font(.system(size: 18, weight: .semibold))
                        Text("Kohdista kamera QR-koodiin").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { showScanner = false } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                            .frame(width: 38, height: 38).appGlass(cornerRadius: 19)
                    }.buttonStyle(.plain)
                }
                .padding(16).appGlass(cornerRadius: 20).padding(.horizontal, 16).padding(.top, 12)
                Spacer()
                Button {
                    showScanner = false
                    room = nil
                    screen = .room
                } label: {
                    Label("Liity huonekoodilla", systemImage: "number")
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 20).frame(height: 50).appGlass(cornerRadius: 25)
                }
                .buttonStyle(.plain).padding(.bottom, 22)
            }
        }
        .ignoresSafeArea()
        .presentationBackground(.black)
    }

    private var signInSheet: some View {
        SignInPanel().environmentObject(session).presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
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
        .background(Color.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .foregroundStyle(Color(uiColor: .systemBackground))
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
        Task { await publishGame(advanceTurn: game.game == .mustaMaija || !game.mustRefillAfterPlay) }
    }

    private func drawFromDeck() {
        let completesKakkahousuTurn = game.game == .kakkahousu && game.mustRefillAfterPlay
        game.draw()
        guard game.actionSucceeded else { return }
        Task { await publishGame(advanceTurn: completesKakkahousuTurn) }
    }

    private func playDroppedCards(_ cardIDs: [String]) -> Bool {
        guard game.turn else { return false }
        let handIDs = Set(game.hand.map(\.id))
        game.selected.formUnion(cardIDs.filter { handIDs.contains($0) })
        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) { game.playSelected() }
        guard game.actionSucceeded else { return false }
        if room == nil { AudioServicesPlaySystemSound(1104) }
        Task { await publishGame(advanceTurn: game.game == .mustaMaija || !game.mustRefillAfterPlay) }
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
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.primary, in: RoundedRectangle(cornerRadius: 14))
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
