import Foundation
import DRCCore
import LayoutCore
import LayoutIO
import LayoutTech

public struct DRCCorpusRunner: Sendable {
    private let engine: DefaultDRCEngine

    public init(engine: DefaultDRCEngine = DefaultDRCEngine()) {
        self.engine = engine
    }

    public func run(
        specURL: URL,
        outputDirectory: URL,
        options: DRCCorpusRunOptions = DRCCorpusRunOptions()
    ) async throws -> DRCCorpusReport {
        let spec = try loadSpec(from: specURL)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        try validateBudget(spec.defaultMaxDurationSeconds, label: "defaultMaxDurationSeconds")

        let caseResults = try await runCases(
            spec: spec,
            specDirectory: specURL.deletingLastPathComponent(),
            outputDirectory: outputDirectory,
            options: options
        )
        let report = makeReport(
            caseResults: caseResults,
            options: options,
            qualificationPolicy: spec.qualificationPolicy
        )
        try writeReport(report, to: outputDirectory)
        return report
    }

    private func loadSpec(from specURL: URL) throws -> DRCCorpusSpec {
        let data: Data
        do {
            data = try Data(contentsOf: specURL)
        } catch {
            throw DRCError.invalidInput("Could not read DRC corpus spec: \(error.localizedDescription)")
        }
        let spec: DRCCorpusSpec
        do {
            spec = try JSONDecoder().decode(DRCCorpusSpec.self, from: data)
        } catch {
            throw DRCError.invalidInput("Could not decode DRC corpus spec: \(error.localizedDescription)")
        }
        return spec
    }

    private func runCases(
        spec: DRCCorpusSpec,
        specDirectory: URL,
        outputDirectory: URL,
        options: DRCCorpusRunOptions
    ) async throws -> [DRCCorpusCaseResult] {
        var caseResults: [DRCCorpusCaseResult] = []

        for corpusCase in spec.cases {
            caseResults.append(try await runCase(
                corpusCase,
                defaultMaxDurationSeconds: spec.defaultMaxDurationSeconds,
                specDirectory: specDirectory,
                outputDirectory: outputDirectory,
                options: options
            ))
        }
        return caseResults
    }

    private func runCase(
        _ corpusCase: DRCCorpusCase,
        defaultMaxDurationSeconds: Double?,
        specDirectory: URL,
        outputDirectory: URL,
        options: DRCCorpusRunOptions
    ) async throws -> DRCCorpusCaseResult {
        try validateBudget(corpusCase.maxDurationSeconds, label: "\(corpusCase.caseID).maxDurationSeconds")
        let maxDurationSeconds = corpusCase.maxDurationSeconds ?? defaultMaxDurationSeconds
        let caseDirectory = try createCaseDirectory(for: corpusCase, outputDirectory: outputDirectory)
        let startedAt = Date()

        let preparedInputs: PreparedDRCCorpusInputs
        do {
            preparedInputs = try prepareInputs(
                for: corpusCase,
                specDirectory: specDirectory,
                caseDirectory: caseDirectory
            )
        } catch {
            return failedCaseResult(
                corpusCase: corpusCase,
                expectedMaxDurationSeconds: maxDurationSeconds,
                durationSeconds: Date().timeIntervalSince(startedAt),
                error: error
            )
        }

        let executionResult: DRCExecutionResult
        do {
            executionResult = try await engine.run(primaryRequest(
                for: corpusCase,
                preparedInputs: preparedInputs,
                specDirectory: specDirectory,
                caseDirectory: caseDirectory
            ))
        } catch {
            return failedCaseResult(
                corpusCase: corpusCase,
                expectedMaxDurationSeconds: maxDurationSeconds,
                durationSeconds: Date().timeIntervalSince(startedAt),
                error: error
            )
        }

        return await successfulCaseResult(
            corpusCase: corpusCase,
            executionResult: executionResult,
            preparedInputs: preparedInputs,
            specDirectory: specDirectory,
            caseDirectory: caseDirectory,
            startedAt: startedAt,
            maxDurationSeconds: maxDurationSeconds,
            options: options
        )
    }

    private func createCaseDirectory(for corpusCase: DRCCorpusCase, outputDirectory: URL) throws -> URL {
        let caseDirectory = outputDirectory
            .appending(path: "cases")
            .appending(path: safePathComponent(corpusCase.caseID))
        try FileManager.default.createDirectory(at: caseDirectory, withIntermediateDirectories: true)
        return caseDirectory
    }

    private func prepareInputs(
        for corpusCase: DRCCorpusCase,
        specDirectory: URL,
        caseDirectory: URL
    ) throws -> PreparedDRCCorpusInputs {
        try DRCCorpusGeneratedInputFactory().prepareInputs(
            for: corpusCase,
            specDirectory: specDirectory,
            caseDirectory: caseDirectory
        )
    }

    private func primaryRequest(
        for corpusCase: DRCCorpusCase,
        preparedInputs: PreparedDRCCorpusInputs,
        specDirectory: URL,
        caseDirectory: URL
    ) -> DRCRequest {
        DRCRequest(
            layoutURL: preparedInputs.layoutURL,
            topCell: corpusCase.topCell,
            layoutFormat: preparedInputs.layoutFormat,
            technologyURL: preparedInputs.technologyURL,
            waiverURL: corpusCase.waiverPath.map { resolve($0, relativeTo: specDirectory) },
            workingDirectory: caseDirectory,
            backendSelection: DRCBackendSelection(backendID: corpusCase.backendID ?? "native"),
            options: DRCOptions(additionalEnvironment: corpusCase.additionalEnvironment)
        )
    }

    private func successfulCaseResult(
        corpusCase: DRCCorpusCase,
        executionResult: DRCExecutionResult,
        preparedInputs: PreparedDRCCorpusInputs,
        specDirectory: URL,
        caseDirectory: URL,
        startedAt: Date,
        maxDurationSeconds: Double?,
        options: DRCCorpusRunOptions
    ) async -> DRCCorpusCaseResult {
        let durationSeconds = Date().timeIntervalSince(startedAt)
        let actualRuleIDs = activeErrorRuleIDs(in: executionResult.result.diagnostics)
        let primaryDiagnosticSummary = diagnosticSummary(executionResult.result.diagnostics)
        let expectedRuleIDs = corpusCase.expectedActiveErrorRuleIDs.sorted()
        let expectationMatched = executionResult.result.passed == corpusCase.expectedPassed
            && actualRuleIDs == expectedRuleIDs
        let durationBudgetPassed = maxDurationSeconds.map { durationSeconds <= $0 } ?? true
        let oracleResult = await runOracleIfNeeded(
            corpusCase: corpusCase,
            oracleBackendID: options.oracleBackendIDOverride ?? corpusCase.oracleBackendID,
            specDirectory: specDirectory,
            caseDirectory: caseDirectory,
            preparedInputs: preparedInputs,
            primaryPassed: executionResult.result.passed,
            primaryBackendID: executionResult.result.backendID,
            primaryActiveRuleIDs: actualRuleIDs,
            primaryDiagnosticSummary: primaryDiagnosticSummary
        )
        return buildCaseResult(
            corpusCase: corpusCase,
            executionResult: executionResult,
            expectedRuleIDs: expectedRuleIDs,
            actualRuleIDs: actualRuleIDs,
            primaryDiagnosticSummary: primaryDiagnosticSummary,
            expectationMatched: expectationMatched,
            durationSeconds: durationSeconds,
            maxDurationSeconds: maxDurationSeconds,
            durationBudgetPassed: durationBudgetPassed,
            oracleResult: oracleResult
        )
    }

    private func buildCaseResult(
        corpusCase: DRCCorpusCase,
        executionResult: DRCExecutionResult,
        expectedRuleIDs: [String],
        actualRuleIDs: [String],
        primaryDiagnosticSummary: DRCDiagnosticSummary,
        expectationMatched: Bool,
        durationSeconds: Double,
        maxDurationSeconds: Double?,
        durationBudgetPassed: Bool,
        oracleResult: DRCCorpusOracleResult?
    ) -> DRCCorpusCaseResult {
        let oracleComparison = oracleResult.map {
            self.oracleComparison(
                primaryBackendID: executionResult.result.backendID,
                primaryPassed: executionResult.result.passed,
                primaryActiveRuleIDs: actualRuleIDs,
                primaryDiagnosticSummary: primaryDiagnosticSummary,
                oracleResult: $0
            )
        }
        let oracleAgreementPassed = oracleResult?.agreementPassed ?? true
        return DRCCorpusCaseResult(
            caseID: corpusCase.caseID,
            matched: expectationMatched && durationBudgetPassed && oracleAgreementPassed,
            expectedPassed: corpusCase.expectedPassed,
            actualPassed: executionResult.result.passed,
            expectedActiveErrorRuleIDs: expectedRuleIDs,
            actualActiveErrorRuleIDs: actualRuleIDs,
            coverageTags: corpusCase.coverageTags,
            expectationMatched: expectationMatched,
            durationSeconds: durationSeconds,
            expectedMaxDurationSeconds: maxDurationSeconds,
            durationBudgetPassed: durationBudgetPassed,
            failureReasons: failureReasons(
                expectationMatched: expectationMatched,
                durationBudgetPassed: durationBudgetPassed,
                oracleAgreementPassed: oracleAgreementPassed,
                oracleFailureReasons: oracleComparison?.mismatchReasons ?? oracleResult?.failureReasons ?? [],
                durationSeconds: durationSeconds,
                maxDurationSeconds: maxDurationSeconds
            ),
            diagnosticSummary: primaryDiagnosticSummary,
            reportPath: executionResult.reportURL?.path(percentEncoded: false),
            manifestPath: executionResult.artifactManifestURL?.path(percentEncoded: false),
            primaryProvenance: provenance(for: executionResult),
            oracleResult: oracleResult,
            oracleComparison: oracleComparison
        )
    }

    private func makeReport(
        caseResults: [DRCCorpusCaseResult],
        options: DRCCorpusRunOptions,
        qualificationPolicy: DRCCorpusQualificationPolicy
    ) -> DRCCorpusReport {
        DRCCorpusReport(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            passed: caseResults.allSatisfy(\.matched),
            caseCount: caseResults.count,
            matchedCaseCount: caseResults.filter(\.matched).count,
            budgetExceededCaseCount: caseResults.filter { !$0.durationBudgetPassed }.count,
            totalDurationSeconds: caseResults.reduce(0) { $0 + $1.durationSeconds },
            runOptions: options,
            qualificationPolicy: qualificationPolicy,
            caseResults: caseResults
        )
    }

    private func writeReport(_ report: DRCCorpusReport, to outputDirectory: URL) throws {
        let reportURL = outputDirectory.appending(path: "drc-corpus-report.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let reportData = try encoder.encode(report)
        try reportData.write(to: reportURL, options: [.atomic])
    }

    private func validateBudget(_ value: Double?, label: String) throws {
        guard let value else { return }
        guard value.isFinite, value > 0 else {
            throw DRCError.invalidInput("\(label) must be positive finite seconds")
        }
    }

    private func failureReasons(
        expectationMatched: Bool,
        durationBudgetPassed: Bool,
        oracleAgreementPassed: Bool,
        oracleFailureReasons: [String],
        durationSeconds: Double,
        maxDurationSeconds: Double?
    ) -> [String] {
        var reasons: [String] = []
        if !expectationMatched {
            reasons.append("expectation_mismatch")
        }
        if !durationBudgetPassed, let maxDurationSeconds {
            reasons.append("duration_exceeded:\(durationSeconds)>\(maxDurationSeconds)")
        }
        if !oracleAgreementPassed && !oracleFailureReasons.contains("oracle_agreement_mismatch") {
            reasons.append("oracle_agreement_mismatch")
        }
        for reason in oracleFailureReasons where !reasons.contains(reason) {
            reasons.append(reason)
        }
        return reasons
    }

    private func failedCaseResult(
        corpusCase: DRCCorpusCase,
        expectedMaxDurationSeconds: Double?,
        durationSeconds: Double,
        error: any Error
    ) -> DRCCorpusCaseResult {
        let message = executionErrorMessage(error)
        let durationBudgetPassed = expectedMaxDurationSeconds.map { durationSeconds <= $0 } ?? true
        var failureReasons = ["primary_execution_failed:\(message)"]
        if !durationBudgetPassed, let expectedMaxDurationSeconds {
            failureReasons.append("duration_exceeded:\(durationSeconds)>\(expectedMaxDurationSeconds)")
        }
        return DRCCorpusCaseResult(
            caseID: corpusCase.caseID,
            matched: false,
            expectedPassed: corpusCase.expectedPassed,
            actualPassed: false,
            expectedActiveErrorRuleIDs: corpusCase.expectedActiveErrorRuleIDs.sorted(),
            actualActiveErrorRuleIDs: [],
            coverageTags: corpusCase.coverageTags,
            expectationMatched: false,
            durationSeconds: durationSeconds,
            expectedMaxDurationSeconds: expectedMaxDurationSeconds,
            durationBudgetPassed: durationBudgetPassed,
            failureReasons: failureReasons,
            executionError: message,
            diagnosticSummary: zeroDiagnosticSummary(),
            reportPath: nil,
            manifestPath: nil
        )
    }

    private func runOracleIfNeeded(
        corpusCase: DRCCorpusCase,
        oracleBackendID: String?,
        specDirectory: URL,
        caseDirectory: URL,
        preparedInputs: PreparedDRCCorpusInputs,
        primaryPassed: Bool,
        primaryBackendID: String,
        primaryActiveRuleIDs: [String],
        primaryDiagnosticSummary: DRCDiagnosticSummary
    ) async -> DRCCorpusOracleResult? {
        guard let oracleBackendID else {
            return nil
        }
        let oracleDirectory = caseDirectory
            .appending(path: "oracle-\(safePathComponent(oracleBackendID))")
        let startedAt = Date()
        do {
            try FileManager.default.createDirectory(at: oracleDirectory, withIntermediateDirectories: true)
        } catch {
            return failedOracleResult(
                backendID: oracleBackendID,
                durationSeconds: Date().timeIntervalSince(startedAt),
                error: error
            )
        }
        let request = DRCRequest(
            layoutURL: preparedInputs.layoutURL,
            topCell: corpusCase.topCell,
            layoutFormat: preparedInputs.layoutFormat,
            technologyURL: preparedInputs.technologyURL,
            waiverURL: corpusCase.waiverPath.map { resolve($0, relativeTo: specDirectory) },
            workingDirectory: oracleDirectory,
            backendSelection: DRCBackendSelection(backendID: oracleBackendID),
            options: DRCOptions(additionalEnvironment: corpusCase.additionalEnvironment)
        )
        let executionResult: DRCExecutionResult
        do {
            executionResult = try await engine.run(request)
        } catch {
            return failedOracleResult(
                backendID: oracleBackendID,
                durationSeconds: Date().timeIntervalSince(startedAt),
                error: error
            )
        }
        let durationSeconds = Date().timeIntervalSince(startedAt)
        let oracleRuleIDs = activeErrorRuleIDs(in: executionResult.result.diagnostics)
        let oracleDiagnosticSummary = diagnosticSummary(executionResult.result.diagnostics)
        let readinessDiagnostics = oracleReadinessDiagnostics(for: executionResult.result)
        let readinessStatus: DRCCorpusOracleReadinessStatus = readinessDiagnostics.isEmpty ? .ready : .blocked
        let executionError = readinessDiagnostics.first
        let readinessFailureReasons = executionError.map { ["oracle_execution_failed:\($0)"] } ?? []
        let agreementPassed = executionResult.result.passed == primaryPassed
            && oracleRuleIDs == primaryActiveRuleIDs
        let comparison = DRCCorpusOracleComparison(
            primaryBackendID: primaryBackendID,
            oracleBackendID: executionResult.result.backendID,
            passedMatched: executionResult.result.passed == primaryPassed,
            activeErrorRuleIDsMatched: oracleRuleIDs == primaryActiveRuleIDs,
            diagnosticSummaryMatched: oracleDiagnosticSummary == primaryDiagnosticSummary,
            primaryPassed: primaryPassed,
            oraclePassed: executionResult.result.passed,
            primaryActiveErrorRuleIDs: primaryActiveRuleIDs,
            oracleActiveErrorRuleIDs: oracleRuleIDs,
            primaryDiagnosticSummary: primaryDiagnosticSummary,
            oracleDiagnosticSummary: oracleDiagnosticSummary,
            mismatchReasons: agreementPassed && readinessFailureReasons.isEmpty ? [] : oracleMismatchReasons(
                primaryPassed: primaryPassed,
                oraclePassed: executionResult.result.passed,
                primaryActiveRuleIDs: primaryActiveRuleIDs,
                oracleActiveRuleIDs: oracleRuleIDs,
                primaryDiagnosticSummary: primaryDiagnosticSummary,
                oracleDiagnosticSummary: oracleDiagnosticSummary,
                oracleFailureReasons: readinessFailureReasons + ["oracle_agreement_mismatch"]
            )
        )
        return DRCCorpusOracleResult(
            backendID: executionResult.result.backendID,
            passed: executionResult.result.passed,
            activeErrorRuleIDs: oracleRuleIDs,
            diagnosticSummary: oracleDiagnosticSummary,
            durationSeconds: durationSeconds,
            agreementPassed: comparison.agreementPassed && readinessStatus == .ready,
            readinessStatus: readinessStatus,
            readinessDiagnostics: readinessDiagnostics,
            failureReasons: comparison.mismatchReasons,
            executionError: executionError,
            reportPath: executionResult.reportURL?.path(percentEncoded: false),
            manifestPath: executionResult.artifactManifestURL?.path(percentEncoded: false),
            provenance: provenance(for: executionResult)
        )
    }

    private func failedOracleResult(
        backendID: String,
        durationSeconds: Double,
        error: any Error
    ) -> DRCCorpusOracleResult {
        let message = executionErrorMessage(error)
        return DRCCorpusOracleResult(
            backendID: backendID,
            passed: false,
            activeErrorRuleIDs: [],
            diagnosticSummary: zeroDiagnosticSummary(),
            durationSeconds: durationSeconds,
            agreementPassed: false,
            readinessStatus: .blocked,
            readinessDiagnostics: [message],
            failureReasons: ["oracle_execution_failed:\(message)"],
            executionError: message,
            reportPath: nil,
            manifestPath: nil
        )
    }

    private func provenance(for executionResult: DRCExecutionResult) -> DRCCorpusCaseProvenance? {
        guard let manifestURL = executionResult.artifactManifestURL else {
            return nil
        }
        let manifest: DRCArtifactManifest
        do {
            let data = try Data(contentsOf: manifestURL)
            manifest = try JSONDecoder().decode(DRCArtifactManifest.self, from: data)
        } catch {
            return DRCCorpusCaseProvenance(
                backendID: executionResult.result.backendID,
                reportPath: executionResult.reportURL?.path(percentEncoded: false),
                manifestPath: manifestURL.path(percentEncoded: false)
            )
        }

        return DRCCorpusCaseProvenance(
            backendID: executionResult.result.backendID,
            inputArtifacts: manifest.inputs,
            outputArtifacts: manifest.outputs,
            reportPath: executionResult.reportURL?.path(percentEncoded: false),
            manifestPath: manifestURL.path(percentEncoded: false)
        )
    }

    private func oracleComparison(
        primaryBackendID: String,
        primaryPassed: Bool,
        primaryActiveRuleIDs: [String],
        primaryDiagnosticSummary: DRCDiagnosticSummary,
        oracleResult: DRCCorpusOracleResult
    ) -> DRCCorpusOracleComparison {
        DRCCorpusOracleComparison(
            primaryBackendID: primaryBackendID,
            oracleBackendID: oracleResult.backendID,
            passedMatched: primaryPassed == oracleResult.passed,
            activeErrorRuleIDsMatched: primaryActiveRuleIDs == oracleResult.activeErrorRuleIDs,
            diagnosticSummaryMatched: primaryDiagnosticSummary == oracleResult.diagnosticSummary,
            primaryPassed: primaryPassed,
            oraclePassed: oracleResult.passed,
            primaryActiveErrorRuleIDs: primaryActiveRuleIDs,
            oracleActiveErrorRuleIDs: oracleResult.activeErrorRuleIDs,
            primaryDiagnosticSummary: primaryDiagnosticSummary,
            oracleDiagnosticSummary: oracleResult.diagnosticSummary,
            mismatchReasons: oracleMismatchReasons(
                primaryPassed: primaryPassed,
                oraclePassed: oracleResult.passed,
                primaryActiveRuleIDs: primaryActiveRuleIDs,
                oracleActiveRuleIDs: oracleResult.activeErrorRuleIDs,
                primaryDiagnosticSummary: primaryDiagnosticSummary,
                oracleDiagnosticSummary: oracleResult.diagnosticSummary,
                oracleFailureReasons: oracleResult.failureReasons
            )
        )
    }

    private func oracleMismatchReasons(
        primaryPassed: Bool,
        oraclePassed: Bool,
        primaryActiveRuleIDs: [String],
        oracleActiveRuleIDs: [String],
        primaryDiagnosticSummary: DRCDiagnosticSummary,
        oracleDiagnosticSummary: DRCDiagnosticSummary,
        oracleFailureReasons: [String]
    ) -> [String] {
        var reasons: [String] = []
        if primaryPassed != oraclePassed {
            reasons.append("passed_mismatch")
        }
        if primaryActiveRuleIDs != oracleActiveRuleIDs {
            reasons.append("active_error_rule_ids_mismatch")
        }
        if primaryDiagnosticSummary != oracleDiagnosticSummary {
            reasons.append("diagnostic_summary_mismatch")
        }
        for reason in oracleFailureReasons where !reasons.contains(reason) {
            reasons.append(reason)
        }
        return reasons
    }

    private func oracleReadinessDiagnostics(for result: DRCResult) -> [String] {
        guard result.completed else {
            let messages = result.diagnostics
                .filter { $0.severity == .error }
                .map { diagnostic in
                    let ruleID = diagnostic.ruleID ?? "unclassified"
                    return "\(ruleID): \(diagnostic.message)"
                }
            if messages.isEmpty {
                return ["oracle_result_incomplete"]
            }
            return ["oracle_result_incomplete"] + messages
        }
        return []
    }

    private func activeErrorRuleIDs(in diagnostics: [DRCDiagnostic]) -> [String] {
        diagnostics
            .filter { $0.severity == .error && !$0.isWaived }
            .map { $0.ruleID ?? "unclassified" }
            .sorted()
    }

    private func diagnosticSummary(_ diagnostics: [DRCDiagnostic]) -> DRCDiagnosticSummary {
        diagnostics.reduce(into: DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0)) { summary, diagnostic in
            switch diagnostic.severity {
            case .info:
                summary = DRCDiagnosticSummary(
                    infoCount: summary.infoCount + 1,
                    warningCount: summary.warningCount,
                    errorCount: summary.errorCount,
                    waivedErrorCount: summary.waivedErrorCount
                )
            case .warning:
                summary = DRCDiagnosticSummary(
                    infoCount: summary.infoCount,
                    warningCount: summary.warningCount + 1,
                    errorCount: summary.errorCount,
                    waivedErrorCount: summary.waivedErrorCount
                )
            case .error:
                summary = DRCDiagnosticSummary(
                    infoCount: summary.infoCount,
                    warningCount: summary.warningCount,
                    errorCount: summary.errorCount + (diagnostic.isWaived ? 0 : 1),
                    waivedErrorCount: summary.waivedErrorCount + (diagnostic.isWaived ? 1 : 0)
                )
            }
        }
    }

    private func zeroDiagnosticSummary() -> DRCDiagnosticSummary {
        DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0)
    }

    private func executionErrorMessage(_ error: any Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return error.localizedDescription
    }

    private func resolve(_ path: String, relativeTo base: URL) -> URL {
        if path.hasPrefix("/") {
            return URL(filePath: path)
        }
        return base.appending(path: path)
    }

    private func safePathComponent(_ value: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        let mapped = value.map { allowed.contains($0) ? $0 : "_" }
        let result = String(mapped)
        return result.isEmpty ? "case" : result
    }
}

struct PreparedDRCCorpusInputs: Sendable {
    let layoutURL: URL
    let layoutFormat: DRCLayoutFormat?
    let technologyURL: URL?
}
