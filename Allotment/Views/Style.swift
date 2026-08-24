import SwiftUI

extension Color {
    static let alloInk = adaptive(light: .rgb(0.18, 0.16, 0.29), dark: .rgb(0.96, 0.95, 1.0))
    static let alloMuted = adaptive(light: .rgb(0.44, 0.42, 0.53), dark: .rgb(0.75, 0.72, 0.82))
    static let alloPaper = adaptive(light: .rgb(1.0, 0.99, 0.97), dark: .rgb(0.15, 0.13, 0.20))
    static let alloPink = Color(uiColor: .rgb(1.0, 0.68, 0.82))
    static let alloMauve = Color(uiColor: .rgb(0.776, 0.627, 0.965))
    static let alloMint = Color(uiColor: .rgb(0.65, 0.90, 0.78))
    static let alloBlue = Color(uiColor: .rgb(0.73, 0.93, 1.0))
    static let alloPurple = adaptive(light: .rgb(0.55, 0.47, 0.85), dark: .rgb(0.67, 0.59, 0.94))
    static let alloBackground = adaptive(light: .rgb(0.91, 0.96, 1.0), dark: .rgb(0.07, 0.06, 0.10))
    static let alloOutline = adaptive(light: .rgb(0.18, 0.16, 0.29), dark: .rgb(0.60, 0.56, 0.74))
    static let alloShadow = adaptive(light: .rgb(0.55, 0.47, 0.85), dark: UIColor(red: 0.67, green: 0.59, blue: 0.94, alpha: 0.35))
    static let alloInkShadow = adaptive(light: .rgb(0.18, 0.16, 0.29), dark: UIColor(red: 0.67, green: 0.59, blue: 0.94, alpha: 0.35))
    static let alloStickerInk = Color(uiColor: .rgb(0.18, 0.16, 0.28))
    static let alloRequestFill = adaptive(light: .rgb(0.14, 0.51, 0.37), dark: .rgb(0.38, 0.76, 0.62))
    static let alloError = adaptive(light: .rgb(0.72, 0.13, 0.16), dark: .rgb(0.96, 0.51, 0.55))

    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

extension UIColor {
    static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

struct DotBackground: View {
    private let dotColor = Color.adaptive(
        light: UIColor(red: 0.37, green: 0.67, blue: 0.86, alpha: 0.24),
        dark: UIColor(red: 0.67, green: 0.59, blue: 0.94, alpha: 0.20)
    )

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.alloBackground))
            for x in stride(from: 8.0, through: size.width, by: 17.0) {
                for y in stride(from: 8.0, through: size.height, by: 17.0) {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2.4, height: 2.4)), with: .color(dotColor))
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

extension View {
    func notebookOutline(cornerRadius: CGFloat = 14) -> some View {
        clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Color.alloOutline, lineWidth: 2))
    }

    func stickerBorder(shadow: Color = .alloShadow, cornerRadius: CGFloat = 14, offset: CGFloat = 6) -> some View {
        modifier(StickerBorder(shadow: shadow, cornerRadius: cornerRadius, offset: offset))
    }
}

private struct StickerBorder: ViewModifier {
    let shadow: Color
    let cornerRadius: CGFloat
    let offset: CGFloat

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(shadow)
                    .offset(x: offset, y: offset)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.alloOutline, lineWidth: 2)
            }
            .padding(offset)
    }
}

extension Font {
    static func alloWordmark(size: CGFloat) -> Font {
        .custom("Fraunces-SemiBold", size: size)
    }
}

struct Stamp: View {
    let icon: String
    let color: Color
    var foreground = Color.alloStickerInk
    var size: CGFloat = 39

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.36, weight: .bold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(color)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.alloOutline, lineWidth: 2))
            .accessibilityHidden(true)
    }
}
