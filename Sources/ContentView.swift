import SwiftUI
import AudioToolbox
import UIKit

private enum Screen { case home, room, table }

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
        TabView(selection: $activeTab) {
            gameTab
                .tabItem { Label("Pelit", systemImage: "suit.spade.fill") }
                .tag(0)
            accountTab
                .tabItem { Label("Tili", systemImage: "person.crop.circle") }
                .tag(1)
        }
        .tint(Color(red: 0.12, green: 0.12, blue: 0.13))
        .toolbar(screen == .table ? .hidden : .visible, for: .tabBar)
        .sheet(isPresented: $showSignIn) { signInSheet }
        .sheet(isPresented: $showScanner) {
            QRScanner { code in
                roomCode = code
                showScanner = false
                Task { await joinRoom() }
            }
            .ignoresSafeArea()
        }
        .alert("Chrome Hearts", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .onOpenURL { url in
            guard let code = url.pathComponents.last, code != "/" else { return }
            roomCode = code.uppercased()
            activeTab = 0
            screen = .room
            Task { await joinRoom() }
        }
        .preferredColorScheme(.light)
    }

    private var gameTab: some View {
        ZStack {
            VelvetBackground()
            switch screen {
            case .home: home
            case .room:
                if room == nil {
                    joinRoomView
                } else {
                    roomLobby
                }
            case .table: tableView
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: screen == .table)
        .alert("Kierros päättyi", isPresented: $game.isOver) {
            Button("Uusi jako") { Task { await restartGame() } }
            Button("Valmis", role: .cancel) { screen = .home; room = nil }
        } message: { Text(game.notice) }
    }

    private var home: some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        BrandCross(size: 26, color: .black)
                        Text("CHROME HEARTS").font(.system(size: 12, weight: .black, design: .serif)).tracking(2.2)
                        Spacer()
                        Button { activeTab = 1 } label: {
                            Label(session.isSignedIn ? session.displayName : "Kirjaudu", systemImage: "person.crop.circle")
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.primary)
                        }.buttonStyle(.plain)
                    }.padding(.top, 8)

                    VStack(spacing: 10) {
                        BrandCross(size: min(58, proxy.size.width * 0.15), color: Color(red: 0.13, green: 0.13, blue: 0.14))
                        Text("CHROME HEARTS").font(.system(size: min(25, proxy.size.width * 0.065), weight: .black, design: .serif)).tracking(1.4)
                        Text("KORTTIPELI").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(5).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).padding(.top, max(16, proxy.size.height * 0.03)).padding(.bottom, max(18, proxy.size.height * 0.035))

                    VStack(spacing: 12) {
                        ForEach(GameKind.allCases) { kind in
                            Button { selectedGame = kind; showNewGame = true } label: {
                                HStack(spacing: 16) {
                                    Text(kind == .kakkahousu ? "♠" : "♣").font(.system(size: 28, weight: .regular)).foregroundStyle(Color(red: 0.34, green: 0.29, blue: 0.23)).frame(width: 38)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(kind.rawValue.uppercased()).font(.system(size: 12, weight: .bold, design: .serif)).tracking(1)
                                        Text(kind.subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 8)
                                    Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                                }
                                .foregroundStyle(.primary).padding(.horizontal, 15).frame(height: 64)
                                .premiumGlass(cornerRadius: 18)
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.75), lineWidth: 0.8))
                                .shadow(color: .black.opacity(0.045), radius: 14, y: 7)
                            }.buttonStyle(.plain)
                        }
                    }

                    Button { screen = .room } label: {
                        HStack(spacing: 8) { Image(systemName: "qrcode.viewfinder"); Text("LIITY HUONEESEEN") }
                            .font(.system(size: 10, weight: .bold)).tracking(1.3).foregroundStyle(.primary)
                            .frame(maxWidth: .infinity).frame(height: 48).premiumGlass(cornerRadius: 24)
                    }.buttonStyle(.plain).padding(.top, 12)

                    HStack(spacing: 8) { BrandCross(size: 14, color: .black.opacity(0.4)); Text("YHDESSÄ PÖYDÄN ÄÄREEN").tracking(2).font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary); BrandCross(size: 14, color: .black.opacity(0.4)) }
                        .padding(.top, 28).padding(.bottom, 16)
                }
                .padding(.horizontal, 22)
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
        }
        .confirmationDialog(selectedGame.rawValue, isPresented: $showNewGame, titleVisibility: .visible) {
            if selectedGame == .kakkahousu {
                Button("Harjoittele paikallisesti") { game.start(selectedGame, rules: KakkahousuRules(faceCardsMinimum: faceCardsMinimum)); room = nil; screen = .table }
            }
            Button("Luo online-huone") { Task { await createRoom() } }
            Button("Liity koodilla / QR") { screen = .room }
            Button("Peruuta", role: .cancel) { }
        } message: { Text("Valitse pelitapa") }
    }

    private var joinRoomView: some View {
        VStack(spacing: 0) {
            pageHeader("PELIHUONE") { screen = .home }
            Spacer(minLength: 18)
            VStack(spacing: 15) {
                Text("LIITY PELIIN").font(.system(size: 11, weight: .bold)).tracking(3).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    TextField("HUONEKOODI", text: $roomCode).textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .font(.system(size: 21, weight: .bold, design: .monospaced)).tracking(5).multilineTextAlignment(.center)
                        .padding(15).background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 14))
                    Button { showScanner = true } label: {
                        Image(systemName: "qrcode.viewfinder").font(.system(size: 22, weight: .medium)).frame(width: 56, height: 56).premiumGlass(cornerRadius: 14)
                    }
                }
                Button { Task { await joinRoom() } } label: { primaryButton("LIITY HUONEESEEN", icon: "arrow.right") }
                    .disabled(roomCode.count < 4 || session.isBusy)
                Rectangle().fill(.black.opacity(0.08)).frame(height: 1).padding(.vertical, 5)
                Text("LUO UUSI HUONE").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(.secondary)
                HStack(spacing: 9) {
                    ForEach(GameKind.allCases) { kind in
                        Button { selectedGame = kind } label: {
                            Text(kind.rawValue).font(.system(size: 11, weight: .bold)).frame(maxWidth: .infinity).padding(13)
                                .background(selectedGame == kind ? .black.opacity(0.09) : .white.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(selectedGame == kind ? 0.18 : 0.06)))
                        }.buttonStyle(.plain).foregroundStyle(.primary)
                    }
                }
                if selectedGame == .kakkahousu { rulesPicker }
                Button { Task { await createRoom() } } label: { primaryButton("LUO HUONE", icon: "plus") }.disabled(session.isBusy)
                if !session.isSignedIn {
                    Button("Kirjaudu sisään online-peliä varten") { activeTab = 1 }
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary).padding(20).premiumGlass(cornerRadius: 24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.8), lineWidth: 0.8))
            .padding(.horizontal, 20)
            Spacer(minLength: 24)
        }
    }

    private var roomLobby: some View {
        VStack(spacing: 14) {
            pageHeader("PELIHUONE") { screen = .home; room = nil }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    Text(room?.game.rawValue.uppercased() ?? "PELIHUONE").font(.system(size: 11, weight: .bold)).tracking(3).foregroundStyle(.secondary)
                    Text(room?.code ?? "------").font(.system(size: 32, weight: .black, design: .monospaced)).tracking(7)
                    if let code = room?.code, let image = QRCode.make(from: "chromehearts://join/\(code)") {
                        Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(width: 150, height: 150).padding(8).background(.white, in: RoundedRectangle(cornerRadius: 16)).shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                    }
                    Text("Skannaa QR tai jaa huonekoodi kavereille.").font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    VStack(spacing: 9) {
                        ForEach(Array((room?.players.values.sorted { $0.id < $1.id } ?? [])), id: \.id) { player in
                            HStack(spacing: 10) {
                                Image(systemName: "person.crop.circle.fill").font(.system(size: 20)).foregroundStyle(.secondary)
                                Text(player.name).font(.system(size: 13, weight: .semibold))
                                Spacer()
                                if player.id == room?.hostID { Text("HOST").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.secondary) }
                            }.padding(11).background(.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }.frame(maxWidth: .infinity)
                    if room?.hostID == playerID, room?.game == .kakkahousu { rulesPicker }
                    Button { Task { await beginGame() } } label: { primaryButton(room?.hostID == playerID ? "ALOITA PELI" : "ODOTA PELINJOHTAJAA", icon: "play.fill") }
                        .disabled(room?.hostID != playerID || (room?.players.count ?? 0) < 2)
                    if (room?.players.count ?? 0) < 2 { Text("Aloita, kun vähintään yksi kaveri liittyy.").font(.system(size: 10)).foregroundStyle(.secondary) }
                }
                .padding(22).frame(maxWidth: 500).frame(maxWidth: .infinity)
                .premiumGlass(cornerRadius: 24).overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.8), lineWidth: 0.8))
                .padding(.horizontal, 18).padding(.bottom, 20)
            }
        }
        .task(id: room?.code) { await pollRoom() }
    }

    private var tableView: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                HStack(spacing: 11) {
                    Button { screen = room == nil ? .home : .room } label: { Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold)).frame(width: 38, height: 38).premiumGlass(cornerRadius: 20) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text((room?.game ?? game.game).rawValue.uppercased()).font(.system(size: 11, weight: .bold)).tracking(1.4)
                        Text(room.map { "HUONE \($0.code)" } ?? "PAIKALLINEN PELI").font(.system(size: 9, weight: .medium)).tracking(1.1).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { Task { await restartGame() } } label: { Image(systemName: "arrow.clockwise").font(.system(size: 13, weight: .bold)).frame(width: 38, height: 38).premiumGlass(cornerRadius: 20) }
                }.padding(.horizontal, 16).padding(.top, 6).foregroundStyle(.primary)

                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 7) {
                        Button { game.draw(); if game.actionSucceeded { if room == nil { AudioServicesPlaySystemSound(1104) }; Task { await publishGame(advanceTurn: false) } } } label: {
                            CardBackView().frame(width: min(60, proxy.size.width * 0.16), height: min(92, proxy.size.width * 0.24))
                        }.buttonStyle(.plain).disabled(!game.turn || game.game == .mustaMaija)
                        Text("PAKKA · \(game.deckCount)").font(.system(size: 9, weight: .bold)).tracking(0.8).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    VStack(spacing: 7) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.42)).frame(width: min(88, proxy.size.width * 0.23), height: min(120, proxy.size.width * 0.31))
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(.black.opacity(0.07), style: StrokeStyle(lineWidth: 1, dash: [5, 5])))
                            if let top = game.tableCards.last {
                                PlayingCardView(card: top).frame(width: min(64, proxy.size.width * 0.17)).rotationEffect(.degrees(Double(top.rank % 5 - 2))).transition(.move(edge: .top).combined(with: .scale))
                            } else if game.game == .mustaMaija, let trump = game.maijaTrumpCard {
                                PlayingCardView(card: trump).frame(width: min(64, proxy.size.width * 0.17)).transition(.move(edge: .top).combined(with: .scale))
                            } else { BrandCross(size: 35, color: .black.opacity(0.16)) }
                        }
                        Text(game.game == .mustaMaija ? "VALTTI · \(game.maijaTrumpSuit?.glyph ?? "–")" : "PÖYTÄ · \(game.tableCards.count)").font(.system(size: 9, weight: .bold)).tracking(0.8).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 8) {
                        let others = room?.players.values.filter { $0.id != playerID }.sorted { $0.id < $1.id } ?? []
                        ForEach(others.prefix(3)) { player in playerBadge(player.name, count: player.handCount) }
                        playerBadge(session.displayName, count: game.hand.count, isLocal: true)
                    }.frame(maxWidth: proxy.size.width * 0.28, alignment: .trailing)
                }
                .padding(.horizontal, 20).padding(.top, max(20, proxy.size.height * 0.035))

                HStack(spacing: 7) {
                    Circle().fill(game.turn ? Color.green.opacity(0.8) : Color.gray.opacity(0.7)).frame(width: 6, height: 6)
                    Text(game.notice).font(.system(size: 11, weight: .medium)).lineLimit(2).multilineTextAlignment(.center)
                }
                .foregroundStyle(.primary.opacity(0.75)).padding(.horizontal, 15).padding(.vertical, 10)
                .premiumGlass(cornerRadius: 22).padding(.horizontal, 22).padding(.top, 17)

                if !game.tableCards.isEmpty {
                    Button { withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) { game.pickupTable() }; if game.actionSucceeded { if room == nil { AudioServicesPlaySystemSound(1104) }; Task { await publishGame(advanceTurn: true) } } } label: {
                        Label(game.game == .mustaMaija ? "OTA KORTIT" : "NOSTA PÖYTÄ", systemImage: "arrow.down.to.line").font(.system(size: 9, weight: .bold)).tracking(1.1).padding(.horizontal, 15).padding(.vertical, 8).premiumGlass(cornerRadius: 18)
                    }.disabled(!game.turn).padding(.top, 8)
                }

                Spacer(minLength: 4)
                if !game.selected.isEmpty, let preview = game.hand.first(where: { game.selected.contains($0.id) }) {
                    HStack(spacing: 12) {
                        PlayingCardView(card: preview).frame(width: 52).shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("VALITTU KORTTI").font(.system(size: 8, weight: .bold)).tracking(1.2).foregroundStyle(.secondary)
                            Text("\(preview.label) \(preview.suit.glyph)").font(.system(size: 16, weight: .bold, design: .serif))
                        }
                        Spacer()
                    }.padding(.horizontal, 20).padding(.bottom, 7).transition(.move(edge: .bottom).combined(with: .opacity))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: -min(25, proxy.size.width * 0.065)) {
                        ForEach(game.hand) { card in
                            Button { withAnimation(.spring(response: 0.28, dampingFraction: 0.68)) { game.toggle(card) } } label: {
                                PlayingCardView(card: card)
                                    .frame(width: min(60, max(38, (proxy.size.width - 42) / CGFloat(max(game.hand.count, 6)))) )
                                    .offset(y: game.selected.contains(card.id) ? -16 : 0)
                                    .rotationEffect(.degrees(handAngle(for: card)))
                                    .zIndex(game.selected.contains(card.id) ? 1 : 0)
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 23).padding(.top, 17).padding(.bottom, 9)
                }.frame(height: min(116, proxy.size.height * 0.19))

                HStack(spacing: 9) {
                    Button { game.draw(); if game.actionSucceeded { AudioServicesPlaySystemSound(1104); Task { await publishGame(advanceTurn: false) } } } label: { actionButton("NOSTA", icon: "arrow.down.to.line") }.disabled(!game.turn || game.game == .mustaMaija)
                    Button { game.playSelected(); if game.actionSucceeded { if room == nil { AudioServicesPlaySystemSound(1104) }; Task { await publishGame(advanceTurn: true) } } } label: { actionButton(game.game == .mustaMaija ? (game.isMaijaDefense ? "KAADA" : "HYÖKKÄÄ") : "PELAA", icon: "arrow.up.right", emphasized: true) }.disabled(game.selected.isEmpty || !game.turn)
                    Button { game.selected.removeAll(); game.notice = "Valinta peruttu." } label: { actionButton("PERU", icon: "xmark") }
                }.padding(.horizontal, 16).padding(.bottom, 12).padding(.top, 3)
            }
            .foregroundStyle(.primary)
            .task(id: room?.code) { await pollGame() }
        }
    }

    private var accountTab: some View {
        ZStack {
            VelvetBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) { BrandCross(size: 25, color: .black); Text("PELAAJATILI").font(.system(size: 12, weight: .black, design: .serif)).tracking(2) }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("NÄYTTÖNIMI").font(.system(size: 9, weight: .bold)).tracking(1.3).foregroundStyle(.secondary)
                        TextField("Pelaaja", text: $session.displayName).textContentType(.name).padding(13).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                        Text("SÄHKÖPOSTI").font(.system(size: 9, weight: .bold)).tracking(1.3).foregroundStyle(.secondary)
                        TextField("nimi@esimerkki.fi", text: $session.email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().padding(13).background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                        if let message = session.message { Text(message).font(.system(size: 11)).foregroundStyle(.secondary) }
                        Button { showSignIn = true } label: { primaryButton(session.isSignedIn ? "HALLITSE KIRJAUTUMISTA" : "KIRJAUDU / LUO TILI", icon: "person.crop.circle") }
                        Button("Jatka vieraana") { session.playAsGuest() }.font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 2)
                    }.padding(20).premiumGlass(cornerRadius: 22).overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.75), lineWidth: 0.8))
                }.padding(20)
            }
        }
    }

    private var rulesPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KUVAKORTIT SALLITTU 7, 8 TAI 9 PÄÄLLE").font(.system(size: 9, weight: .bold)).tracking(0.7).foregroundStyle(.secondary)
            Picker("Kuvakortit", selection: $faceCardsMinimum) {
                Text("7 päälle").tag(7)
                Text("8 päälle").tag(8)
                Text("9 päälle").tag(9)
            }.pickerStyle(.segmented)
        }.padding(12).background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 13))
            .onChange(of: faceCardsMinimum) { _, value in Task { await updateRoomRules(value) } }
    }

    private var signInSheet: some View {
        SignInPanel().environmentObject(session).presentationDetents([.medium, .large]).presentationDragIndicator(.visible).preferredColorScheme(.light)
    }

    private func pageHeader(_ title: String, back: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Button(action: back) { Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold)).frame(width: 38, height: 38).premiumGlass(cornerRadius: 20) }
            Text(title).font(.system(size: 11, weight: .bold)).tracking(2)
            Spacer()
        }.foregroundStyle(.primary).padding(.horizontal, 18).padding(.top, 8)
    }

    private func primaryButton(_ title: String, icon: String) -> some View {
        HStack(spacing: 9) { Text(title).tracking(1.3); Image(systemName: icon) }.font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 48)
            .background(Color(red: 0.13, green: 0.13, blue: 0.14), in: Capsule())
            .shadow(color: .black.opacity(0.14), radius: 8, y: 4)
    }

    private func actionButton(_ title: String, icon: String, emphasized: Bool = false) -> some View {
        HStack(spacing: 6) { Image(systemName: icon); Text(title).tracking(0.8) }
            .font(.system(size: 9, weight: .bold)).frame(maxWidth: .infinity).frame(height: 38)
            .foregroundStyle(emphasized ? .white : .primary)
            .background(emphasized ? Color(red: 0.12, green: 0.12, blue: 0.13) : .white.opacity(0.62), in: Capsule())
            .overlay(Capsule().stroke(.black.opacity(emphasized ? 0 : 0.08), lineWidth: 0.8))
    }

    private func playerBadge(_ name: String, count: Int, isLocal: Bool = false) -> some View {
        HStack(spacing: 7) {
            Image(systemName: isLocal ? "person.crop.circle.fill" : "person.fill").font(.system(size: 12)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(name.uppercased()).font(.system(size: 7, weight: .bold)).tracking(0.45).lineLimit(1)
                Text("\(count) korttia").font(.system(size: 7)).foregroundStyle(.secondary)
            }
        }.padding(.horizontal, 9).padding(.vertical, 7).premiumGlass(cornerRadius: 19)
    }

    private func handAngle(for card: PlayingCard) -> Double {
        guard game.hand.count > 1, let index = game.hand.firstIndex(of: card) else { return 0 }
        return Double(index - game.hand.count / 2) * 1.7
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
            VelvetBackground()
            ScrollView {
                VStack(spacing: 13) {
                    Text(create ? "LUO PELAAJATILI" : "KIRJAUDU SISÄÄN").font(.system(size: 17, weight: .black, design: .serif)).tracking(1.6)
                    TextField("Nimi", text: $session.displayName).textContentType(.name).textInputAutocapitalization(.words).padding(13).background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
                    TextField("Sähköposti", text: $session.email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().padding(13).background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
                    SecureField("Salasana", text: $password).textContentType(create ? .newPassword : .password).padding(13).background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
                    if let message = session.message { Text(message).font(.system(size: 11)).foregroundStyle(.secondary) }
                    Button {
                        Task { await session.signIn(createAccount: create, password: password); if session.isSignedIn { dismiss() } }
                    } label: {
                        Text(create ? "LUO TILI" : "KIRJAUDU").font(.system(size: 11, weight: .bold)).tracking(1.5)
                            .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 47).background(.black, in: Capsule())
                    }
                    Button(create ? "Minulla on jo tili" : "Luo uusi tili") { create.toggle() }.font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    Button("Jatka vieraana") { session.playAsGuest(); dismiss() }.font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                }.padding(22).foregroundStyle(.primary)
            }
        }
    }
}
