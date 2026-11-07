import SwiftUI

struct AppCanvas: View {
    var body: some View {
        Color(red: 0.97, green: 0.965, blue: 0.95)
            .ignoresSafeArea()
    }
}

struct BrandMark: View {
    var size: CGFloat
    var color: Color = Color(red: 0.28, green: 0.27, blue: 0.25)

    var body: some View {
        Image("BrandMark")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct CleanSurface: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(.white, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.07), lineWidth: 1)
            }
    }
}

extension View {
    func cleanSurface(cornerRadius: CGFloat = 18) -> some View {
        modifier(CleanSurface(cornerRadius: cornerRadius))
    }
}

struct PlayingCardView: View {
    let card: PlayingCard

    private var ink: Color {
        card.suit.isRed ? Color(red: 0.67, green: 0.12, blue: 0.15) : Color(red: 0.10, green: 0.10, blue: 0.10)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let labelSize = max(9, min(16, width * 0.25))
            ZStack {
                Image("CardFace")
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: proxy.size.height)
                    .clipped()

                RoundedRectangle(cornerRadius: max(7, width * 0.09), style: .continuous)
                    .stroke(Color.black.opacity(0.15), lineWidth: 0.8)

                VStack {
                    cornerLabel(size: labelSize)
                    Spacer(minLength: 0)
                    cornerLabel(size: labelSize).rotationEffect(.degrees(180))
                }
                .padding(.horizontal, width * 0.08)
                .padding(.vertical, proxy.size.height * 0.04)
            }
            .clipShape(RoundedRectangle(cornerRadius: max(7, width * 0.09), style: .continuous))
            .accessibilityLabel("\(card.label) \(card.suit.glyph)")
        }
        .aspectRatio(0.64, contentMode: .fit)
    }

    private func cornerLabel(size: CGFloat) -> some View {
        VStack(spacing: -2) {
            Text(card.label).font(.system(size: size, weight: .bold))
            Text(card.suit.glyph).font(.system(size: size * 0.86, weight: .semibold))
        }
        .foregroundStyle(ink)
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
                .clipShape(RoundedRectangle(cornerRadius: max(7, proxy.size.width * 0.09), style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: max(7, proxy.size.width * 0.09), style: .continuous)
                        .stroke(Color.black.opacity(0.12), lineWidth: 0.8)
                }
                .accessibilityLabel("Kortin selkäpuoli")
        }
        .aspectRatio(0.64, contentMode: .fit)
    }
}
