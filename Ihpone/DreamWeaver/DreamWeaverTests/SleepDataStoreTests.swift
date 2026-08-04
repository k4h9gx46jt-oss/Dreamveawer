import Foundation
import Testing
@testable import DreamWeaver

// Tests run against a temp directory so they never touch real app storage.
@MainActor
@Suite("SleepDataStore persistence")
struct SleepDataStoreTests {

    // MARK: - Helpers

    private func makeStore() -> (SleepDataStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "SleepDataStoreTests/\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (SleepDataStore(_testingStorageDirectory: dir), dir)
    }

    private func addDream(mood: DreamMood = .peaceful, to store: SleepDataStore) {
        let fixture = DreamFixture.dream(mood: mood)
        let ai = SleepAIResult(
            narrative: "test", themes: ["a"], symbolism: ["⭐"],
            intensity: 0.5, consciousness: 0.3, visualPrompt: "p",
            mood: mood, remEstimate: 22, deepSleepEstimate: 25
        )
        var session = SleepSession(startedAt: fixture.startedAt,
                                   biosignals: fixture.biosignals,
                                   remProfile: fixture.remProfile)
        session.finish(on: fixture.endedAt)
        store.addDream(from: session, aiResult: ai)
    }

    // MARK: - Fresh install

    @Test("Fresh install starts with an empty dream list")
    func freshInstallIsEmpty() {
        let (store, _) = makeStore()
        #expect(store.dreams.isEmpty)
    }

    // MARK: - Persistence round-trip

    @Test("A saved dream survives a store reload")
    func dreamSurvivesReload() {
        let (store, dir) = makeStore()
        addDream(mood: .ethereal, to: store)
        let savedId = store.dreams[0].id

        let reloaded = SleepDataStore(_testingStorageDirectory: dir)
        #expect(reloaded.dreams.count == 1)
        #expect(reloaded.dreams[0].id == savedId)
        #expect(reloaded.dreams[0].mood == .ethereal)
    }

    @Test("Multiple dreams are persisted and reload in insertion order")
    func multiplesDreamsPreserveOrder() {
        let (store, dir) = makeStore()
        addDream(mood: .peaceful, to: store)
        addDream(mood: .intense,  to: store)
        addDream(mood: .chaotic,  to: store)

        // addDream inserts at index 0, so the last-inserted appears first
        let reloaded = SleepDataStore(_testingStorageDirectory: dir)
        #expect(reloaded.dreams.count == 3)
        #expect(reloaded.dreams[0].mood == .chaotic)
        #expect(reloaded.dreams[2].mood == .peaceful)
    }

    @Test("Narrative and themes survive the JSON round-trip")
    func narrativeAndThemesSurviveRoundTrip() {
        let (store, dir) = makeStore()
        addDream(mood: .ethereal, to: store)

        let reloaded = SleepDataStore(_testingStorageDirectory: dir)
        #expect(!reloaded.dreams[0].aiNarrative.isEmpty)
        #expect(!reloaded.dreams[0].aiThemes.isEmpty)
    }

    // MARK: - Delete

    @Test("Deleting a dream removes it from disk")
    func deleteRemovesFromDisk() {
        let (store, dir) = makeStore()
        addDream(to: store)
        store.deleteDream(id: store.dreams[0].id)

        let reloaded = SleepDataStore(_testingStorageDirectory: dir)
        #expect(reloaded.dreams.isEmpty)
    }

    @Test("Deleting updates the in-memory list immediately")
    func deleteUpdatesInMemoryList() {
        let (store, _) = makeStore()
        addDream(mood: .peaceful, to: store)
        addDream(mood: .calm,     to: store)
        let idToDelete = store.dreams[1].id
        store.deleteDream(id: idToDelete)
        #expect(store.dreams.count == 1)
        #expect(!store.dreams.contains { $0.id == idToDelete })
    }

    @Test("Deleting an unknown id is a no-op")
    func deleteUnknownIdIsNoOp() {
        let (store, _) = makeStore()
        store.deleteDream(id: UUID())
        #expect(store.dreams.isEmpty)
    }

    // MARK: - Corruption safety

    @Test("Corrupted storage file loads as an empty list")
    func corruptedFileLoadsEmpty() throws {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "SleepDataStoreTests/corrupt-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "not json {{".write(to: dir.appending(path: "dreams.json"),
                                atomically: true, encoding: .utf8)
        let store = SleepDataStore(_testingStorageDirectory: dir)
        #expect(store.dreams.isEmpty)
    }
}
