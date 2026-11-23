import SwiftUI
import SwiftData

/// Новая запись: эмоция → опросник → чат. Открывается по «+» на главном экране.
struct NewCheckInFlow: View {
    enum Step {
        case emotion
        case questionnaire(CheckIn)
        case chat(CheckIn)
    }

    var onClose: () -> Void
    @State private var step: Step = .emotion

    var body: some View {
        NavigationStack {
            switch step {
            case .emotion:
                EmotionFlowView(
                    onDone: { checkIn in step = .questionnaire(checkIn) },
                    onCancel: onClose
                )
            case .questionnaire(let checkIn):
                QuestionnaireView(checkIn: checkIn, onClose: onClose) {
                    step = .chat(checkIn)
                }
            case .chat(let checkIn):
                ChatView(checkIn: checkIn, onClose: onClose)
            }
        }
        .preferredColorScheme(.dark)
    }
}
