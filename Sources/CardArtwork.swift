import SwiftUI

struct AppCanvas: View {
    var body: some View {
        Color(red: 0.94, green: 0.945, blue: 0.95)
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

    private var ink: Color { Color.black }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let labelSize = max(11, min(18, width * 0.23))
            ZStack {
                Image("CardFace")
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: proxy.size.height)
                    .clipped()

                RoundedRectangle(cornerRadius: max(3, width * 0.045), style: .continuous)
                    .stroke(Color.black.opacity(0.10), lineWidth: 0.6)

                VStack {
                    cornerLabel(size: labelSize)
                    Spacer(minLength: 0)
                    cornerLabel(size: labelSize).rotationEffect(.degrees(180))
                }
                .padding(.horizontal, width * 0.07)
                .padding(.vertical, proxy.size.height * 0.035)
            }
            .clipShape(RoundedRectangle(cornerRadius: max(3, width * 0.045), style: .continuous))
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
                .clipShape(RoundedRectangle(cornerRadius: max(3, proxy.size.width * 0.045), style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: max(3, proxy.size.width * 0.045), style: .continuous)
                        .stroke(Color.black.opacity(0.12), lineWidth: 0.8)
                }
                .accessibilityLabel("Kortin selkäpuoli")
        }
        .aspectRatio(0.64, contentMode: .fit)
    }
}
