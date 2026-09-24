import SwiftUI

/// The anthropomorphic emotion ball from design/Figure.dc.html.
/// Drawn on a 100×100 grid (same numbers as the design) and scaled to `size`.
struct FigureView: View {
    enum Mood { case idle, fed }

    let kind: FigureKind
    var size: CGFloat = 120
    var mood: Mood = .idle
    var dim = false
    var glow: Double = 0.3
    var lookX: Double = 0
    var lookY: Double = 0
    var still = false

    var body: some View {
        Group {
            if still {
                figure(t: 0)
            } else {
                Ticker { t in figure(t: t) }
            }
        }
        .frame(width: 100, height: 100)
        .scaleEffect(size / 100)
        .frame(width: size, height: size)
        .opacity(dim ? 0.45 : 1)
        .saturation(dim ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.6), value: dim)
        .accessibilityElement()
        .accessibilityLabel(kind.displayName)
    }

    private var palette: FigurePalette { kind.palette }

    private func figure(t: Double) -> some View {
        ZStack(alignment: .topLeading) {
            Ellipse()
                .fill(Color(red: 80 / 255, green: 60 / 255, blue: 120 / 255, opacity: 0.16))
                .frame(width: 60, height: 10)
                .blur(radius: 3)
                .offset(x: 20, y: 98)

            ZStack(alignment: .topLeading) {
                halo
                ball
                highlight
                face(t: t)
                    .offset(x: lookX * 6, y: lookY * 4)
                    .animation(.easeInOut(duration: 0.8), value: lookX)
                    .animation(.easeInOut(duration: 0.8), value: lookY)
            }
            .frame(width: 100, height: 100, alignment: .topLeading)
            .modifier(IdleMotion(kind: kind, fed: mood == .fed, t: still ? 0 : t))
        }
        .frame(width: 100, height: 100, alignment: .topLeading)
    }

    private var halo: some View {
        let color = palette.glow.opacity(0.2 + glow * 0.5)
        return Circle()
            .fill(RadialGradient(
                stops: [
                    .init(color: color, location: 0),
                    .init(color: color, location: 0.35),
                    .init(color: palette.glow.opacity(0), location: 0.7)
                ],
                center: .center, startRadius: 0, endRadius: 99
            ))
            .frame(width: 140, height: 140)
            .offset(x: -20, y: -20)
            .animation(.easeInOut(duration: 0.6), value: glow)
    }

    private var ball: some View {
        Circle()
            .fill(RadialGradient(
                stops: [
                    .init(color: .white, location: 0),
                    .init(color: palette.light, location: 0.13),
                    .init(color: palette.base, location: 0.52),
                    .init(color: palette.dark, location: 1)
                ],
                center: UnitPoint(x: 0.32, y: 0.26), startRadius: 0, endRadius: 100
            ))
            .overlay(
                Circle().fill(RadialGradient(
                    colors: [.clear, .black.opacity(0.08)],
                    center: UnitPoint(x: 0.4, y: 0.35), startRadius: 32, endRadius: 62
                ))
            )
            .frame(width: 100, height: 100)
            .shadow(color: palette.glow.opacity(0.35), radius: 12, y: 10)
    }

    private var highlight: some View {
        Ellipse()
            .fill(LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: 36, height: 20)
            .rotationEffect(.degrees(-22))
            .opacity(0.85)
            .offset(x: 18, y: 10)
    }

    @ViewBuilder
    private func face(t: Double) -> some View {
        ZStack(alignment: .topLeading) {
            blush.offset(x: 17, y: 55)
            blush.offset(x: 69, y: 55)

            if mood == .fed {
                fedFace
            } else {
                switch kind {
                case .joy: joyFace
                case .sadness: sadnessFace(t: t)
                case .anger: angerFace(t: t)
                case .fear: fearFace
                }
            }
        }
        .frame(width: 100, height: 100, alignment: .topLeading)
    }

    private var blush: some View {
        Ellipse()
            .fill(Color(red: 1, green: 105 / 255, blue: 140 / 255, opacity: 0.45))
            .frame(width: 14, height: 9)
            .blur(radius: 1.5)
            .opacity(mood == .fed ? 1 : 0.6)
    }

    private func dot(_ w: CGFloat, _ h: CGFloat, _ x: CGFloat, _ y: CGFloat) -> some View {
        Ellipse().fill(Ink.face).frame(width: w, height: h).offset(x: x, y: y)
    }

    private func brow(_ w: CGFloat, _ h: CGFloat, _ x: CGFloat, _ y: CGFloat, _ degrees: Double) -> some View {
        Capsule().fill(Ink.face).frame(width: w, height: h).rotationEffect(.degrees(degrees)).offset(x: x, y: y)
    }

    private func arc(_ w: CGFloat, _ h: CGFloat, _ x: CGFloat, _ y: CGFloat, up: Bool, line: CGFloat = 3.5) -> some View {
        ArcShape(up: up)
            .stroke(Ink.face, style: StrokeStyle(lineWidth: line, lineCap: .round))
            .frame(width: w, height: h)
            .offset(x: x, y: y)
    }

    private var joyFace: some View {
        ZStack(alignment: .topLeading) {
            dot(8, 11, 33, 40)
            dot(8, 11, 59, 40)
            arc(26, 13, 37, 54, up: false)
        }
    }

    private func sadnessFace(t: Double) -> some View {
        let p = cycle(t, period: 3.2)
        let fall = p < 0.55 ? 0 : pow((p - 0.55) / 0.45, 2)
        return ZStack(alignment: .topLeading) {
            brow(15, 3.5, 28, 35, -16)
            brow(15, 3.5, 57, 35, 16)
            dot(8, 9, 33, 44)
            dot(8, 9, 59, 44)
            arc(18, 8, 41, 62, up: true)
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 3.5,
                                   bottomTrailingRadius: 3.5, topTrailingRadius: 3.5)
                .fill(Color(hex: 0xE6F3FF))
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 3.5,
                                           bottomTrailingRadius: 3.5, topTrailingRadius: 3.5)
                        .stroke(Color(hex: 0x8FB6EE), lineWidth: 1.5)
                )
                .frame(width: 7, height: 7)
                .rotationEffect(.degrees(45))
                .offset(x: 31, y: 56 + 9 * fall)
                .opacity(1 - fall)
        }
    }

    private func angerFace(t: Double) -> some View {
        ZStack(alignment: .topLeading) {
            brow(17, 4, 27, 36, 20)
            brow(17, 4, 56, 36, -20)
            dot(8, 9, 34, 45)
            dot(8, 9, 58, 45)
            arc(20, 7, 40, 62, up: true)
            steam(13, 72, -6, opacity: 0.9, p: cycle(t, period: 1.8))
            steam(9, 84, 4, opacity: 0.85, p: cycle(t, period: 1.8, delay: 0.6))
        }
    }

    private func steam(_ d: CGFloat, _ x: CGFloat, _ y: CGFloat, opacity: Double, p: Double) -> some View {
        let eased = 1 - pow(1 - p, 2)
        let alpha = p < 0.4 ? 0.95 * p / 0.4 : 0.95 * (1 - (p - 0.4) / 0.6)
        return Circle()
            .fill(.white.opacity(opacity))
            .frame(width: d, height: d)
            .scaleEffect(0.6 + 0.55 * eased)
            .offset(x: x, y: y + 4 - 16 * eased)
            .opacity(alpha)
    }

    private var fearFace: some View {
        ZStack(alignment: .topLeading) {
            brow(13, 3, 29, 27, -12)
            brow(13, 3, 58, 27, 12)
            fearEye(pupilX: 7).offset(x: 26, y: 34)
            fearEye(pupilX: 5).offset(x: 54, y: 34)
            Ellipse()
                .stroke(Ink.face, lineWidth: 3)
                .frame(width: 9, height: 8)
                .offset(x: 45.5, y: 62.5)
        }
    }

    private func fearEye(pupilX: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Circle().fill(.white)
                .shadow(color: Color(red: 60 / 255, green: 40 / 255, blue: 90 / 255, opacity: 0.25), radius: 1.5, y: 1)
            Circle().fill(Ink.face).frame(width: 8, height: 8).offset(x: pupilX, y: 7)
        }
        .frame(width: 20, height: 20, alignment: .topLeading)
    }

    private var fedFace: some View {
        let mouth = UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 12,
                                           bottomTrailingRadius: 12, topTrailingRadius: 0)
        return ZStack(alignment: .topLeading) {
            arc(15, 8, 29, 42, up: true)
            arc(15, 8, 56, 42, up: true)
            ZStack(alignment: .topLeading) {
                mouth.fill(Color(hex: 0x6B2A3E))
                Ellipse().fill(Color(hex: 0xFF8FA3)).frame(width: 12, height: 9).offset(x: 6, y: 6)
            }
            .frame(width: 24, height: 13, alignment: .topLeading)
            .clipShape(mouth)
            .offset(x: 38, y: 55)
        }
    }
}

/// Idle personality: Joy bounces, Sadness sways, Anger puffs, Fear trembles.
private struct IdleMotion: ViewModifier {
    let kind: FigureKind
    let fed: Bool
    let t: Double

    func body(content: Content) -> some View {
        var y = 0.0, x = 0.0, angle = 0.0, scale = 1.0
        if fed {
            y = -6 * wave(t, period: 1.8)
        } else {
            switch kind {
            case .joy: y = -6 * wave(t, period: 2.6)
            case .sadness: angle = -3 + 6 * wave(t, period: 4.2)
            case .anger: scale = 1 + 0.05 * wave(t, period: 1.6)
            case .fear: x = -1.3 * sin(2 * .pi * t / 0.32)
            }
        }
        return content
            .scaleEffect(scale)
            .rotationEffect(.degrees(angle))
            .offset(x: x, y: y)
    }
}

/// Half-ellipse stroke: `up == false` is a smile (∪), `up == true` a frown / closed eye (∩).
struct ArcShape: Shape {
    var up: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bulge = rect.height * 4 / 3
        if up {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                          control1: CGPoint(x: rect.minX, y: rect.maxY - bulge),
                          control2: CGPoint(x: rect.maxX, y: rect.maxY - bulge))
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                          control1: CGPoint(x: rect.minX, y: rect.minY + bulge),
                          control2: CGPoint(x: rect.maxX, y: rect.minY + bulge))
        }
        return path
    }
}

#Preview {
    HStack {
        ForEach(FigureKind.allCases) { kind in
            FigureView(kind: kind, size: 80)
        }
    }
    .padding(40)
    .background(AppBackground())
}
