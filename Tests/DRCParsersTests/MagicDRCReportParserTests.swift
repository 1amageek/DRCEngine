import Testing
import DRCCore
import DRCParsers

@Suite("Magic DRC report parser")
struct MagicDRCReportParserTests {
    @Test func cleanCompletedReportPasses() {
        let report = MagicDRCReportParser().parse(
            logPath: "/tmp/drc.log",
            rawOutput: """
            DRC_SUMMARY total=0 cell=inv
            DRC_DONE
            """,
            success: true
        )

        #expect(report.passed)
        #expect(report.completed)
        #expect(report.diagnostics.isEmpty)
    }

    @Test func violationReportFailsWithRule() {
        let report = MagicDRCReportParser().parse(
            logPath: "/tmp/drc.log",
            rawOutput: """
            DRC_SUMMARY total=1 cell=inv
            VIOLATION rule=met1.2 count=1 message="Metal1 spacing < 0.14um"
            DRC_DONE
            """,
            success: true
        )

        #expect(!report.passed)
        #expect(report.diagnostics.count == 1)
        #expect(report.diagnostics[0].ruleID == "met1.2")
        #expect(report.diagnostics[0].count == 1)
    }

    @Test func summaryCountMismatchCannotPass() {
        let report = MagicDRCReportParser().parse(
            logPath: "/tmp/drc.log",
            rawOutput: """
            DRC_SUMMARY total=3 cell=inv
            VIOLATION rule=met1.2 count=1 message="Metal1 spacing"
            DRC_DONE
            """,
            success: true
        )

        #expect(!report.passed)
        #expect(report.diagnostics.contains { $0.ruleID == "DRC_SUMMARY_MISMATCH" })
    }

    @Test func completionMarkerMustBeExactLine() {
        let report = MagicDRCReportParser().parse(
            logPath: "/tmp/drc.log",
            rawOutput: """
            DRC_SUMMARY total=0 cell=inv
            ERROR rule=TEXT message="DRC_DONE"
            """,
            success: true
        )

        #expect(!report.completed)
        #expect(!report.passed)
    }

    @Test func escapedMessageFieldsAreDecoded() {
        let report = MagicDRCReportParser().parse(
            logPath: "/tmp/drc.log",
            rawOutput: #"""
            DRC_SUMMARY total=1 cell=inv
            VIOLATION rule=met1.2 count=1 message="Metal \"one\", spacing\nfailed"
            DRC_DONE
            """#,
            success: true
        )

        #expect(!report.passed)
        #expect(report.diagnostics[0].message == "Metal \"one\", spacing\nfailed")
    }

    @Test func missingCompletionMarkerCannotPass() {
        let report = MagicDRCReportParser().parse(
            logPath: "/tmp/drc.log",
            rawOutput: "DRC_SUMMARY total=0 cell=inv",
            success: true
        )

        #expect(!report.passed)
        #expect(!report.completed)
    }

    @Test func completedReportWithoutSummaryCannotPass() {
        let report = MagicDRCReportParser().parse(
            logPath: "/tmp/drc.log",
            rawOutput: "DRC_DONE",
            success: true
        )

        #expect(!report.passed)
        #expect(report.completed)
        #expect(report.diagnostics.count == 1)
        #expect(report.diagnostics[0].ruleID == "DRC_SUMMARY_MISSING")
    }

    @Test func completedReportWithInvalidSummaryCannotPass() {
        let report = MagicDRCReportParser().parse(
            logPath: "/tmp/drc.log",
            rawOutput: """
            DRC_SUMMARY total=unknown cell=inv
            DRC_DONE
            """,
            success: true
        )

        #expect(!report.passed)
        #expect(report.completed)
        #expect(report.diagnostics.count == 1)
        #expect(report.diagnostics[0].ruleID == "DRC_SUMMARY_INVALID")
    }
}
