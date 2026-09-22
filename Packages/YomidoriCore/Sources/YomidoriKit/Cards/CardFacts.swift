import SwiftUI
import YomidoriCore

/// When the card came and last changed, and how each question has gone.
struct CardFacts: View {
    let card: Card

    var body: some View {
        Section {
            LabeledContent {
                RankName(rank: card.rank)
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
                if card.state(for: question) != nil {
                    let good = card.answers(to: question, graded: .good)
                    let again = card.answers(to: question, graded: .again)
                    LabeledContent {
                        Text("\(good) good · \(again) again", bundle: .module)
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
