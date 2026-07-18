import Testing
import DRCCore

@Suite("DRC corpus marker fingerprints")
struct DRCCorpusMarkerFingerprintTests {
    @Test func fingerprintIgnoresMessageAndRelatedIDOrdering() {
        let first = diagnostic(
            message: "first backend wording",
            relatedShapeIDs: ["shape-b", "shape-a"]
        )
        let second = diagnostic(
            message: "second backend wording",
            relatedShapeIDs: ["shape-a", "shape-b"]
        )

        #expect(
            DRCCorpusMarkerFingerprint(diagnostic: first)
                == DRCCorpusMarkerFingerprint(diagnostic: second)
        )
    }

    @Test func fingerprintChangesWhenRuleLayerOrRegionChanges() {
        let baseline = diagnostic(message: "baseline")
        let changed = DRCDiagnostic(
            severity: .error,
            message: "same message",
            ruleID: "min-width.other",
            kind: "spacing",
            layer: "M2",
            region: DRCRegion(x: 10, y: 20, width: 4, height: 6),
            relatedShapeIDs: ["shape-a"],
            rawLine: "raw"
        )

        #expect(
            DRCCorpusMarkerFingerprint(diagnostic: baseline)
                != DRCCorpusMarkerFingerprint(diagnostic: changed)
        )
    }

    @Test func fingerprintsAreSortedForStableArtifactEncoding() {
        let diagnostics = [
            diagnostic(message: "b", relatedShapeIDs: ["shape-b"]),
            diagnostic(message: "a", relatedShapeIDs: ["shape-a"])
        ]
        let fingerprints = DRCCorpusMarkerFingerprint.fingerprints(from: diagnostics)

        #expect(fingerprints == fingerprints.sorted())
    }

    @Test func comparisonUsesMarkerGateOnlyWhenEvidenceRequiresIt() {
        let summary = DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0)
        let comparison = DRCCorpusOracleComparison(
            primaryBackendID: "primary",
            oracleBackendID: "oracle",
            passedMatched: true,
            activeErrorRuleIDsMatched: true,
            ruleAssertionsMatched: true,
            diagnosticSummaryMatched: true,
            primaryPassed: true,
            oraclePassed: true,
            primaryActiveErrorRuleIDs: [],
            oracleActiveErrorRuleIDs: [],
            primaryDiagnosticSummary: summary,
            oracleDiagnosticSummary: summary,
            mismatchReasons: ["marker_set_mismatch"],
            primaryMarkerFingerprints: ["a"],
            oracleMarkerFingerprints: ["b"],
            markerCorrelationRequired: true
        )

        #expect(!comparison.agreementPassed)
        #expect(!comparison.markerSetMatched)
        #expect(comparison.markerCorrelationRequired)
    }

    private func diagnostic(message: String, relatedShapeIDs: [String] = ["shape-a"]) -> DRCDiagnostic {
        DRCDiagnostic(
            severity: .error,
            message: message,
            ruleID: "min-width",
            kind: "width",
            layer: "M1",
            region: DRCRegion(x: 10, y: 20, width: 4, height: 6),
            relatedShapeIDs: relatedShapeIDs,
            rawLine: "raw"
        )
    }
}
