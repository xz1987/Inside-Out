import SwiftUI

struct DailyEventView: View {
    @StateObject private var viewModel = DailyEventViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    intro

                    if let analysis = viewModel.analysis {
                        AnalysisResultView(analysis: analysis) {
                            viewModel.startOver()
                        }
                    } else {
                        inputCard
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Inside Out")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Talk about a daily event")
                .font(.title2.bold())
            Text("What happened, and what part of it stays with you now?")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextEditor(text: $viewModel.eventText)
                .frame(minHeight: 180)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(alignment: .topLeading) {
                    if viewModel.eventText.isEmpty {
                        Text("For example: I shared an idea in class today, but someone interrupted me before I could finish…")
                            .foregroundStyle(.tertiary)
                            .padding(18)
                            .allowsHitTesting(false)
                    }
                }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await viewModel.interpretEvent() }
            } label: {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(viewModel.isLoading ? "The figures are listening…" : "Let the figures listen")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSubmit)

            Text("MVP: interpretation currently uses a local fallback until the two server API keys are configured.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AnalysisResultView: View {
    let analysis: EventAnalysis
    let startOver: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Label("What the figures heard", systemImage: "quote.bubble.fill")
                    .font(.headline)
                Text(analysis.summary)
                    .font(.body)
                Text(analysis.interpretationMode)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .cardStyle()

            VStack(alignment: .leading, spacing: 14) {
                Text("Who gets fed")
                    .font(.headline)

                ForEach(analysis.feeds) { feed in
                    FigureFeedRow(feed: feed)
                }
            }
            .cardStyle()

            RelationshipCard(promotion: analysis.promotedRelationship)

            Button("Talk about another event", action: startOver)
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct FigureFeedRow: View {
    let feed: FigureFeed

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: feed.figure.symbolName)
                .font(.title2)
                .frame(width: 40, height: 40)
                .foregroundStyle(color(for: feed.figure))
                .background(color(for: feed.figure).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(feed.figure.displayName)
                        .font(.headline)
                    Spacer()
                    Text("+\(feed.feedAmount) Feed")
                        .font(.subheadline.bold())
                }

                ProgressView(value: feed.concentration)
                    .tint(color(for: feed.figure))

                Text("\(Int(feed.concentration * 100))% concentration")
                    .font(.caption.bold())
                Text(feed.evidence)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func color(for figure: FigureKind) -> Color {
        switch figure {
        case .sadness: .blue
        case .joy: .yellow
        case .anger: .red
        case .fear: .purple
        }
    }
}

private struct RelationshipCard: View {
    let promotion: RelationshipPromotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Relationship promoted")
                .font(.headline)

            HStack {
                Label(promotion.firstFigure.displayName, systemImage: promotion.firstFigure.symbolName)
                Spacer()
                Text("+\(promotion.points)")
                    .font(.title3.bold())
                    .foregroundStyle(.green)
                Spacer()
                Label(promotion.secondFigure.displayName, systemImage: promotion.secondFigure.symbolName)
                    .labelStyle(.titleAndIcon)
            }

            Text(promotion.reason)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }
}

private extension View {
    func cardStyle() -> some View {
        padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    DailyEventView()
}

