import SwiftUI

struct VelvetBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [Color(red: 0.11, green: 0.105, blue: 0.105), Color(red: 0.025, green: 0.024, blue: 0.027), Color(red: 0.09, green: 0.055, blue: 0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 22) {
                    ForEach(0..<(Int(proxy.size.height / 58) + 2), id: \.self) { row in
                        HStack(spacing: 25) {
                            ForEach(0..<(Int(proxy.size.width / 56) + 2), id: \.self) { _ in
                                BrandCross(size: 28, color: .white.opacity(0.028))
                            }
                        }.offset(x: row.isMultiple(of: 2) ? 0 : 25)
                    }
                }
                RadialGradient(colors: [.clear, .black.opacity(0.44)], center: .center, startRadius: proxy.size.width * 0.12, endRadius: proxy.size.height * 0.8)
            }.ignoresSafeArea()
        }
    }
}

struct BrandCross: View {
    var size: CGFloat
    var color: Color
    var body: some View {
        ZStack {
            ForEach(0..<4) { index in
                Capsule().fill(color).frame(width: size * 0.25, height: size * 0.48).offset(y: -size * 0.22).rotationEffect(.degrees(Double(index) * 90))
                Capsule().stroke(color, lineWidth: max(0.7, size * 0.025)).frame(width: size * 0.34, height: size * 0.58).offset(y: -size * 0.22).rotationEffect(.degrees(Double(index) * 90))
            }
            Circle().fill(color).frame(width: size * 0.2, height: size * 0.2)
            Circle().stroke(color, lineWidth: max(0.8, size * 0.035)).frame(width: size * 0.32, height: size * 0.32)
        }.frame(width: size, height: size)
    }
}

struct PlayingCardView: View {
    let card: PlayingCard
    private var ink: Color { card.suit.isRed ? Color(red: 0.65, green: 0.08, blue: 0.10) : Color(red: 0.06, green: 0.055, blue: 0.06) }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.105).fill(Color(red: 0.91, green: 0.90, blue: 0.86))
                RoundedRectangle(cornerRadius: w * 0.105).stroke(Color.black.opacity(0.2), lineWidth: 0.8).padding(1.5)
                VStack(spacing: 0) {
                    ForEach(0..<(Int(h / 30) + 1), id: \.self) { row in
                        HStack(spacing: 17) { ForEach(0..<Int(w / 24) + 2, id: \.self) { _ in BrandCross(size: 13, color: Color.black.opacity(0.05)) } }.offset(x: row.isMultiple(of: 2) ? 0 : -12)
                    }
                }.clipShape(RoundedRectangle(cornerRadius: w * 0.105)).padding(4)
                RoundedRectangle(cornerRadius: w * 0.1).stroke(.white.opacity(0.65), lineWidth: 0.7).padding(4)
                BrandCross(size: w * 0.43, color: ink.opacity(0.23))
                VStack {
                    HStack(alignment: .top, spacing: 1) { cornerLabel; Spacer(minLength: 0) }
                    Spacer()
                    HStack(alignment: .bottom, spacing: 1) { Spacer(minLength: 0); cornerLabel.rotationEffect(.degrees(180)) }
                }.padding(.horizontal, w * 0.09).padding(.vertical, h * 0.045)
            }
        }.aspectRatio(0.69, contentMode: .fit)
    }

    private var cornerLabel: some View {
        VStack(spacing: -2) {
            Text(card.label).font(.system(size: 15, weight: .bold, design: .serif)).minimumScaleFactor(0.7)
            Text(card.suit.glyph).font(.system(size: 12, weight: .bold))
        }.foregroundStyle(ink)
    }
}

struct CardBackView: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.1).fill(LinearGradient(colors: [Color(white: 0.13), .black, Color(white: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: w * 0.1).stroke(.white.opacity(0.74), lineWidth: 1.1).padding(4)
                RoundedRectangle(cornerRadius: w * 0.08).stroke(.white.opacity(0.25), lineWidth: 0.7).padding(8)
                VStack(spacing: h * 0.08) {
                    BrandCross(size: w * 0.17, color: .white.opacity(0.78))
                    ZStack {
                        Circle().stroke(.white.opacity(0.86), lineWidth: 1.5).frame(width: w * 0.62, height: w * 0.62)
                        Circle().stroke(.white.opacity(0.54), lineWidth: 0.7).frame(width: w * 0.47, height: w * 0.47)
                        BrandCross(size: w * 0.33, color: .white.opacity(0.92))
                    }
                    Text("CHROME\nHEARTS").font(.system(size: w * 0.095, weight: .black, design: .serif)).tracking(0.6).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.9))
                    BrandCross(size: w * 0.16, color: .white.opacity(0.78))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: w * 0.1).stroke(.black.opacity(0.75), lineWidth: 1.2))
        }.aspectRatio(0.69, contentMode: .fit)
    }
}
