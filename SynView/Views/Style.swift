import SwiftUI

extension Color {
    static let synInk = adaptive(light: .rgb(0.18, 0.16, 0.29), dark: .rgb(0.96, 0.95, 1.0))
    static let synMuted = adaptive(light: .rgb(0.34, 0.32, 0.46), dark: .rgb(0.74, 0.72, 0.82))
    static let synPaper = adaptive(light: .rgb(1.0, 0.99, 0.97), dark: .rgb(0.13, 0.12, 0.18))
    static let synPink = adaptive(light: .rgb(1.0, 0.68, 0.82), dark: .rgb(0.44, 0.20, 0.34))
    static let synYellow = adaptive(light: .rgb(1.0, 0.94, 0.62), dark: .rgb(0.40, 0.31, 0.10))
    static let synMint = adaptive(light: .rgb(0.65, 0.90, 0.78), dark: .rgb(0.15, 0.38, 0.29))
    static let synBlue = adaptive(light: .rgb(0.73, 0.93, 1.0), dark: .rgb(0.16, 0.32, 0.48))
    static let synPurple = adaptive(light: .rgb(0.42, 0.34, 0.78), dark: .rgb(0.64, 0.57, 0.94))
    static let synBackground = adaptive(light: .rgb(0.91, 0.96, 1.0), dark: .rgb(0.065, 0.06, 0.095))
    static let synOutline = adaptive(light: .rgb(0.18, 0.16, 0.29), dark: .rgb(0.40, 0.37, 0.52))
    static let synShadow = adaptive(
        light: UIColor.black.withAlphaComponent(0.14),
        dark: UIColor.black.withAlphaComponent(0.42)
    )
    static let synError = adaptive(light: .rgb(0.72, 0.13, 0.16), dark: .rgb(0.96, 0.51, 0.55))

    fileprivate static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

private extension UIColor {
    static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

struct DotBackground: View {
    private let dotColor = Color.adaptive(
        light: UIColor.systemBlue.withAlphaComponent(0.13),
        dark: UIColor.white.withAlphaComponent(0.055)
    )

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.synBackground))
            for x in stride(from: 10.0, through: size.width, by: 22.0) {
                for y in stride(from: 10.0, through: size.height, by: 22.0) {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(dotColor))
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
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Color.synOutline, lineWidth: 1))
    }

    func stickerBorder(cornerRadius: CGFloat = 14) -> some View {
        notebookOutline(cornerRadius: cornerRadius)
            .shadow(color: Color.synShadow, radius: 7, x: 0, y: 4)
    }
}
