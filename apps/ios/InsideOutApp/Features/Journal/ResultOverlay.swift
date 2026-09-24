import SwiftUI

/// "Who got fed" — sits on top of the stage, where the fed Figures have
/// already moved to centre. Positions follow the design artboard.
struct ResultOverlay: View {
    @ObservedObject var vm: JournalViewModel
    let analysis: EventAnalysis

    @State private var expFilled = false
    @State private var replaying = false
    @State private var showingOriginal = false

    private var primary: FigureFeed { analysis.feeds[0] }
    private var secondary: FigureFeed? { analysis.feeds.count > 1 ? analysis.feeds[1] : nil }
    private var bond: RelationshipPromotion? { analysis.promotedRelationship }
    /// Centre x of the most-fed Figure; must match `resultSlot` in JournalView.
    private var primaryX: CGFloat { secondary == nil ? 195 : 102 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            summaryCard
                .offset(x: 20, y: 62)
                .appear()

            if let secondary, let bond {
                BondArc(from: primary.figure.palette.base, to: secondary.figure.palette.base)
                bondHeart
                Text("+\(bond.points) bond")
                    .font(.rounded(13, .black))
                    .foregroundStyle(.white)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(Capsule().fill(Ink.primary))
                    .fixedSize()
                    .frame(width: 120)
                    .offset(x: 200 - 60, y: 236)
                    .appear(delay: 1.1, pop: true)

                feedNumber(secondary, size: 28, centerX: 288, top: 206, delay: 0.7)
                percentPill(secondary).offset(x: 316, y: 326)
                FedColumn(feed: secondary, before: vm.baseline[secondary.figure], filled: expFilled)
                    .offset(x: 203, y: 380)
            }

            feedNumber(primary, size: 34, centerX: primaryX, top: 190, delay: 0.4)
            if secondary != nil {
                // A lone Figure is always 100% — the pill would add nothing.
                percentPill(primary).offset(x: primaryX + 38, y: 336)
            }
            FedColumn(feed: primary, before: vm.baseline[primary.figure], filled: expFilled)
                .offset(x: primaryX - 85, y: 380)

            Sparkles()

            if let bond {
                HStack(spacing: 8) {
                    Text("♥").foregroundStyle(Ink.heart)
                    Text("\(bond.firstFigure.displayName) & \(bond.secondFigure.displayName) grew closer")
                }
                .font(.rounded(13, .heavy))
                .foregroundStyle(Ink.secondary)
                .padding(.vertical, 7)
                .padding(.horizontal, 14)
                .background(Capsule().fill(.white.opacity(0.55)))
                .frame(width: 390)
                .offset(y: 596)
                .appear(delay: 1.5)
            }

            Button(action: vm.save) {
                Text(vm.isSaved ? "Saved" : "Save this memory")
                    .font(.rounded(17, .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 342, height: 58)
                    .background(Capsule().fill(Ink.primary))
                    .shadow(color: Ink.primary.opacity(0.3), radius: 14, y: 12)
            }
            .buttonStyle(PressableStyle())
            .disabled(vm.isSaved)
            .offset(x: 24, y: 660)

            Button(action: vm.tellAnother) {
                Text("Tell another")
                    .font(.rounded(14, .bold))
                    .foregroundStyle(Ink.muted)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
            }
            .frame(width: 390)
            .offset(y: 734)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.timingCurve(0.2, 1, 0.3, 1, duration: 1.3)) { expFilled = true }
            }
        }
    }

    private var summaryCard: some View {
        // Replay sits on the timestamp row (not below the text as in the
        // design) so the card stays clear of the "+N" pop above the Figure.
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(vm.capturedLabel.uppercased())
                    .font(.rounded(12, .heavy))
                    .tracking(1)
                    .foregroundStyle(Ink.label)
                Spacer(minLength: 8)
                if vm.inputMode == .voice {
                    replayChip
                }
                Button { showingOriginal = true } label: {
                    Image(systemName: "text.quote")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Ink.primary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Ink.primary.opacity(0.07)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("See what you said")
            }
            Text(analysis.summary)
                .font(.rounded(16, .bold))
                .lineSpacing(2)
                .lineLimit(2)
            if analysis.isKeywordGuess {
                // Be honest when the language model wasn't used.
                Label("Offline guess from keywords — couldn’t reach your Figures", systemImage: "wifi.slash")
                    .font(.rounded(12, .bold))
                    .foregroundStyle(Ink.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .frame(width: 350, alignment: .leading)
        .glassCard()
        .contentShape(Rectangle())
        .onTapGesture { showingOriginal = true }
        .sheet(isPresented: $showingOriginal) {
            OriginalInputSheet(
                text: vm.lastInputText,
                source: vm.inputMode == .voice ? "You said · 0:" + String(format: "%02d", vm.recordedSeconds) : "You wrote",
                onEdit: {
                    showingOriginal = false
                    vm.editLastInput()
                }
            )
        }
    }

    /// No audio is recorded yet (Sprint 1), so this only toggles its label.
    private var replayChip: some View {
        Button {
            replaying = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { replaying = false }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(Ink.primary)
                    .frame(width: 20, height: 20)
                    .overlay(Image(systemName: "play.fill").font(.system(size: 8)).foregroundStyle(.white).offset(x: 1))
                Text((replaying ? "Playing… " : "Replay · ") + "0:" + String(format: "%02d", vm.recordedSeconds))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
            }
            .font(.rounded(12, .heavy))
            .foregroundStyle(Ink.primary)
            .padding(.leading, 4)
            .padding(.trailing, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Ink.primary.opacity(0.07)))
        }
        .buttonStyle(.plain)
    }

    private var bondHeart: some View {
        Ticker { t in
            Text("♥")
                .font(.system(size: 17))
                .foregroundStyle(Ink.heart)
                .frame(width: 30, height: 30)
                .background(Circle().fill(.white))
                .shadow(color: Color(red: 1, green: 120 / 255, blue: 150 / 255, opacity: 0.45), radius: 8, y: 4)
                .scaleEffect(1 + 0.15 * wave(t, period: 1.6))
        }
        .frame(width: 30, height: 30)
        .offset(x: 185, y: 269)
    }

    private func feedNumber(_ feed: FigureFeed, size: CGFloat, centerX: CGFloat, top: CGFloat, delay: Double) -> some View {
        let palette = feed.figure.palette
        return Text("+\(feed.feedAmount)")
            .font(.rounded(size, .black))
            .foregroundStyle(palette.dark)
            .shadow(color: .white, radius: 0, y: 2)
            .shadow(color: palette.glow.opacity(0.5), radius: 9, y: 6)
            .fixedSize()
            .frame(width: 120)
            .offset(x: centerX - 60, y: top)
            .appear(delay: delay, pop: true)
            .accessibilityLabel("\(feed.figure.displayName) fed \(feed.feedAmount)")
    }

    private func percentPill(_ feed: FigureFeed) -> some View {
        Text("\(Int((feed.concentration * 100).rounded()))%")
            .font(.rounded(12, .black))
            .foregroundStyle(feed.figure.palette.dark)
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(Capsule().fill(.white.opacity(0.85)))
            .shadow(color: Ink.shadow.opacity(0.15), radius: 4, y: 2)
            .fixedSize()
    }
}

/// Name, level, EXP bar and speech bubble under a fed Figure.
private struct FedColumn: View {
    let feed: FigureFeed
    let before: FigureState?
    let filled: Bool

    var body: some View {
        let palette = feed.figure.palette
        let startExp = before?.exp ?? 0
        let endExp = min(100, startExp + feed.feedAmount)

        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Text(feed.figure.displayName)
                    .font(.rounded(18, .black))
                Text("Lv \(before?.level ?? 1)")
                    .font(.rounded(12, .black))
                    .foregroundStyle(palette.badgeText)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 8)
                    .background(Capsule().fill(palette.badgeBackground))
            }

            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.7))
                Capsule()
                    .fill(LinearGradient(colors: [palette.barStart, palette.dark], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 118 * CGFloat(filled ? endExp : startExp) / 100)
            }
            .frame(width: 118, height: 9)
            .accessibilityLabel("Experience \(filled ? endExp : startExp) of 100")

            Text("“\(feed.voiceLine)”")
                .font(.rounded(13, .bold))
                .lineSpacing(1)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white.opacity(0.78))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.95), lineWidth: 1))
                        .shadow(color: Ink.shadow.opacity(0.1), radius: 9, y: 6)
                )
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.95))
                        .frame(width: 11, height: 11)
                        .rotationEffect(.degrees(45))
                        .offset(y: -5.5)
                }
                .padding(.top, 8)
                .appear(delay: 1.3)
        }
        .frame(width: 170)
        .appear(delay: 0.9)
    }
}

private struct BondArc: View {
    let from: Color
    let to: Color

    var body: some View {
        let gradient = LinearGradient(colors: [from, to],
                                      startPoint: UnitPoint(x: 160 / 390, y: 0), endPoint: UnitPoint(x: 240 / 390, y: 0))
        let arc = Path { path in
            path.move(to: CGPoint(x: 160, y: 302))
            path.addQuadCurve(to: CGPoint(x: 240, y: 302), control: CGPoint(x: 199, y: 262))
        }
        Ticker { t in
            ZStack {
                arc.stroke(gradient, style: StrokeStyle(lineWidth: 10, lineCap: .round)).opacity(0.25)
                arc.stroke(gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                arc.stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 16],
                                                      dashPhase: CGFloat(-40 * cycle(t, period: 1.4))))
            }
        }
        .frame(width: 390, height: 844)
        .allowsHitTesting(false)
    }
}

private struct Sparkles: View {
    private let specs: [(x: CGFloat, y: CGFloat, size: CGFloat, gold: Bool, period: Double, delay: Double)] = [
        (58, 204, 9, true, 1.6, 0.5), (146, 196, 7, false, 1.4, 0.9),
        (250, 218, 7, false, 1.5, 0.7), (326, 212, 9, true, 1.7, 1.0)
    ]

    var body: some View {
        Ticker { t in
            ZStack(alignment: .topLeading) {
                ForEach(specs.indices, id: \.self) { index in
                    let spec = specs[index]
                    let p = wave(t, period: spec.period, delay: spec.delay)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(spec.gold ? Ink.spark : .white)
                        .frame(width: spec.size, height: spec.size)
                        .scaleEffect(0.4 + 0.6 * p)
                        .rotationEffect(.degrees(45))
                        .opacity(p)
                        .offset(x: spec.x, y: spec.y)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// "What you said" — the untouched input behind the summary, with a way back
/// to edit and resend it (PRD §31 A).
private struct OriginalInputSheet: View {
    let text: String
    let source: String
    let onEdit: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(source.uppercased())
                .font(.rounded(12, .heavy))
                .tracking(1)
                .foregroundStyle(Ink.label)
            ScrollView {
                Text(text)
                    .font(.rounded(17, .semibold))
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 220)

            Button(action: onEdit) {
                Label("Edit and ask again", systemImage: "pencil")
                    .font(.rounded(16, .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Capsule().fill(Ink.primary))
            }
            .buttonStyle(PressableStyle())

            Button("Close") { dismiss() }
                .font(.rounded(14, .bold))
                .foregroundStyle(Ink.muted)
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(Ink.primary)
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(34)
        .presentationBackground(.white.opacity(0.94))
    }
}
