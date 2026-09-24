import SwiftUI

/// "Your Figures" — the four Figures on their island with energy rings,
/// relationship threads, and a weekly trend card for the selected one.
struct FiguresScreen: View {
    @ObservedObject var vm: JournalViewModel

    private static let spots: [FigureKind: (x: CGFloat, y: CGFloat, size: CGFloat)] = [
        .joy: (112, 258, 96), .sadness: (286, 250, 74), .anger: (120, 430, 118), .fear: (285, 425, 90)
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            header("Your Figures", "Tap one to check in")
                .offset(x: 28, y: 62)

            Ellipse()
                .fill(RadialGradient(colors: [.white.opacity(0.75), .white.opacity(0.25)],
                                     center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: 210))
                .overlay(Ellipse().stroke(.white.opacity(0.8), lineWidth: 1))
                .shadow(color: Color(red: 140 / 255, green: 100 / 255, blue: 190 / 255, opacity: 0.15), radius: 30, y: 30)
                .frame(width: 366, height: 430)
                .offset(x: 12, y: 150)

            RelationshipThreads()

            ForEach(FigureKind.allCases) { kind in
                islandFigure(kind)
            }

            HStack(spacing: 18) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0xC9A3E0)).frame(width: 18, height: 4)
                    Text("closer")
                }
                HStack(spacing: 6) {
                    Path { $0.move(to: .init(x: 0, y: 1.5)); $0.addLine(to: .init(x: 18, y: 1.5)) }
                        .stroke(Color(hex: 0xFF9A88), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [0.1, 5]))
                        .frame(width: 18, height: 3)
                    Text("tension")
                }
            }
            .font(.rounded(11, .heavy))
            .foregroundStyle(Ink.label)
            .frame(width: 390)
            .offset(y: 548)

            TrendCard(state: vm.figures[vm.selectedFigure]!)
                .offset(x: 20, y: 592)
        }
        .appear()
    }

    private func islandFigure(_ kind: FigureKind) -> some View {
        let spot = Self.spots[kind]!
        let state = vm.figures[kind]!
        let selected = vm.selectedFigure == kind
        let ring = spot.size + 16

        return ZStack(alignment: .top) {
            ZStack {
                Circle().stroke(.white.opacity(0.7), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: state.energy)
                    .stroke(kind.palette.dark, style: StrokeStyle(lineWidth: selected ? 6 : 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: ring, height: ring)
            .offset(y: -8)

            FigureView(kind: kind, size: spot.size, glow: selected ? 0.8 : 0.35)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(kind.displayName).font(.rounded(14, .black))
                Text("Lv \(state.level)").font(.rounded(11, .heavy)).foregroundStyle(Ink.muted)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 10)
            .background(Capsule().fill(.white.opacity(selected ? 0.9 : 0)))
            .fixedSize()
            .offset(y: spot.size + 14)
        }
        .frame(width: spot.size, height: spot.size, alignment: .top)
        .scaleEffect(selected ? 1.06 : 1)
        .contentShape(Circle())
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { vm.selectedFigure = kind }
        }
        .offset(x: spot.x - spot.size / 2, y: spot.y - spot.size / 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.displayName), level \(state.level), \(Int(state.energy * 100))% energy")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

func header(_ title: String, _ subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title)
            .font(.rounded(30, .black))
            .tracking(-0.6)
        Text(subtitle)
            .font(.rounded(14, .semibold))
            .foregroundStyle(Ink.muted)
    }
}

/// Decorative for now — the PRD keeps the real relationship graph out of MVP scope.
private struct RelationshipThreads: View {
    var body: some View {
        ZStack {
            let angerFear = Path { p in
                p.move(to: .init(x: 120, y: 430)); p.addQuadCurve(to: .init(x: 285, y: 425), control: .init(x: 202, y: 480))
            }
            let warm = LinearGradient(colors: [Color(hex: 0xFF8B78), Color(hex: 0xB99AF0)],
                                      startPoint: UnitPoint(x: 120 / 390, y: 0), endPoint: UnitPoint(x: 285 / 390, y: 0))
            angerFear.stroke(warm, style: StrokeStyle(lineWidth: 16, lineCap: .round)).opacity(0.2)
            angerFear.stroke(warm, style: StrokeStyle(lineWidth: 7, lineCap: .round))

            Path { p in
                p.move(to: .init(x: 112, y: 258)); p.addQuadCurve(to: .init(x: 286, y: 250), control: .init(x: 199, y: 214))
            }
            .stroke(LinearGradient(colors: [Color(hex: 0xFFD84D), Color(hex: 0x94A9F3)],
                                   startPoint: UnitPoint(x: 112 / 390, y: 0), endPoint: UnitPoint(x: 286 / 390, y: 0)),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .opacity(0.8)

            Path { p in
                p.move(to: .init(x: 112, y: 258)); p.addQuadCurve(to: .init(x: 120, y: 430), control: .init(x: 62, y: 344))
            }
            .stroke(Color(hex: 0xFF9A88), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [3, 9]))
            .opacity(0.9)

            Path { p in
                p.move(to: .init(x: 286, y: 250)); p.addQuadCurve(to: .init(x: 285, y: 425), control: .init(x: 336, y: 338))
            }
            .stroke(Color(hex: 0xA9B6F5), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .opacity(0.8)
        }
        .frame(width: 390, height: 844)
        .allowsHitTesting(false)
    }
}

private struct TrendCard: View {
    let state: FigureState

    var body: some View {
        let color = state.kind.palette.dark
        let change = Int((state.trend.last ?? 0) - (state.trend.first ?? 0))
        let up = change >= 0

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                FigureView(kind: state.kind, size: 40, still: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.headline)
                        .font(.rounded(15, .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text("Lv \(state.level) · \(Int((state.energy * 100).rounded()))% energy")
                        .font(.rounded(12, .bold))
                        .foregroundStyle(Ink.muted)
                }
                Spacer(minLength: 0)
                Text(up ? "+\(change)" : "−\(-change)")
                    .font(.rounded(13, .black))
                    .foregroundStyle(up ? .white : Ink.secondary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(Capsule().fill(up ? Ink.primary : Ink.primary.opacity(0.08)))
            }
            Sparkline(values: state.trend, color: color)
                .frame(width: 312, height: 40)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .frame(width: 350, alignment: .leading)
        .glassCard(opacity: 0.62)
        .animation(.easeInOut(duration: 0.3), value: state)
    }
}

private struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        let points = normalized
        ZStack(alignment: .topLeading) {
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                points.dropFirst().forEach { path.addLine(to: $0) }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

            if let last = points.last {
                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(color, lineWidth: 3))
                    .frame(width: 10, height: 10)
                    .offset(x: last.x - 5, y: last.y - 5)
            }
        }
    }

    private var normalized: [CGPoint] {
        guard let high = values.max(), let low = values.min() else { return [] }
        let range = high - low == 0 ? 1 : high - low
        return values.enumerated().map { index, value in
            CGPoint(x: 6 + CGFloat(index) * 50, y: 34 - CGFloat((value - low) / range) * 28)
        }
    }
}
