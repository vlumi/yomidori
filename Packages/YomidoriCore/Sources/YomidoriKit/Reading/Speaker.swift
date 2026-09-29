import AVFoundation
import SwiftUI

/// A sentence read aloud by the system's own Japanese voice, on the device: the best one
/// installed (the enhanced and premium voices are downloads in the Settings app). Its pitch
/// is fair, not always right. One sentence at a time; a second press stops it.
@MainActor
final class Speaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()

    /// The text being spoken, for its button to show as a stop.
    @Published private(set) var speaking: String?
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func toggle(_ text: String) {
        if speaking == text {
            synthesizer.stopSpeaking(at: .immediate)
        } else {
            speak(text)
        }
    }

    private func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        #if os(iOS)
        // Asked for by a press, so heard with the ring switch off too, over whatever plays.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        #endif
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice
        // A little under the usual pace, for a learner's ear.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        speaking = text
        synthesizer.speak(utterance)
    }

    /// The best Japanese voice installed.
    private static var voice: AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "ja-JP" }
            .max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: "ja-JP")
    }

    private func finished(_ text: String) {
        guard speaking == text else { return }
        speaking = nil
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance
    ) {
        let text = utterance.speechString
        Task { @MainActor in self.finished(text) }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance
    ) {
        let text = utterance.speechString
        Task { @MainActor in self.finished(text) }
    }
}

/// Reads a sentence aloud, or stops reading it.
struct SpeakButton: View {
    let text: String
    @ObservedObject private var speaker = Speaker.shared

    var body: some View {
        Button {
            speaker.toggle(text)
        } label: {
            Label {
                if speaker.speaking == text {
                    Text("Stop", bundle: .module)
                } else {
                    Text("Hear the sentence", bundle: .module)
                }
            } icon: {
                Image(systemName: speaker.speaking == text ? "stop.fill" : "speaker.wave.2")
            }
        }
    }
}
