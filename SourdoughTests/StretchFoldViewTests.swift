import Foundation
import SourdoughKit
import Testing
@testable import Sourdough

@Suite("StretchFoldView")
struct StretchFoldViewTests {
    @Test func theStagesHaveTheirGermanNames() {
        #expect(StretchFoldView.stageName(.grab) == "Greifen")
        #expect(StretchFoldView.stageName(.stretch) == "Dehnen")
        #expect(StretchFoldView.stageName(.fold) == "Falten")
        #expect(StretchFoldView.stageName(.turn) == "Drehen")
    }

    @Test func theClockRunsUnlessMotionIsReduced() {
        let date = Date(timeIntervalSinceReferenceDate: 123.5)
        #expect(StretchFoldView.seconds(reduceMotion: false, date: date) == 123.5)
        #expect(StretchFoldView.seconds(reduceMotion: true, date: date) == StretchFold.stillSeconds)
    }
}
