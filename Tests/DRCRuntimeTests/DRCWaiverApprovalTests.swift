import Testing
import DRCCore

@Suite("DRC waiver boundary")
struct DRCWaiverBoundaryTests {
    @Test func waiverCarriesMatchingEvidenceOnly() {
        let waiver = DRCWaiver(
            id: "width-exception",
            reason: "Reviewed process exception",
            ruleID: "met1.width"
        )

        #expect(waiver.validationIssues().isEmpty)
    }

    @Test func invalidWaiverProducesStructuredIssue() {
        let waiver = DRCWaiver(
            id: "",
            reason: "",
            ruleID: "met1.width"
        )

        #expect(!waiver.validationIssues().isEmpty)
    }
}
