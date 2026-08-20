import Foundation
import Testing
@testable import DreamWeaver

@Suite("Dream dashboard empty state")
struct DreamDashboardModelTests {

    @Test("Empty history shows the empty state")
    func emptyShowsState() {
        #expect(DreamDashboardModel.showsEmptyState(history: []))
    }

    @Test("Any history hides the empty state")
    func historyHidesState() {
        let dream = DreamFixture.dream(mood: .calm)
        #expect(!DreamDashboardModel.showsEmptyState(history: [dream]))
    }
}
