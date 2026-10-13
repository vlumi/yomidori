import SwiftUI
import YomidoriCore

/// When the card came and last changed, and how each question has gone: its rank, which
/// climbs on its own, and its answers.
struct CardFacts: View {
    let card: Card

    var body: some View {
        Section {
            LabeledContent {
                HStack(spacing: 6) {
                    RankMark(rank: card.rank)
                    RankName(rank: card.rank)
                }
            } label: {
                Text("Rank", bundle: .module)
            }
            LabeledContent {
                Text(card.created, format: .dateTime.year().month().day())
            } label: {
                Text("Added", bundle: .module)
            }
            LabeledContent {
                Text(card.modified, format: .dateTime.year().month().day())
            } label: {
                Text("Modified", bundle: .module)
            }
            ForEach(Question.allCases, id: \.self) { question in
                if card.state(for: question) != nil, question != .reading || card.asksReading {
                    let good = card.answers(to: question, graded: .good)
                    let again = card.answers(to: question, graded: .again)
                    LabeledContent {
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 6) {
                                RankMark(rank: card.rank(for: question), size: 22)
                                    .accessibilityLabel(
                                        RankName.text(for: card.rank(for: question)))
                                Text("\(good) good · \(again) again", bundle: .module)
                            }
                            // When the question comes back: now, or how far off.
                            if let due = card.state(for: question)?.due {
                                NextReview(due: due)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } label: {
                        QuestionName(question: question)
                    }
                }
            }
        }
        .font(.callout)
    }
}

struct QuestionName: View {
    let question: Question

    var body: some View {
        switch question {
        case .reading: Text("Reading", bundle: .module)
        case .meaning: Text("Meaning", bundle: .module)
        case .pitch: Text("Pitch", bundle: .module)
        }
    }
}

/// "Due now" once the date has come, else the time until it, as the clock counts it.
struct NextReview: View {
    let due: Date

    var body: some View {
        if due <= Date() {
            Text("Due now", bundle: .module)
        } else {
            Text("Next in \(due, style: .relative)", bundle: .module)
        }
    }
}
