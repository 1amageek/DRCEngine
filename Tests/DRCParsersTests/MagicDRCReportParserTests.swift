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

    @Test func violationRuleExpressionUsesPrimaryRuleID() {
        let report = MagicDRCReportParser().parse(
            logPath: "/tmp/drc.log",
            rawOutput: """
            DRC_SUMMARY total=1 cell=inv
            VIOLATION rule="via.5a - via.4a" count=1 message="Metal1 overlap of Via1 < 0.03um"
            DRC_DONE
            """,
            success: true
        )

        #expect(!report.passed)
        #expect(report.diagnostics.count == 1)
        #expect(report.diagnostics[0].ruleID == "via.5a")
        #expect(report.diagnostics[0].message == "Metal1 overlap of Via1 < 0.03um")
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

    @Test func magicFindFallbackRuleOutputIsStructured() {
        let report = MagicDRCReportParser().parse(
            logPath: "/tmp/drc.log",
            rawOutput: """
            DRC_SUMMARY total=1 cell=inv
            DRC_FIND_BEGIN
            Error area #1:
            Metal1 width < 0.14um (met1.1)
            DRC_FIND_END
            DRC_DONE
            """,
            success: true
        )

        #expect(!report.passed)
        #expect(report.diagnostics.count == 1)
        #expect(report.diagnostics[0].ruleID == "met1.1")
        #expect(report.diagnostics[0].message == "Metal1 width < 0.14um (met1.1)")
    }

    @Test func magicFindFallbackRuleExpressionIsStructured() {
        let report = MagicDRCReportParser().parse(
            logPath: "/tmp/drc.log",
            rawOutput: """
            DRC_SUMMARY total=1 cell=inv
            DRC_FIND_BEGIN
            Error area #1:
            Metal2 overlap of Via1 < 0.03um in one direction (met2.5 - met2.4)
            DRC_FIND_END
            DRC_DONE
            """,
            success: true
        )

        #expect(!report.passed)
        #expect(report.diagnostics.count == 1)
        #expect(report.diagnostics[0].ruleID == "met2.5")
        #expect(report.diagnostics[0].message == "Metal2 overlap of Via1 < 0.03um in one direction (met2.5 - met2.4)")
    }

    @Test func summaryCountsEnumeratedRuleBuckets() {
        let report = MagicDRCReportParser().parse(
            logPath: "/tmp/drc.log",
            rawOutput: """
            DRC_SUMMARY total=3 cell=inv
            VIOLATION rule=nwell.4 count=1 message="All nwells must contain metal-connected N+ taps (nwell.4)"
            VIOLATION rule=LU.3 count=2 message="P-diff distance to N-tap must be < 15.0um (LU.3)"
            VIOLATION rule=LU.2 count=2 message="N-diff distance to P-tap must be < 15.0um (LU.2)"
            DRC_DONE
            """,
            success: true
        )

        #expect(!report.passed)
        #expect(report.diagnostics.compactMap { $0.ruleID }.sorted() == ["LU.2", "LU.3", "nwell.4"])
        #expect(!report.diagnostics.contains { $0.ruleID == "DRC_SUMMARY_MISMATCH" })
    }

    @Test func summaryCanMatchEnumeratedInstanceCount() {
        let report = MagicDRCReportParser().parse(
            logPath: "/tmp/drc.log",
            rawOutput: """
            DRC_SUMMARY total=2 cell=inv
            VIOLATION rule=met1.2 count=2 message="Metal1 spacing < 0.14um (met1.2)"
            DRC_DONE
            """,
            success: true
        )

        #expect(!report.passed)
        #expect(report.diagnostics.count == 1)
        #expect(report.diagnostics[0].ruleID == "met1.2")
        #expect(report.diagnostics[0].count == 2)
        #expect(!report.diagnostics.contains { $0.ruleID == "DRC_SUMMARY_MISMATCH" })
    }

    @Test func summaryCanMatchMagicEnumeratedRange() {
        let report = MagicDRCReportParser().parse(
            logPath: "/tmp/drc.log",
            rawOutput: """
            DRC_SUMMARY total=3 cell=via2
            VIOLATION rule=met3.4 count=5 message="Metal3 overlap of via2 < 0.025um (met3.4)"
            DRC_DONE
            """,
            success: true
        )

        #expect(!report.passed)
        #expect(report.diagnostics.count == 1)
        #expect(report.diagnostics[0].ruleID == "met3.4")
        #expect(report.diagnostics[0].count == 5)
        #expect(!report.diagnostics.contains { $0.ruleID == "DRC_SUMMARY_MISMATCH" })
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
