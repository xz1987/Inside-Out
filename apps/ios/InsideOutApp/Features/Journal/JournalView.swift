import SwiftUI

/// Root of the redesigned app. Layout follows design/Inside Out.dc.html,
/// using its 390×844 artboard coordinates via `DesignCanvas`.
struct JournalView: View {
    @StateObject private var vm = JournalViewModel()

    var body: some View {
        ZStack {
            AppBackground()
            DesignCanvas {
                ZStack(alignment: .topLeading) {
                    BackgroundBlobs()
                    if vm.showsStage {
                        StageView(vm: vm)
                    }
                    screenContent
                    if vm.showsTabs {
                        TabBar(vm: vm)
                            .offset(x: 24, y: 752)
                    }
                    if let toast = vm.toast {
                        ToastView(text: toast)
                            .frame(width: DesignCanvas<EmptyView>.width)
                            .offset(y: 60)
                            .transition(.opacity.combined(with: .offset(y: 8)))
                            .zIndex(10)
                    }
                }
            }
        }
        .foregroundStyle(Ink.primary)
        .sheet(isPresented: $vm.isTyping) {
            TypeSheet(vm: vm)
        }
    }

    @ViewBuilder
    private var screenContent: some View {
        switch vm.screen {
        case .home:
            HomeOverlay(vm: vm).transition(.opacity)
        case .listening:
            ListeningOverlay(vm: vm).transition(.opacity)
        case .result:
            if let analysis = vm.analysis {
                ResultOverlay(vm: vm, analysis: analysis).transition(.opacity)
            }
        case .figures:
            FiguresScreen(vm: vm).transition(.opacity)
        case .memories:
            MemoriesScreen(vm: vm).transition(.opacity)
        }
    }
}

// MARK: - Stage: the four Figures and the mic

private struct StageSlot {
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var mood: FigureView.Mood = .idle
    var dim = false
    var glow = 0.3
    var lookX = 0.0
    var lookY = 0.0
}

private struct StageView: View {
    @ObservedObject var vm: JournalViewModel

    var body: some View {
        let listening = vm.screen == .listening
        let result = vm.screen == .result
        let mic = listening ? CGPoint(x: 195, y: 515) : CGPoint(x: 195, y: 420)
        let micSize: CGFloat = listening ? 150 : 176
        let levels = vm.listeningLevels

        ZStack(alignment: .topLeading) {
            ForEach(FigureKind.allCases) { kind in
                let slot = slot(for: kind, mic: mic, levels: levels)
                FigureView(kind: kind, size: slot.size, mood: slot.mood, dim: slot.dim,
                           glow: slot.glow, lookX: slot.lookX, lookY: slot.lookY)
                    .offset(x: slot.x - slot.size / 2, y: slot.y - slot.size / 2)
                    .zIndex(kind == .fear ? 4 : 6)
            }

            MicButton(listening: listening, thinking: vm.isInterpreting, diameter: micSize, action: vm.micTapped)
                .offset(x: mic.x - micSize / 2, y: mic.y - micSize / 2)
                .opacity(result ? 0 : 1)
                .scaleEffect(result ? 0.3 : 1)
                .allowsHitTesting(!result)
                .zIndex(5)
        }
        .animation(.spring(response: 0.9, dampingFraction: 0.7), value: vm.screen)
        .animation(.spring(response: 0.9, dampingFraction: 0.7), value: levels)
    }

    private func slot(for kind: FigureKind, mic: CGPoint, levels: [FigureKind: Int]) -> StageSlot {
        switch vm.screen {
        case .listening:
            return listeningSlot(for: kind, mic: mic, levels: levels)
        case .result:
            return resultSlot(for: kind)
        default:
            let home: [FigureKind: (CGFloat, CGFloat, CGFloat)] = [
                .joy: (80, 290, 88), .anger: (315, 285, 80), .sadness: (72, 540, 76), .fear: (318, 548, 78)
            ]
            let (x, y, size) = home[kind]!
            return looking(StageSlot(x: x, y: y, size: size), at: mic)
        }
    }

    /// Figures swell toward the mic as they hear words that concern them.
    private func listeningSlot(for kind: FigureKind, mic: CGPoint, levels: [FigureKind: Int]) -> StageSlot {
        let steps: [FigureKind: [(CGFloat, CGFloat, CGFloat)]] = [
            .anger: [(322, 400, 64), (305, 410, 92), (296, 405, 112)],
            .fear: [(330, 650, 60), (302, 628, 86), (292, 618, 102)],
            .joy: [(66, 410, 62), (85, 410, 92), (94, 405, 112)],
            .sadness: [(64, 628, 58), (88, 628, 86), (98, 618, 102)]
        ]
        let level = levels[kind, default: 0]
        let anyEngaged = levels.values.contains { $0 > 0 }
        let (x, y, size) = steps[kind]![level]
        var slot = StageSlot(x: x, y: y, size: size, glow: 0.3 + Double(level) * 0.3)
        if level == 0 && anyEngaged {
            slot.size = 50
            slot.dim = true
        }
        return looking(slot, at: mic)
    }

    /// Most-fed Figure takes centre stage; the uninvolved two wait at the edges.
    private func resultSlot(for kind: FigureKind) -> StageSlot {
        let fed = vm.analysis?.feeds.map(\.figure) ?? []
        if fed.first == kind {
            // A lone Figure takes the centre; with a partner it shifts left.
            return fed.count == 1
                ? StageSlot(x: 195, y: 305, size: 132, mood: .fed, glow: 0.95, lookY: 0.2)
                : StageSlot(x: 102, y: 305, size: 124, mood: .fed, glow: 0.95, lookX: 0.8, lookY: 0.2)
        }
        if fed.count > 1, fed[1] == kind {
            return StageSlot(x: 288, y: 305, size: 100, mood: .fed, glow: 0.6, lookX: -0.8, lookY: 0.2)
        }
        // Uninvolved Figures wait, dimmed, at the edges.
        let edges: [(x: CGFloat, y: CGFloat, look: Double)] = [(14, 250, 1), (378, 250, -1), (14, 372, 1), (378, 372, -1)]
        let index = FigureKind.allCases.filter { !fed.contains($0) }.firstIndex(of: kind) ?? 0
        let edge = edges[min(index, edges.count - 1)]
        return StageSlot(x: edge.x, y: edge.y, size: 46, dim: true, glow: 0.1, lookX: edge.look, lookY: 0.2)
    }

    private func looking(_ slot: StageSlot, at point: CGPoint) -> StageSlot {
        var slot = slot
        slot.lookX = max(-1, min(1, (point.x - slot.x) / 140))
        slot.lookY = max(-1, min(1, (point.y - slot.y) / 180))
        return slot
    }
}

private struct MicButton: View {
    let listening: Bool
    let thinking: Bool
    let diameter: CGFloat
    let action: () -> Void

    var body: some View {
        ZStack {
            if listening {
                ListeningRings(diameter: diameter)
            }
            Circle()
                .fill(.white.opacity(0.28))
                .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1))
                .frame(width: diameter + 28, height: diameter + 28)

            Button(action: action) {
                VStack(spacing: 8) {
                    MicGlyph()
                    Text(thinking ? "Thinking…" : listening ? "Listening…" : "Tap to tell me")
                        .font(.rounded(14, .heavy))
                        .foregroundStyle(Ink.primary)
                }
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(gradient))
                .overlay(Circle().stroke(.white.opacity(0.95), lineWidth: 1))
                .shadow(color: shadowColor, radius: 25, y: 20)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(listening ? "Stop and share" : "Start telling")
        }
        .frame(width: diameter, height: diameter)
    }

    private var gradient: RadialGradient {
        let stops: [Gradient.Stop] = listening
            ? [.init(color: .white, location: 0), .init(color: Color(hex: 0xFBE8F3), location: 0.45), .init(color: Color(hex: 0xE6CDF3), location: 1)]
            : [.init(color: .white, location: 0), .init(color: Color(hex: 0xF3EEFC), location: 0.45), .init(color: Color(hex: 0xD9D0F3), location: 1)]
        return RadialGradient(stops: stops, center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: diameter * 0.8)
    }

    private var shadowColor: Color {
        listening
            ? Color(red: 230 / 255, green: 130 / 255, blue: 190 / 255, opacity: 0.4)
            : Color(red: 140 / 255, green: 110 / 255, blue: 200 / 255, opacity: 0.35)
    }
}

private struct MicGlyph: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10).fill(Ink.primary)
                .frame(width: 18, height: 28).offset(x: 8)
            ArcShape(up: false)
                .stroke(Ink.primary, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .frame(width: 28, height: 16).offset(x: 3, y: 17)
            RoundedRectangle(cornerRadius: 2).fill(Ink.primary)
                .frame(width: 3.5, height: 8).offset(x: 15.25, y: 35)
        }
        .frame(width: 34, height: 46, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

private struct ListeningRings: View {
    let diameter: CGFloat

    var body: some View {
        Ticker { t in
            ZStack {
                ring(Color.white.opacity(0.95), t: t, delay: 0)
                ring(Color(red: 190 / 255, green: 160 / 255, blue: 240 / 255, opacity: 0.7), t: t, delay: 0.8)
                ring(Color(red: 1, green: 180 / 255, blue: 210 / 255, opacity: 0.7), t: t, delay: 1.6)
            }
        }
        .allowsHitTesting(false)
    }

    private func ring(_ color: Color, t: Double, delay: Double) -> some View {
        let p = 1 - pow(1 - cycle(t, period: 2.4, delay: delay), 2)
        return Circle()
            .stroke(color, lineWidth: 2)
            .frame(width: diameter, height: diameter)
            .scaleEffect(1 + 0.9 * p)
            .opacity(0.8 * (1 - p))
    }
}

// MARK: - Home

private struct HomeOverlay: View {
    @ObservedObject var vm: JournalViewModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 14) {
                GreetingPill()
                Text("What stayed with\nyou today?")
                    .font(.rounded(32, .black))
                    .multilineTextAlignment(.center)
                    .tracking(-0.6)
                Text("Your Figures are gathering to listen.")
                    .font(.rounded(14, .semibold))
                    .foregroundStyle(Ink.muted)
            }
            .frame(width: 390)
            .offset(y: 62)
            .appear()

            Button(action: vm.openTyping) {
                Text("or type it instead")
                    .font(.rounded(14, .bold))
                    .foregroundStyle(Ink.muted)
                    .underline(color: Ink.muted.opacity(0.4))
                    .padding(10)
            }
            .frame(width: 390)
            .offset(y: 630)
        }
    }
}

private struct GreetingPill: View {
    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                Circle().fill(Color(hex: 0xF5B93A))
                if greeting == "Good evening" {
                    Circle().fill(Color(hex: 0xF3EEF9))
                        .frame(width: 12, height: 12)
                        .offset(x: 4, y: -3)
                }
            }
            .frame(width: 12, height: 12)
            .clipShape(Circle())
            Text(greeting)
        }
        .font(.rounded(13, .heavy))
        .glassPill()
    }
}

// MARK: - Listening

private struct ListeningOverlay: View {
    @ObservedObject var vm: JournalViewModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 8) {
                PulsingDot()
                Text(vm.isInterpreting ? "Your Figures are thinking it over" : "Listening · \(vm.listeningClock)")
                    .monospacedDigit()
            }
            .font(.rounded(13, .heavy))
            .glassPill()
            .frame(width: 390)
            .offset(y: 62)
            .appear()

            transcript
                .frame(width: 330, height: 220, alignment: .bottom)
                .offset(x: 30, y: 112)

            if let error = vm.interpretError {
                VStack(spacing: 2) {
                    Text(error)
                    Text("Tap Done to try again").foregroundStyle(Ink.muted)
                }
                .font(.rounded(13, .bold))
                .foregroundStyle(Color(hex: 0xC9463A))
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.8)))
                .frame(width: 390)
                .offset(y: 636)
                .transition(.opacity)
            }

            Button(action: vm.finishListening) {
                HStack(spacing: 8) {
                    if vm.isInterpreting {
                        ProgressView().tint(.white).controlSize(.small)
                    }
                    Text(vm.isInterpreting ? "Thinking…" : "Done")
                }
                    .font(.rounded(15, .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 34)
                    .frame(height: 48)
                    .background(Capsule().fill(Ink.primary))
                    .shadow(color: Ink.primary.opacity(0.25), radius: 12, y: 10)
            }
            .buttonStyle(PressableStyle())
            .disabled(vm.isInterpreting)
            .opacity(vm.canFinishListening ? 1 : 0.4)
            .animation(.easeInOut(duration: 0.4), value: vm.canFinishListening)
            .frame(width: 390)
            .offset(y: 706)

            Button { vm.go(.home) } label: {
                Text("Cancel")
                    .font(.rounded(14, .bold))
                    .foregroundStyle(Ink.muted)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
            }
            .frame(width: 390)
            .offset(y: 762)
        }
    }

    private var transcript: some View {
        let lines = vm.transcriptLines
        return VStack(spacing: 8) {
            if lines.isEmpty {
                Text("Go ahead, I’m listening…")
                    .font(.rounded(18, .bold))
                    .foregroundStyle(Ink.label)
            }
            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                let age = lines.count - 1 - index
                Text(line.text)
                    .font(.rounded(age == 0 ? 21 : 18, .heavy))
                    .opacity([1, 0.45, 0.2][age])
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct PulsingDot: View {
    var body: some View {
        Ticker { t in
            Circle()
                .fill(Color(hex: 0xFF6F7D))
                .frame(width: 8, height: 8)
                .opacity(1 - 0.7 * wave(t, period: 1.2))
        }
        .frame(width: 8, height: 8)
    }
}

// MARK: - Chrome

private struct TabBar: View {
    @ObservedObject var vm: JournalViewModel

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            tab(.home, "Home") { color in
                RoundedRectangle(cornerRadius: 5).stroke(color, lineWidth: 2.5).frame(width: 14, height: 14)
            }
            Spacer(minLength: 0)
            tab(.figures, "Figures") { color in
                Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                    GridRow { Circle().fill(color).frame(width: 7, height: 7); Circle().fill(color).frame(width: 7, height: 7) }
                    GridRow { Circle().fill(color).frame(width: 7, height: 7); Circle().fill(color).frame(width: 7, height: 7) }
                }
            }
            Spacer(minLength: 0)
            tab(.memories, "Memories") { color in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 16, height: 5)
                    RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 16, height: 5)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(width: 342, height: 64)
        .background(
            Capsule()
                .fill(.white.opacity(0.7))
                .overlay(Capsule().stroke(.white.opacity(0.95), lineWidth: 1))
                .shadow(color: Ink.shadow.opacity(0.15), radius: 15, y: 10)
        )
    }

    private func tab<Icon: View>(_ screen: JournalViewModel.Screen, _ label: String,
                                 @ViewBuilder icon: (Color) -> Icon) -> some View {
        let on = vm.screen == screen
        let color = on ? Color.white : Ink.muted
        return Button { vm.go(screen) } label: {
            HStack(spacing: 8) {
                icon(color)
                Text(label)
            }
            .font(.rounded(13, .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, on ? 16 : 10)
            .frame(height: 46)
            .background(Capsule().fill(on ? Ink.primary : .clear))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.3), value: on)
    }
}

private struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.rounded(14, .heavy))
            .foregroundStyle(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(Capsule().fill(Ink.primary))
            .shadow(color: Ink.primary.opacity(0.3), radius: 12, y: 10)
    }
}

private struct TypeSheet: View {
    @ObservedObject var vm: JournalViewModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tell them in words")
                .font(.rounded(21, .black))

            ZStack(alignment: .topLeading) {
                TextEditor(text: $vm.typedText)
                    .focused($focused)
                    .scrollContentBackground(.hidden)
                    .font(.rounded(16, .semibold))
                    .padding(11)
                if vm.typedText.isEmpty {
                    Text("Something happened on the way home…")
                        .font(.rounded(16, .semibold))
                        .foregroundStyle(Ink.muted.opacity(0.7))
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 120)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 236 / 255, green: 230 / 255, blue: 248 / 255, opacity: 0.7)))
            .onChange(of: vm.typedText) { vm.typeError = nil }

            if let error = vm.typeError {
                Text(error)
                    .font(.rounded(13, .bold))
                    .foregroundStyle(Color(hex: 0xC9463A))
            }

            Button(action: vm.submitTyped) {
                HStack(spacing: 10) {
                    if vm.isInterpreting {
                        ProgressView().tint(.white)
                    }
                    Text(vm.isInterpreting ? "Your Figures are listening…" : "Share with my Figures")
                }
                    .font(.rounded(16, .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Capsule().fill(Ink.primary))
            }
            .buttonStyle(PressableStyle())
            .disabled(vm.isInterpreting)

            Spacer(minLength: 0)
        }
        .foregroundStyle(Ink.primary)
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .presentationDetents([.height(vm.typeError == nil ? 320 : 346)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(34)
        .presentationBackground(.white.opacity(0.92))
        .onAppear { focused = true }
    }
}

#Preview {
    JournalView()
}
