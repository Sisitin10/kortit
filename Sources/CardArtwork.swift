import SwiftUI

struct VelvetBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 0.965, green: 0.958, blue: 0.938)
                LinearGradient(colors: [.white.opacity(0.84), .clear, Color(red: 0.92, green: 0.90, blue: 0.86).opacity(0.34)], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 26) {
                    ForEach(0..<(Int(proxy.size.height / 70) + 2), id: \.self) { row in
                        HStack(spacing: 32) {
                            ForEach(0..<(Int(proxy.size.width / 64) + 2), id: \.self) { _ in
                                BrandCross(size: 22, color: .black.opacity(0.025))
                            }
                        }.offset(x: row.isMultiple(of: 2) ? 0 : 32)
                    }
                }
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

struct PremiumGlass: ViewModifier {
    var cornerRadius: CGFloat = 22
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

extension View {
    func premiumGlass(cornerRadius: CGFloat = 22) -> some View { modifier(PremiumGlass(cornerRadius: cornerRadius)) }
}

struct PlayingCardView: View {
    let card: PlayingCard
    private var ink: Color { card.suit.isRed ? Color(red: 0.67, green: 0.11, blue: 0.14) : Color(red: 0.08, green: 0.08, blue: 0.085) }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                Image("CardFace").resizable().scaledToFill().frame(width: w, height: h).clipped()
                RoundedRectangle(cornerRadius: max(8, w * 0.09)).stroke(.black.opacity(0.28), lineWidth: 0.8)
                VStack {
                    cornerLabel
                    Spacer(minLength: 0)
                    cornerLabel.rotationEffect(.degrees(180))
                }.padding(.horizontal, w * 0.08).padding(.vertical, h * 0.04)
            }
            .clipShape(RoundedRectangle(cornerRadius: max(8, w * 0.09), style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 3)
            .accessibilityLabel("\(card.label) \(card.suit.glyph)")
        }.aspectRatio(0.64, contentMode: .fit)
    }

    private var cornerLabel: some View {
        VStack(spacing: -2) {
            Text(card.label).font(.system(size: 16, weight: .bold, design: .serif)).minimumScaleFactor(0.7)
            Text(card.suit.glyph).font(.system(size: 13, weight: .bold))
        }.foregroundStyle(ink).shadow(color: .white.opacity(0.65), radius: 2)
    }
}

struct CardBackView: View {
    var body: some View {
        GeometryReader { proxy in
            Image("CardBack")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: max(8, proxy.size.width * 0.09), style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: max(8, proxy.size.width * 0.09), style: .continuous).stroke(.white.opacity(0.68), lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 7, x: 0, y: 4)
                .accessibilityLabel("Kortin selkäpuoli")
        }.aspectRatio(0.64, contentMode: .fit)
    }
}
