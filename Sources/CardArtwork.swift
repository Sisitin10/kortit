import SwiftUI

struct AppCanvas: View {
    var body: some View {
        Color(uiColor: .systemBackground)
            .ignoresSafeArea()
    }
}

struct BrandPatternBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let columns = max(1, Int(proxy.size.width / 74) + 2)
            VStack(spacing: 36) {
                ForEach(0..<15, id: \.self) { row in
                    HStack(spacing: 42) {
                        ForEach(0..<columns, id: \.self) { _ in
                            Image("BrandMark")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                                .foregroundStyle(Color.primary.opacity(0.1))
                                .rotationEffect(.degrees(45))
                        }
                    }
                    .offset(x: row.isMultiple(of: 2) ? 0 : 36)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .accessibilityHidden(true)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
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
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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

    @ViewBuilder func appGlass(cornerRadius: CGFloat = 18) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.primary.opacity(0.08), lineWidth: 1))
        }
    }
}

struct PlayingCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let card: PlayingCard

    private var ink: Color { Color.black }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let labelSize = max(11, min(18, width * 0.23))
            ZStack {
                Image("CardFace")
                    .resizable()
                    .colorInvertIfNeeded(colorScheme == .dark)
                    .scaledToFill()
                    .frame(width: width, height: proxy.size.height)
                    .clipped()

                RoundedRectangle(cornerRadius: max(3, width * 0.045), style: .continuous)
                    .stroke(Color.black.opacity(0.10), lineWidth: 0.6)

                VStack(spacing: 0) {
                    HStack(alignment: .top) {
                        cornerLabel(size: labelSize)
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom) {
                        Spacer(minLength: 0)
                        cornerLabel(size: labelSize).rotationEffect(.degrees(180))
                    }
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
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        GeometryReader { proxy in
            Image("CardBack")
                .resizable()
                .colorInvertIfNeeded(colorScheme == .dark)
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

private extension Image {
    @ViewBuilder func colorInvertIfNeeded(_ shouldInvert: Bool) -> some View {
        if shouldInvert { colorInvert() } else { self }
    }
}
