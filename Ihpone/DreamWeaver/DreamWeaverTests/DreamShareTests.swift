import Foundation
import Testing
@testable import DreamWeaver

@Suite("Dream media sharing")
struct DreamShareTests {

    private func result(video: URL?, audio: URL?) -> DreamVideoResult {
        DreamVideoResult(
            headline: "Dream Film",
            soundtrackMood: "Symphonic",
            previewText: "preview",
            runtime: 42,
            scenes: [],
            videoURL: video,
            audioURL: audio,
            waveform: [],
            diagnostics: [:]
        )
    }

    private let film = URL(fileURLWithPath: "/tmp/dream-video.mp4")
    private let score = URL(fileURLWithPath: "/tmp/dream-score.caf")

    @Test("Film is offered before the score")
    func filmComesFirst() {
        let items = result(video: film, audio: score).shareableItems
        #expect(items == [film, score])
    }

    @Test("Only the score is shared when no film rendered")
    func scoreOnly() {
        #expect(result(video: nil, audio: score).shareableItems == [score])
    }

    @Test("Only the film is shared when no score rendered")
    func filmOnly() {
        #expect(result(video: film, audio: nil).shareableItems == [film])
    }

    @Test("Nothing to share when neither exists")
    func nothingToShare() {
        #expect(result(video: nil, audio: nil).shareableItems.isEmpty)
    }
}
