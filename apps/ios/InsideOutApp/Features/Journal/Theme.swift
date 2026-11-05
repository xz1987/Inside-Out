import SwiftUI

// Tokens from design/Inside Out.dc.html and design/Figure.dc.html.

enum Ink {
    static let primary = Color(hex: 0x2E2440)
    static let secondary = Color(hex: 0x5A4F70)
    static let muted = Color(hex: 0x7D7390)
    static let label = Color(hex: 0x8A7FA3)
    static let face = Color(hex: 0x3B2D4A)
    static let heart = Color(hex: 0xFF6F8E)
    static let spark = Color(hex: 0xFFD84D)
    static let shadow = Color(red: 120 / 255, green: 90 / 255, blue: 160 / 255)
}

struct FigurePalette {
    let light: Color
    let base: Color
    let dark: Color
    let glow: Color
    let barStart: Color
    let badgeBackground: Color
    let badgeText: Color
}

extension FigureKind {
    var palette: FigurePalette {
        switch self {
        case .anger:
            FigurePalette(light: Color(hex: 0xFFD1CC), base: Color(hex: 0xFF4C3E), dark: Color(hex: 0xC9272D),
                          glow: Color(hex: 0xFF4D5B), barStart: Color(hex: 0xFF9A8E),
                          badgeBackground: Color(hex: 0xFFE0DC), badgeText: Color(hex: 0xA32228))
        case .joy:
            FigurePalette(light: Color(hex: 0xFFF6C2), base: Color(hex: 0xFFD84D), dark: Color(hex: 0xF2A81D),
                          glow: Color(red: 1, green: 196 / 255, blue: 60 / 255), barStart: Color(hex: 0xFFE38A),
                          badgeBackground: Color(hex: 0xFFF0C4), badgeText: Color(hex: 0xB27A0A))
        case .anxiety:
            FigurePalette(light: Color(hex: 0xFFE3BD), base: Color(hex: 0xFF8A32), dark: Color(hex: 0xD85B16),
                          glow: Color(hex: 0xFF7A24), barStart: Color(hex: 0xFFB86E),
                          badgeBackground: Color(hex: 0xFFE4CB), badgeText: Color(hex: 0xA94510))
        case .sadness:
            FigurePalette(light: Color(hex: 0xDCE9FF), base: Color(hex: 0x4285F4), dark: Color(hex: 0x245BB6),
                          glow: Color(hex: 0x3E83FF), barStart: Color(hex: 0x8EB9FF),
                          badgeBackground: Color(hex: 0xDDEAFF), badgeText: Color(hex: 0x2455A5))
        case .disgust:
            FigurePalette(light: Color(hex: 0xDDF7D4), base: Color(hex: 0x65C35A), dark: Color(hex: 0x2E8A3A),
                          glow: Color(hex: 0x6AD65C), barStart: Color(hex: 0xA7E79E),
                          badgeBackground: Color(hex: 0xDEF3D8), badgeText: Color(hex: 0x246E31))
        case .fear:
            FigurePalette(light: Color(hex: 0xEEE2FF), base: Color(hex: 0xA273E8), dark: Color(hex: 0x6841B4),
                          glow: Color(hex: 0xA97CF3), barStart: Color(hex: 0xCDB3F4),
                          badgeBackground: Color(hex: 0xEDE3FC), badgeText: Color(hex: 0x5F3AA9))
        case .embarrassment:
            FigurePalette(light: Color(hex: 0xFFE0F0), base: Color(hex: 0xF58BC1), dark: Color(hex: 0xC9508F),
                          glow: Color(hex: 0xFF8FCB), barStart: Color(hex: 0xF7B5D7),
                          badgeBackground: Color(hex: 0xFCE1EF), badgeText: Color(hex: 0xA93B77))
        case .boredom:
            FigurePalette(light: Color(hex: 0xFFFFFF), base: Color(hex: 0xE8EDF3), dark: Color(hex: 0x66758A),
                          glow: Color(hex: 0xB9D2F0), barStart: Color(hex: 0xD9E5F3),
                          badgeBackground: Color(hex: 0xEEF3F8), badgeText: Color(hex: 0x536274))
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension Font {
    /// The design uses Nunito; SF Rounded is the closest system face.
    static func rounded(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// Lays content out on the design's fixed 390×844 artboard and scales it to
/// fit the device, so absolute coordinates from the design carry over as-is.
struct DesignCanvas<Content: View>: View {
    static var width: CGFloat { 390 }
    static var height: CGFloat { 844 }

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / Self.width, geo.size.height / Self.height)
            content
                .frame(width: Self.width, height: Self.height, alignment: .topLeading)
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
}

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hex: 0xD4F3E9), location: 0),
                .init(color: Color(hex: 0xE3E0FA), location: 0.48),
                .init(color: Color(hex: 0xF8D8EA), location: 1)
            ],
            startPoint: UnitPoint(x: 0.37, y: 0),
            endPoint: UnitPoint(x: 0.63, y: 1)
        )
        .ignoresSafeArea()
    }
}

struct BackgroundBlobs: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .fill(RadialGradient(colors: [.white.opacity(0.7), .white.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: 150))
                .frame(width: 300, height: 300)
                .offset(x: -80, y: 120)
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFAC8E6, opacity: 0.7), Color(hex: 0xFAC8E6, opacity: 0)],
                                     center: .center, startRadius: 0, endRadius: 170))
                .frame(width: 340, height: 340)
                .offset(x: 170, y: 420)
        }
        .allowsHitTesting(false)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 26, opacity: Double = 0.6) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white.opacity(opacity))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.9), lineWidth: 1)
                )
                .shadow(color: Ink.shadow.opacity(0.12), radius: 15, y: 10)
        )
    }

    func glassPill() -> some View {
        padding(.vertical, 7)
            .padding(.horizontal, 14)
            .background(
                Capsule()
                    .fill(.white.opacity(0.6))
                    .overlay(Capsule().stroke(.white.opacity(0.9), lineWidth: 1))
            )
    }

    /// Entrance animation: `pop` mirrors the design's fg-pop, otherwise fg-fade.
    func appear(delay: Double = 0, pop: Bool = false) -> some View {
        modifier(AppearModifier(delay: delay, pop: pop))
    }
}

private struct AppearModifier: ViewModifier {
    let delay: Double
    let pop: Bool
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown || !pop ? 1 : 0.4)
            .offset(y: shown ? 0 : (pop ? 14 : 8))
            .onAppear {
                let animation: Animation = pop
                    ? .spring(response: 0.5, dampingFraction: 0.55).delay(delay)
                    : .easeOut(duration: 0.5).delay(delay)
                withAnimation(animation) { shown = true }
            }
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Seconds since reference date, frozen when Reduce Motion is on.
struct Ticker<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let content: (Double) -> Content

    init(@ViewBuilder content: @escaping (Double) -> Content) {
        self.content = content
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: reduceMotion)) { context in
            content(reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate)
        }
    }
}

/// 0→1→0 over `period`, eased like CSS ease-in-out.
func wave(_ t: Double, period: Double, delay: Double = 0) -> Double {
    0.5 - 0.5 * cos(2 * .pi * (t - delay) / period)
}

/// 0→1 sawtooth over `period`.
func cycle(_ t: Double, period: Double, delay: Double = 0) -> Double {
    let value = (t - delay).truncatingRemainder(dividingBy: period) / period
    return value < 0 ? value + 1 : value
}
