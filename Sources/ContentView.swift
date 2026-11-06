import SwiftUI
import AudioToolbox
import UIKit

private enum Screen { case home, room, table }

struct ContentView: View {
    @EnvironmentObject private var session: PlayerSession
    @StateObject private var game = CardGame()
    @State private var screen: Screen = .home
    @State private var selectedGame: GameKind = .kakkahousu
    @State private var room: OnlineRoom?
    @State private var playerID = UUID().uuidString
    @State private var roomCode = ""
    @State private var showSignIn = false
    @State private var showScanner = false
    @State private var showNewGame = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            VelvetBackground()
            switch screen {
            case .home: home
            case .room: roomView
            case .table: tableView
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: screen == .table)
        .sheet(isPresented: $showSignIn) { signInSheet }
        .sheet(isPresented: $showScanner) { QRScanner { roomCode = $0; showScanner = false; Task { await joinRoom() } } }
        .alert("Chrome Hearts", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Selvä", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .onOpenURL { url in
            let code = url.pathComponents.last ?? ""
            guard !code.isEmpty, code != "/" else { return }
            roomCode = code.uppercased()
            screen = .room
            Task { await joinRoom() }
        }
        .preferredColorScheme(.dark)
    }

    private var home: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 9) { BrandCross(size: 27, color: .white); Text("CHROME HEARTS").font(.system(size: 12, weight: .black, design: .serif)).tracking(2.2) }
                Spacer()
                Button { showSignIn = true } label: {
                    HStack(spacing: 6) { Image(systemName: session.isSignedIn ? "person.crop.circle.fill" : "person.crop.circle"); Text(session.isSignedIn ? session.displayName : "Kirjaudu") }
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.86))
                }
            }.padding(.horizontal, 22).padding(.top, 12)

            Spacer(minLength: 22)
            VStack(spacing: 14) {
                BrandCross(size: 76, color: Color(red: 0.92, green: 0.91, blue: 0.86))
                Text("CHROME HEARTS").font(.system(size: 30, weight: .black, design: .serif)).tracking(2).foregroundStyle(.white)
                Text("KORTTIPELI").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(5).foregroundStyle(.white.opacity(0.48))
            }
            Spacer(minLength: 28)

            VStack(spacing: 12) {
                ForEach(GameKind.allCases) { kind in
                    Button { selectedGame = kind; showNewGame = true } label: {
                        HStack(spacing: 16) {
                            Text(kind == .kakkahousu ? "♠" : "♣").font(.system(size: 27, weight: .light)).foregroundStyle(Color(red: 0.83, green: 0.77, blue: 0.68)).frame(width: 42)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(kind.rawValue.uppercased()).font(.system(size: 15, weight: .bold, design: .serif)).tracking(1.2)
                                Text(kind.subtitle).font(.system(size: 11)).foregroundStyle(.white.opacity(0.52))
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.55))
                        }
                        .foregroundStyle(.white).padding(.horizontal, 18).frame(height: 74)
                        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.10), lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 22)

            Spacer(minLength: 22)
            HStack(spacing: 8) { BrandCross(size: 15, color: .white.opacity(0.44)); Text("YHDESSÄ PÖYDÄN ÄÄREEN").tracking(2).font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.4)); BrandCross(size: 15, color: .white.opacity(0.44)) }
                .padding(.bottom, 20)
        }
        .confirmationDialog(selectedGame.rawValue, isPresented: $showNewGame, titleVisibility: .visible) {
            Button("Pelaa paikallisesti") { game.start(selectedGame); room = nil; screen = .table }
            Button("Luo online-huone") { Task { await createRoom() } }
            Button("Liity koodilla / QR") { screen = .room }
            Button("Peruuta", role: .cancel) { }
        } message: { Text("Valitse pelitapa") }
    }

    private var roomView: some View {
        Group {
            if room == nil { joinRoomView } else { roomLobby }
        }
    }

    private var joinRoomView: some View {
        VStack(spacing: 0) {
            header(title: "PELIHUONE", back: { screen = .home })
            Spacer()
            VStack(spacing: 16) {
                Text("LIITY PELIIN").font(.system(size: 11, weight: .bold)).tracking(3).foregroundStyle(.white.opacity(0.56))
                HStack(spacing: 10) {
                    TextField("HUONEKOODI", text: $roomCode).textInputAutocapitalization(.characters).autocorrectionDisabled().font(.system(size: 22, weight: .bold, design: .monospaced)).tracking(5).multilineTextAlignment(.center).padding(16).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    Button { showScanner = true } label: { Image(systemName: "qrcode.viewfinder").font(.system(size: 22, weight: .medium)).frame(width: 58, height: 58).background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14)) }
                }
                Button { Task { await joinRoom() } } label: { primaryButton("LIITY HUONEESEEN", icon: "arrow.right") }.disabled(roomCode.count < 4 || session.isBusy)
                Rectangle().fill(.white.opacity(0.12)).frame(height: 1).padding(.vertical, 6)
                Text("TAI LUO UUSI HUONE").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(.white.opacity(0.5))
                HStack(spacing: 10) { ForEach(GameKind.allCases) { kind in Button { selectedGame = kind } label: { Text(kind.rawValue).font(.system(size: 12, weight: .bold)).frame(maxWidth: .infinity).padding(14).background(selectedGame == kind ? .white.opacity(0.18) : .white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(selectedGame == kind ? 0.35 : 0.1))) } } }
                Button { Task { await createRoom() } } label: { primaryButton("LUO HUONE", icon: "plus") }.disabled(session.isBusy)
                if !session.isSignedIn { Text("Online-peliin tarvitaan kirjautuminen.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.48)) }
            }
            .padding(22).background(.black.opacity(0.40), in: RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.12)))
            .padding(.horizontal, 22)
            Spacer()
        }
    }

    private var roomLobby: some View {
        VStack(spacing: 18) {
            Text(room?.game.rawValue.uppercased() ?? "PELIHUONE").font(.system(size: 11, weight: .bold)).tracking(3).foregroundStyle(.white.opacity(0.55))
            Text(room?.code ?? "------").font(.system(size: 34, weight: .black, design: .monospaced)).tracking(8)
            if let code = room?.code, let image = QRCode.make(from: "chromehearts://join/\(code)") { Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(width: 166, height: 166).padding(8).background(.white, in: RoundedRectangle(cornerRadius: 12)) }
            Text("Pyydä kavereita skannaamaan QR tai syöttämään huonekoodi.").font(.system(size: 12)).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.6)).padding(.horizontal)
            VStack(spacing: 10) {
                ForEach(Array((room?.players.values.sorted { $0.id < $1.id } ?? [])), id: \.id) { player in
                    HStack { Image(systemName: "person.fill").font(.system(size: 12)); Text(player.name); Spacer(); if player.id == room?.hostID { Text("HOST").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.white.opacity(0.48)) } }.font(.system(size: 14, weight: .medium)).padding(13).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            Button { Task { await beginGame() } } label: { primaryButton(room?.hostID == playerID ? "ALOITA PELI" : "ODOTA PELINJOHTAJAA", icon: "play.fill") }
                .disabled(room?.hostID != playerID || (room?.players.count ?? 0) < 2)
            if (room?.players.count ?? 0) < 2 { Text("Peli alkaa, kun vähintään yksi kaveri liittyy.").font(.system(size: 10)).foregroundStyle(.white.opacity(0.45)) }
        }
        .padding(24).background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.12))).padding(.horizontal, 20)
        .task(id: room?.code) { await pollRoom() }
    }

    private var tableView: some View {
        VStack(spacing: 0) {
            HStack {
                Button { screen = room == nil ? .home : .room } label: { Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold)).frame(width: 38, height: 38).background(.white.opacity(0.08), in: Circle()) }
                VStack(alignment: .leading, spacing: 2) { Text((room?.game ?? game.game).rawValue.uppercased()).font(.system(size: 11, weight: .bold)).tracking(1.5); Text(room.map { "HUONE \($0.code)" } ?? "PAIKALLINEN PELI").font(.system(size: 9, weight: .medium)).tracking(1.2).foregroundStyle(.white.opacity(0.48)) }
                Spacer()
                Button { Task { await restartGame() } } label: { Image(systemName: "arrow.clockwise").frame(width: 38, height: 38).background(.white.opacity(0.08), in: Circle()) }
            }.padding(.horizontal, 18).padding(.top, 8).foregroundStyle(.white)

            HStack(alignment: .top) {
                VStack(spacing: 6) {
            Button { game.draw(); if game.actionSucceeded { AudioServicesPlaySystemSound(1104); Task { await publishGame(advanceTurn: false) } } } label: { CardBackView().frame(width: 74, height: 106).rotationEffect(.degrees(-6)).shadow(color: .black.opacity(0.4), radius: 10, y: 5) }.disabled(!game.turn)
                    Text("PAKKA · \(game.deckCount)").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
                VStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.045)).frame(width: 108, height: 130).overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.09), style: StrokeStyle(lineWidth: 1, dash: [5, 5])))
                        if let top = game.tableCards.last { PlayingCardView(card: top).frame(width: 82, height: 116).rotationEffect(.degrees(Double(top.rank % 7 - 3))).shadow(color: .black.opacity(0.35), radius: 10, y: 5).transition(.asymmetric(insertion: .move(edge: .top).combined(with: .scale), removal: .scale.combined(with: .opacity))) }
                        else { BrandCross(size: 38, color: .white.opacity(0.28)) }
                    }
                    Text("PÖYTÄ · \(game.tableCards.count)").font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
                VStack(spacing: 10) {
                    playerToken(name: room?.players.values.first(where: { $0.id != playerID })?.name ?? "Kaveri", cards: room?.players.values.first(where: { $0.id != playerID })?.handCount ?? 5)
                    playerToken(name: session.displayName, cards: game.hand.count)
                }
            }.padding(.horizontal, 22).padding(.top, 32)

            HStack(spacing: 7) { Circle().fill(.white.opacity(0.6)).frame(width: 5, height: 5); Text(game.notice).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.67)).lineLimit(1) }
                .padding(.horizontal, 15).padding(.vertical, 10).background(.black.opacity(0.28), in: Capsule()).padding(.top, 20)

            if !game.tableCards.isEmpty { Button { withAnimation(.spring()) { game.pickupTable() }; Task { await publishGame(advanceTurn: true) } } label: { Text("NOSTA PÖYTÄ").font(.system(size: 9, weight: .bold)).tracking(1.5).padding(.horizontal, 14).padding(.vertical, 8).background(.white.opacity(0.08), in: Capsule()) }.disabled(!game.turn).padding(.top, 6) }

            Spacer(minLength: 14)
            if !game.selected.isEmpty, let preview = game.hand.first(where: { game.selected.contains($0.id) }) {
                HStack(spacing: 12) {
                    PlayingCardView(card: preview).frame(width: 73, height: 104).shadow(color: .black.opacity(0.35), radius: 10, y: 4).transition(.scale.combined(with: .opacity))
                    VStack(alignment: .leading, spacing: 5) { Text("VALITTU KORTTI").font(.system(size: 9, weight: .bold)).tracking(1.4).foregroundStyle(.white.opacity(0.5)); Text("\(preview.label) \(preview.suit.glyph)").font(.system(size: 18, weight: .bold, design: .serif)) }
                    Spacer()
                }.padding(.horizontal, 22).padding(.bottom, 9).transition(.move(edge: .bottom).combined(with: .opacity))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: -24) {
                    ForEach(game.hand) { card in
                        Button { withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) { game.toggle(card) } } label: {
                            PlayingCardView(card: card).frame(width: min(70, handCardWidth), height: min(102, handCardWidth * 1.46))
                                .offset(y: game.selected.contains(card.id) ? -17 : 0)
                                .rotationEffect(.degrees(handAngle(for: card)))
                                .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
                        }.buttonStyle(.plain).zIndex(game.selected.contains(card.id) ? 1 : 0)
                    }
                }.padding(.horizontal, 23).padding(.top, 18).padding(.bottom, 12)
            }.frame(height: 122)

            HStack(spacing: 10) {
                Button { withAnimation(.spring()) { game.draw() }; if game.actionSucceeded { AudioServicesPlaySystemSound(1104); Task { await publishGame(advanceTurn: false) } } } label: { actionPill("NOSTA", icon: "arrow.down.to.line") }.disabled(!game.turn)
                Button { withAnimation(.spring()) { game.playSelected() }; if game.actionSucceeded { AudioServicesPlaySystemSound(1104); Task { await publishGame(advanceTurn: true) } } } label: { actionPill("PELAA", icon: "arrow.up.right", filled: true) }.disabled(game.selected.isEmpty || !game.turn)
                Button { game.selected.removeAll(); game.notice = "Valinta peruttu." } label: { actionPill("PERU", icon: "xmark") }
            }.padding(.horizontal, 20).padding(.bottom, 18)
        }
        .foregroundStyle(.white)
        .task(id: room?.code) { await pollGame() }
        .alert("Kierros päättyi", isPresented: $game.isOver) { Button("Uusi peli") { game.start(room?.game ?? game.game) }; Button("Takaisin", role: .cancel) { screen = .home } } message: { Text(game.notice) }
    }

    private var handCardWidth: CGFloat { min(70, (UIScreen.main.bounds.width - 46) / CGFloat(max(game.hand.count, 5))) }

    private func playerToken(name: String, cards: Int) -> some View {
        HStack(spacing: 8) { ZStack { Circle().fill(.white.opacity(0.1)).frame(width: 31, height: 31); Image(systemName: "person.fill").font(.system(size: 12)) }; VStack(alignment: .leading, spacing: 2) { Text(name.uppercased()).font(.system(size: 8, weight: .bold)).tracking(0.6).lineLimit(1); Text("\(cards) korttia").font(.system(size: 8)).foregroundStyle(.white.opacity(0.5)) } }.padding(8).background(.black.opacity(0.28), in: Capsule())
    }
    private func header(title: String, back: @escaping () -> Void) -> some View {
        HStack { Button(action: back) { Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold)).frame(width: 38, height: 38).background(.white.opacity(0.08), in: Circle()) }; Text(title).font(.system(size: 11, weight: .bold)).tracking(2); Spacer() }.foregroundStyle(.white).padding(.horizontal, 20).padding(.top, 10)
    }
    private func primaryButton(_ title: String, icon: String) -> some View {
        HStack(spacing: 9) { Text(title).tracking(1.5); Image(systemName: icon) }.font(.system(size: 11, weight: .bold)).foregroundStyle(.black).frame(maxWidth: .infinity).frame(height: 50).background(Color(red: 0.92, green: 0.9, blue: 0.84), in: Capsule())
    }
    private func actionPill(_ title: String, icon: String, filled: Bool = false) -> some View {
        HStack(spacing: 6) { Image(systemName: icon); Text(title).tracking(1) }.font(.system(size: 9, weight: .bold)).frame(maxWidth: .infinity).frame(height: 43).foregroundStyle(filled ? .black : .white.opacity(0.82)).background(filled ? Color(red: 0.92, green: 0.9, blue: 0.84) : .white.opacity(0.075), in: Capsule()).overlay(Capsule().stroke(.white.opacity(filled ? 0 : 0.12)))
    }
    private func handAngle(for card: PlayingCard) -> Double { guard game.hand.count > 1, let index = game.hand.firstIndex(of: card) else { return 0 }; return Double(index - game.hand.count / 2) * 2.2 }

    private var signInSheet: some View {
        SignInPanel().environmentObject(session).presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }

    private func createRoom() async {
        guard let token = session.idToken else { errorMessage = "Kirjaudu sähköpostilla ennen online-huoneen luontia."; showSignIn = true; return }
        do { let person = PlayerInfo(id: playerID, name: session.displayName); room = try await FirebaseService.shared.createRoom(game: selectedGame, player: person, token: token); screen = .room }
        catch { errorMessage = error.localizedDescription }
    }
    private func joinRoom() async {
        guard let token = session.idToken else { errorMessage = "Kirjaudu sähköpostilla ennen online-peliin liittymistä."; showSignIn = true; return }
        do { let person = PlayerInfo(id: playerID, name: session.displayName); room = try await FirebaseService.shared.joinRoom(code: roomCode, player: person, token: token); screen = .room }
        catch { errorMessage = error.localizedDescription }
    }
    private func pollRoom() async {
        while !Task.isCancelled, screen == .room, let room, let token = session.idToken {
            do {
                let latest = try await FirebaseService.shared.load(code: room.code, token: token)
                self.room = latest
                if screen == .room, let state = latest.gameState {
                    game.apply(state, for: playerID)
                    screen = .table
                }
            } catch { }
            try? await Task.sleep(for: .seconds(3))
        }
    }
    private func beginGame() async {
        guard var current = room, let token = session.idToken, current.hostID == playerID else { return }
        let state = game.startOnline(current.game, playerIDs: Array(current.players.keys), hostID: current.hostID)
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
        guard let room else { game.start(game.game); return }
        guard room.hostID == playerID else { errorMessage = "Vain pelinjohtaja voi aloittaa uuden jaon."; return }
        await beginGame()
    }
    private func pollGame() async {
        while !Task.isCancelled, screen == .table, let current = room, let token = session.idToken {
            do {
                let latest = try await FirebaseService.shared.load(code: current.code, token: token)
                if let state = latest.gameState, latest.updatedAt > current.updatedAt {
                    game.apply(state, for: playerID)
                    room = latest
                }
            } catch { }
            try? await Task.sleep(for: .seconds(2))
        }
    }
}

private struct SignInPanel: View {
    @EnvironmentObject private var session: PlayerSession
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var create = false
    var body: some View {
        ZStack { VelvetBackground(); VStack(spacing: 14) {
            Text(create ? "LUO TILI" : "KIRJAUDU SISÄÄN").font(.system(size: 17, weight: .black, design: .serif)).tracking(2)
            TextField("Nimi", text: $session.displayName).textContentType(.name).textInputAutocapitalization(.words).padding(14).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            TextField("Sähköposti", text: $session.email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().padding(14).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            SecureField("Salasana", text: $password).textContentType(create ? .newPassword : .password).padding(14).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            if let message = session.message { Text(message).font(.system(size: 11)).foregroundStyle(.white.opacity(0.65)) }
            Button { Task { await session.signIn(createAccount: create, password: password); if session.isSignedIn { dismiss() } } } label: { Text(create ? "LUO TILI" : "KIRJAUDU").font(.system(size: 11, weight: .bold)).tracking(1.6).foregroundStyle(.black).frame(maxWidth: .infinity).frame(height: 48).background(.white, in: Capsule()) }
            Button(create ? "Minulla on jo tili" : "Luo uusi tili") { create.toggle() }.font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.7))
            Button("Jatka vieraana") { session.playAsGuest(); dismiss() }.font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.7))
        }.padding(22) }.foregroundStyle(.white)
    }
}
