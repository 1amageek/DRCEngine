import Foundation
import Testing
import DRCCore

@Suite("DRC waiver approval")
struct DRCWaiverApprovalTests {
    @Test func approvalMetadataMustBeValidAndActive() {
        let approval = DRCWaiverApproval(
            approvedBy: "reviewer",
            approvedAt: "2026-01-01T00:00:00Z",
            expiresAt: "2030-01-01T00:00:00Z",
            reference: "ticket-123"
        )
        let waiver = DRCWaiver(
            id: "approved-width",
            reason: "Reviewed process exception",
            ruleID: "met1.width",
            approval: approval
        )

        #expect(waiver.validationIssues().isEmpty)
        #expect(approval.isActive(at: date("2027-01-01T00:00:00Z")))
        #expect(!approval.isActive(at: date("2031-01-01T00:00:00Z")))
    }

    @Test func invalidApprovalMetadataProducesStructuredIssue() {
        let waiver = DRCWaiver(
            id: "invalid-approval",
            reason: "Needs review",
            ruleID: "met1.width",
            approval: DRCWaiverApproval(
                approvedBy: "",
                approvedAt: "not-a-date",
                reference: ""
            )
        )

        #expect(waiver.validationIssues().contains { $0.code == "drc_waiver_approval_invalid" })
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value) ?? Date.distantPast
    }
}
