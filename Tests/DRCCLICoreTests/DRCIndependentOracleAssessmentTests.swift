import Foundation
import Testing
import DRCCore
import DRCNative
import DRCRuntime

@Suite("DRC independent oracle assessment")
struct DRCIndependentOracleAssessmentTests {
    @Test func independentlyAttestedReferenceBackendCanSatisfyAssessment() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let layoutURL = root.appending(path: "layout.json")
        let specURL = root.appending(path: "corpus.json")
        let outputDirectory = root.appending(path: "output")
        try """
        {
          "rectangles": [{"id":"thin","layer":"met1","xMin":0.0,"yMin":0.0,"xMax":0.1,"yMax":1.0}],
          "rules": [{"id":"met1.width","kind":"minimumWidth","layer":"met1","value":0.5}],
          "technologyID":"independent-oracle-test",
          "topCell":"inv",
          "unit":"micrometer"
        }
        """.write(to: layoutURL, atomically: true, encoding: .utf8)
        try writeJSON(DRCCorpusSpec(
            evidenceKind: .independentCorrelation,
            acceptanceCriteria: DRCCorpusAcceptanceCriteria(
                requireIndependentOracle: true,
                requiredCoverageTags: ["drc.width"]
            ),
            cases: [
                DRCCorpusCase(
                    caseID: "width",
                    layoutPath: layoutURL.lastPathComponent,
                    topCell: "inv",
                    backendID: "native",
                    oracleBackendID: "reference",
                    expectedPassed: false,
                    expectedActiveErrorRuleIDs: ["met1.width"],
                    coverageTags: ["drc.width"]
                ),
            ]
        ), to: specURL)

        let report = try await DRCCorpusRunner(engine: DefaultDRCEngine(backends: [
            NativeDRCBackend(),
            IndependentReferenceBackend(),
        ])).run(specURL: specURL, outputDirectory: outputDirectory)

        #expect(report.assessment.meetsCriteria)
        #expect(report.summary.oracleCaseCount == 1)
        #expect(report.summary.oracleAgreementPassedCaseCount == 1)
        #expect(report.summary.nonIndependentOracleCaseCount == 0)
        #expect(report.caseResults.first?.oracleComparison?.markerCorrelationRequired == true)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "DRCIndependentOracleAssessmentTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func removeTemporaryDirectory(_ directory: URL) {
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            Issue.record("Failed to remove temporary directory: \(error.localizedDescription)")
        }
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(value).write(to: url, options: [.atomic])
    }
}

private struct IndependentReferenceBackend: DRCBackend {
    let backendID = "reference"
    let identity = DRCBackendIdentity(
        backendID: "reference",
        implementationFamily: .magic,
        executableDigest: String(repeating: "1", count: 64),
        ruleProgramDigest: String(repeating: "2", count: 64),
        technologyDigest: String(repeating: "3", count: 64)
    )

    func run(_ request: DRCRequest) async throws -> DRCExecutionResult {
        let data = try Data(contentsOf: request.layoutURL)
        let layout = try JSONDecoder().decode(ReferenceLayout.self, from: data)
        let diagnostics = layout.rules.flatMap { rule in
            layout.rectangles.compactMap { rectangle -> DRCDiagnostic? in
                guard rule.kind == "minimumWidth",
                      rule.layer == rectangle.layer,
                      min(rectangle.xMax - rectangle.xMin, rectangle.yMax - rectangle.yMin) < rule.value else {
                    return nil
                }
                let measured = min(rectangle.xMax - rectangle.xMin, rectangle.yMax - rectangle.yMin)
                return DRCDiagnostic(
                    severity: .error,
                    message: "Reference width violation.",
                    ruleID: rule.id,
                    count: 1,
                    kind: "minimumWidth",
                    layer: rectangle.layer,
                    measured: measured,
                    required: rule.value,
                    unit: layout.unit,
                    region: DRCRegion(
                        x: rectangle.xMin,
                        y: rectangle.yMin,
                        width: rectangle.xMax - rectangle.xMin,
                        height: rectangle.yMax - rectangle.yMin
                    ),
                    relatedShapeIDs: [rectangle.id],
                    rawLine: "REFERENCE_MIN_WIDTH"
                )
            }
        }
        return DRCExecutionResult(
            request: request,
            result: DRCResult(
                backendID: backendID,
                backendIdentity: identity,
                toolName: "IndependentReference",
                success: true,
                completed: true,
                logPath: "",
                diagnostics: diagnostics
            )
        )
    }
}

private struct ReferenceLayout: Codable {
    let rectangles: [ReferenceRectangle]
    let rules: [ReferenceRule]
    let topCell: String
    let unit: String
}

private struct ReferenceRectangle: Codable {
    let id: String
    let layer: String
    let xMin: Double
    let yMin: Double
    let xMax: Double
    let yMax: Double
}

private struct ReferenceRule: Codable {
    let id: String
    let kind: String
    let layer: String
    let value: Double
}
