import SwiftUI

struct MemoriesScreen: View {
    @ObservedObject var vm: JournalViewModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            header("Memories", "What your Figures have been snacking on")
                .offset(x: 28, y: 62)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(vm.memories) { memory in
                        MemoryRow(memory: memory)
                    }
                }
                .padding(.bottom, 24)
            }
            .frame(width: 350, height: 600)
            .offset(x: 20, y: 146)
        }
        .appear()
    }
}

private struct MemoryRow: View {
    let memory: MemoryEntry

    private static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(spacing: 0) {
                Text(Self.weekday.string(from: memory.date))
                    .font(.rounded(11, .heavy))
                    .foregroundStyle(Ink.label)
                Text("\(Calendar.current.component(.day, from: memory.date))")
                    .font(.rounded(20, .black))
            }
            .frame(width: 52, height: 60)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.85)))

            VStack(alignment: .leading, spacing: 8) {
                Text(memory.text)
                    .font(.rounded(15, .heavy))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    ForEach(memory.figures) { kind in
                        FigureView(kind: kind, size: 24, still: true)
                    }
                    Text(memory.figures.map(\.displayName).joined(separator: " · "))
                        .font(.rounded(12, .bold))
                        .foregroundStyle(Ink.muted)
                        .padding(.leading, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if memory.isNew {
                Text("New")
                    .font(.rounded(11, .black))
                    .foregroundStyle(.white)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Capsule().fill(Ink.primary))
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.58))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.9), lineWidth: 1))
                .shadow(color: Ink.shadow.opacity(0.08), radius: 12, y: 8)
        )
    }
}
