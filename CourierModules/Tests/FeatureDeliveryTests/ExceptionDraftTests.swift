import Domain
import Testing

@testable import FeatureDelivery

struct ExceptionDraftTests {
    @Test(arguments: [
        (ExceptionDraft.Choice.customerNoShow, ExceptionReason.customerNoShow),
        (.addressNotFound, .addressNotFound),
        (.packageDamaged, .packageDamaged),
    ])
    func predefinedChoiceProducesReasonWithoutDetails(choice: ExceptionDraft.Choice, expected: ExceptionReason) {
        let draft = ExceptionDraft(choice: choice, details: "ignored")

        #expect(draft.reason == expected)
    }

    @Test func otherWithoutDetailsHasNoReason() {
        #expect(ExceptionDraft(choice: .other, details: "").reason == nil)
        #expect(ExceptionDraft(choice: .other, details: "  \n ").reason == nil)
    }

    @Test func otherTrimsDetails() {
        let draft = ExceptionDraft(choice: .other, details: "  Gate locked \n")

        #expect(draft.reason == .other(details: "Gate locked"))
    }

    @Test func defaultsToFirstChoice() {
        #expect(ExceptionDraft().reason == .customerNoShow)
    }
}
