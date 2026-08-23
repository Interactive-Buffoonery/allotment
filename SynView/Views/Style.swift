import SwiftUI

extension Color {
    static let synInk = adaptive(light: .rgb(0.18, 0.16, 0.29), dark: .rgb(0.96, 0.95, 1.0))
    static let synMuted = adaptive(light: .rgb(0.44, 0.42, 0.53), dark: .rgb(0.75, 0.72, 0.82))
    static let synPaper = adaptive(light: .rgb(1.0, 0.99, 0.97), dark: .rgb(0.13, 0.12, 0.18))
    static let synPink = adaptive(light: .rgb(1.0, 0.68, 0.82), dark: .rgb(0.55, 0.26, 0.42))
    static let synYellow = adaptive(light: .rgb(1.0, 0.94, 0.62), dark: .rgb(0.94, 0.89, 0.64))
    static let synMint = adaptive(light: .rgb(0.65, 0.90, 0.78), dark: .rgb(0.16, 0.37, 0.29))
    static let synBlue = adaptive(light: .rgb(0.73, 0.93, 1.0), dark: .rgb(0.16, 0.31, 0.44))
    static let synPurple = adaptive(light: .rgb(0.55, 0.47, 0.85), dark: .rgb(0.67, 0.59, 0.94))
    static let synBackground = adaptive(light: .rgb(0.91, 0.96, 1.0), dark: .rgb(0.07, 0.06, 0.10))
    static let synOutline = adaptive(light: .rgb(0.18, 0.16, 0.29), dark: .rgb(0.60, 0.56, 0.74))
    static let synShadow = adaptive(light: .rgb(0.55, 0.47, 0.85), dark: .rgb(0.42, 0.34, 0.72))
    static let synInkShadow = adaptive(light: .rgb(0.18, 0.16, 0.29), dark: .rgb(0.05, 0.04, 0.09))
    static let synPlannerInk = Color(uiColor: .rgb(0.18, 0.16, 0.28))
    static let synWeeklyFill = adaptive(light: .rgb(0.96, 0.84, 0.44), dark: .rgb(0.91, 0.81, 0.47))
    static let synRequestFill = adaptive(light: .rgb(0.28, 0.69, 0.55), dark: .rgb(0.38, 0.76, 0.62))
    static let synError = adaptive(light: .rgb(0.72, 0.13, 0.16), dark: .rgb(0.96, 0.51, 0.55))

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
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.synBackground))
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
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Color.synOutline, lineWidth: 2))
    }

    func stickerBorder(shadow: Color = .synShadow, cornerRadius: CGFloat = 14, offset: CGFloat = 6) -> some View {
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
                    .strokeBorder(Color.synOutline, lineWidth: 2)
            }
            .padding(offset)
    }
}

extension Font {
    static func synWordmark(size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }
}
