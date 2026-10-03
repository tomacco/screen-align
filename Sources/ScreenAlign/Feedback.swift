import AppKit

/// Sounds and trackpad taps that mark the moments that matter.
enum Feedback {
    static func lineConfirmed() {
        NSSound(named: "Pop")?.play()
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    static func lineMoved() {
        NSSound(named: "Tink")?.play()
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }

    static func celebrate() {
        NSSound(named: "Glass")?.play()
    }

    static func edgeChecked() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}
