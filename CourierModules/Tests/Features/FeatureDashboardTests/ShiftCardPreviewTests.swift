import Domain
import DomainTestSupport
import SwiftUI
import Testing
import UIKit

@testable import FeatureDashboard

struct ShiftCardPreviewTests {
    @Test(arguments: [ShiftStatus.scheduled, .active, .finished])
    func previewDisplaysCardOnFirstRender(status: ShiftStatus) throws {
        let renderer = ImageRenderer(content: ShiftCardPreview(.fixture(status: status)))
        renderer.proposedSize = ProposedViewSize(width: 390, height: nil)

        let image = try #require(renderer.uiImage)

        #expect(image.size.height > 100)
    }
}
