import Foundation
import CryptoKit
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
        options: DRCCorpusRunOptions = DRCCorpusRunOptions(),
        eventHandler: DRCCorpusRunEventHandler? = nil
    ) async throws -> DRCCorpusReport {
        let (spec, specData) = try loadSpec(from: specURL)
        try spec.validate()
        try options.validate()
        try validateOracleOverride(options.oracleBackendIDOverride, for: spec)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        try validateBudget(spec.defaultMaxDurationSeconds, label: "defaultMaxDurationSeconds")
        let specSHA256 = sha256(specData)
        let runID = options.runID ?? UUID().uuidString.lowercased()
        let resumedReport = try loadResumeReport(
            from: options.resumeReportURL,
            expectedSpecSHA256: specSHA256,
            expectedEvidenceKind: spec.evidenceKind
        )
        await emit(
            .started(
                runID: runID,
                caseCount: spec.cases.count,
                resumedFromRunID: resumedReport?.runID
            ),
            using: eventHandler
        )

        let caseResults: [DRCCorpusCaseResult]
        do {
            caseResults = try await runCases(
                spec: spec,
                specDirectory: specURL.deletingLastPathComponent(),
                outputDirectory: outputDirectory,
                options: options,
                runID: runID,
                specSHA256: specSHA256,
                parentRunID: resumedReport?.runID,
                priorResults: resumedReport?.caseResults ?? [],
                eventHandler: eventHandler
            )
        } catch is CancellationError {
            await emit(.cancelled(runID: runID), using: eventHandler)
            throw CancellationError()
        }
        let report = makeReport(
            caseResults: caseResults,
            options: options,
            acceptanceCriteria: spec.effectiveAcceptanceCriteria,
            evidenceKind: spec.evidenceKind,
            runID: runID,
            parentRunID: resumedReport?.runID,
            specSHA256: specSHA256,
            completed: true
        )
        try report.validate()
        try writeReport(report, to: outputDirectory)
        await emit(.completed(report), using: eventHandler)
        return report
    }

    private func loadSpec(from specURL: URL) throws -> (DRCCorpusSpec, Data) {
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
        return (spec, data)
    }

    private func validateOracleOverride(
        _ oracleBackendIDOverride: String?,
        for spec: DRCCorpusSpec
    ) throws {
        guard let oracleBackendIDOverride else { return }
        for corpusCase in spec.cases where corpusCase.expectedOracleActiveErrorRuleIDs != nil {
            guard corpusCase.oracleBackendID == oracleBackendIDOverride else {
                throw DRCError.invalidInput(
                    "DRC corpus case '\(corpusCase.caseID)' declares backend-specific oracle rule assertions for '\(corpusCase.oracleBackendID ?? "none")'; --oracle-backend cannot replace that backend with '\(oracleBackendIDOverride)'."
                )
            }
        }
    }

    private func loadResumeReport(
        from reportURL: URL?,
        expectedSpecSHA256: String,
        expectedEvidenceKind: DRCCorpusEvidenceKind
    ) throws -> DRCCorpusReport? {
        guard let reportURL else { return nil }
        let data: Data
        do {
            data = try Data(contentsOf: reportURL)
        } catch {
            throw DRCError.invalidInput(
                "Could not read DRC corpus resume report: \(error.localizedDescription)"
            )
        }
        let report: DRCCorpusReport
        do {
            report = try JSONDecoder().decode(DRCCorpusReport.self, from: data)
        } catch {
            throw DRCError.invalidInput(
                "Could not decode DRC corpus resume report: \(error.localizedDescription)"
            )
        }
        try report.validateEvidence()
        guard report.specSHA256 == expectedSpecSHA256 else {
            throw DRCError.invalidInput(
                "DRC corpus resume report spec digest does not match the requested corpus spec."
            )
        }
        guard report.evidenceKind == expectedEvidenceKind else {
            throw DRCError.invalidInput(
                "DRC corpus resume report evidence kind does not match the requested corpus spec."
            )
        }
        return report
    }

    private func isReusable(_ result: DRCCorpusCaseResult, options: DRCCorpusRunOptions) -> Bool {
        guard result.matched,
              let reportPath = result.reportPath,
              let manifestPath = result.manifestPath,
              !reportPath.isEmpty,
              !manifestPath.isEmpty else {
            return false
        }
        guard FileManager.default.fileExists(atPath: reportPath),
              FileManager.default.fileExists(atPath: manifestPath) else {
            return false
        }
        do {
            return try DRCArtifactManifestVerifier().verify(
                manifestURL: URL(filePath: manifestPath),
                requireSignature: options.requireSignedArtifacts,
                trustedPublicKey: options.trustedArtifactPublicKey
            ).isEmpty
        } catch {
            return false
        }
    }

    private func runCases(
        spec: DRCCorpusSpec,
        specDirectory: URL,
        outputDirectory: URL,
        options: DRCCorpusRunOptions,
        runID: String,
        specSHA256: String,
        parentRunID: String?,
        priorResults: [DRCCorpusCaseResult],
        eventHandler: DRCCorpusRunEventHandler?
    ) async throws -> [DRCCorpusCaseResult] {
        var caseResults: [DRCCorpusCaseResult] = []

        for (index, corpusCase) in spec.cases.enumerated() {
            try Task.checkCancellation()
            await emit(.caseStarted(caseID: corpusCase.caseID, index: index), using: eventHandler)
            if let previous = priorResults.first(where: { $0.caseID == corpusCase.caseID }),
               isReusable(previous, options: options) {
                caseResults.append(previous)
                await emit(.caseResumed(caseID: corpusCase.caseID, index: index), using: eventHandler)
                await emit(
                    .caseCompleted(caseID: corpusCase.caseID, index: index, result: previous),
                    using: eventHandler
                )
                let checkpointURL = try writeCheckpoint(
                    caseResults: caseResults,
                    spec: spec,
                    options: options,
                    runID: runID,
                    parentRunID: parentRunID,
                    specSHA256: specSHA256,
                    outputDirectory: outputDirectory
                )
                await emit(.checkpointWritten(checkpointURL), using: eventHandler)
                continue
            }
            let result = try await runCase(
                corpusCase,
                defaultMaxDurationSeconds: spec.defaultMaxDurationSeconds,
                specDirectory: specDirectory,
                outputDirectory: outputDirectory,
                options: options,
                requireMarkerCorrelation: spec.evidenceKind.requiresMarkerCorrelation
            )
            caseResults.append(result)
            await emit(
                .caseCompleted(caseID: corpusCase.caseID, index: index, result: result),
                using: eventHandler
            )
            let checkpointURL = try writeCheckpoint(
                caseResults: caseResults,
                spec: spec,
                options: options,
                runID: runID,
                parentRunID: parentRunID,
                specSHA256: specSHA256,
                outputDirectory: outputDirectory
            )
            await emit(.checkpointWritten(checkpointURL), using: eventHandler)
        }
        return caseResults
    }

    private func runCase(
        _ corpusCase: DRCCorpusCase,
        defaultMaxDurationSeconds: Double?,
        specDirectory: URL,
        outputDirectory: URL,
        options: DRCCorpusRunOptions,
        requireMarkerCorrelation: Bool
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
                caseDirectory: caseDirectory,
                timeoutSeconds: executionTimeoutSeconds(for: maxDurationSeconds),
                runOptions: options
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
            options: options,
            requireMarkerCorrelation: requireMarkerCorrelation
        )
    }

    private func createCaseDirectory(for corpusCase: DRCCorpusCase, outputDirectory: URL) throws -> URL {
        let caseDirectory = outputDirectory
            .appending(path: "cases")
            .appending(path: DRCCorpusNamespace.safePathComponent(corpusCase.caseID))
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
        caseDirectory: URL,
        timeoutSeconds: Double?,
        runOptions: DRCCorpusRunOptions
    ) -> DRCRequest {
        DRCRequest(
            layoutURL: preparedInputs.layoutURL,
            topCell: corpusCase.topCell,
            layoutFormat: preparedInputs.layoutFormat,
            technologyURL: preparedInputs.technologyURL,
            waiverURL: corpusCase.waiverPath.map { resolve($0, relativeTo: specDirectory) },
            workingDirectory: caseDirectory,
            backendSelection: DRCBackendSelection(backendID: corpusCase.backendID ?? "native"),
            options: DRCOptions(
                timeoutSeconds: timeoutSeconds ?? DRCOptions().timeoutSeconds,
                additionalEnvironment: corpusCase.additionalEnvironment,
                requireSignedArtifacts: runOptions.requireSignedArtifacts,
                trustedArtifactPublicKey: runOptions.trustedArtifactPublicKey,
                requireAntennaRules: runOptions.requireAntennaRules
            ),
            designRevision: corpusCase.designRevision,
            canonicalStateDigest: corpusCase.canonicalStateDigest
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
        options: DRCCorpusRunOptions,
        requireMarkerCorrelation: Bool
    ) async -> DRCCorpusCaseResult {
        let durationSeconds = Date().timeIntervalSince(startedAt)
        let actualRuleIDs = activeErrorRuleIDs(in: executionResult.result.diagnostics)
        let primaryDiagnosticSummary = diagnosticSummary(executionResult.result.diagnostics)
        let expectedRuleIDs = corpusCase.expectedActiveErrorRuleIDs.sorted()
        let expectationMatched = executionResult.result.passed == corpusCase.expectedPassed
            && actualRuleIDs == expectedRuleIDs
        let durationBudgetPassed = maxDurationSeconds.map { durationSeconds <= $0 } ?? true
        let remainingTimeoutSeconds = maxDurationSeconds.map {
            max(0, $0 - durationSeconds)
        }
        let oracleResult = await runOracleIfNeeded(
            corpusCase: corpusCase,
            oracleBackendID: options.oracleBackendIDOverride ?? corpusCase.oracleBackendID,
            specDirectory: specDirectory,
            caseDirectory: caseDirectory,
            preparedInputs: preparedInputs,
            primaryPassed: executionResult.result.passed,
            primaryBackendID: executionResult.result.backendID,
            primaryActiveRuleIDs: actualRuleIDs,
            expectedPrimaryActiveRuleIDs: expectedRuleIDs,
            expectedOracleActiveRuleIDs: corpusCase.expectedOracleActiveErrorRuleIDs,
            primaryDiagnosticSummary: primaryDiagnosticSummary,
            primaryMarkerFingerprints: DRCCorpusMarkerFingerprint.fingerprints(
                from: executionResult.result.diagnostics
            ),
            timeoutSeconds: remainingTimeoutSeconds,
            requireMarkerCorrelation: requireMarkerCorrelation,
            requireSignedArtifacts: options.requireSignedArtifacts,
            trustedArtifactPublicKey: options.trustedArtifactPublicKey,
            requireAntennaRules: options.requireAntennaRules
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
            oracleResult: oracleResult,
            requireMarkerCorrelation: requireMarkerCorrelation
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
        oracleResult: DRCCorpusOracleResult?,
        requireMarkerCorrelation: Bool
    ) -> DRCCorpusCaseResult {
        let oracleComparison = oracleResult.map {
            self.oracleComparison(
                primaryBackendID: executionResult.result.backendID,
                primaryPassed: executionResult.result.passed,
                primaryActiveRuleIDs: actualRuleIDs,
                expectedPrimaryActiveRuleIDs: expectedRuleIDs,
                expectedOracleActiveRuleIDs: corpusCase.expectedOracleActiveErrorRuleIDs,
                primaryDiagnosticSummary: primaryDiagnosticSummary,
                primaryMarkerFingerprints: DRCCorpusMarkerFingerprint.fingerprints(
                    from: executionResult.result.diagnostics
                ),
                oracleResult: $0,
                requireMarkerCorrelation: requireMarkerCorrelation
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
        acceptanceCriteria: DRCCorpusAcceptanceCriteria,
        evidenceKind: DRCCorpusEvidenceKind,
        runID: String?,
        parentRunID: String?,
        specSHA256: String?,
        completed: Bool
    ) -> DRCCorpusReport {
        DRCCorpusReport(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            runID: runID,
            parentRunID: parentRunID,
            specSHA256: specSHA256,
            completed: completed,
            passed: caseResults.allSatisfy(\.matched),
            caseCount: caseResults.count,
            matchedCaseCount: caseResults.filter(\.matched).count,
            budgetExceededCaseCount: caseResults.filter { !$0.durationBudgetPassed }.count,
            totalDurationSeconds: caseResults.reduce(0) { $0 + $1.durationSeconds },
            evidenceKind: evidenceKind,
            runOptions: options,
            acceptanceCriteria: acceptanceCriteria,
            caseResults: caseResults
        )
    }

    @discardableResult
    private func writeCheckpoint(
        caseResults: [DRCCorpusCaseResult],
        spec: DRCCorpusSpec,
        options: DRCCorpusRunOptions,
        runID: String,
        parentRunID: String?,
        specSHA256: String,
        outputDirectory: URL
    ) throws -> URL {
        let report = makeReport(
            caseResults: caseResults,
            options: options,
            acceptanceCriteria: spec.effectiveAcceptanceCriteria,
            evidenceKind: spec.evidenceKind,
            runID: runID,
            parentRunID: parentRunID,
            specSHA256: specSHA256,
            completed: false
        )
        try report.validate()
        return try writeReport(report, to: outputDirectory, fileName: "drc-corpus-checkpoint.json")
    }

    @discardableResult
    private func writeReport(
        _ report: DRCCorpusReport,
        to outputDirectory: URL,
        fileName: String = "drc-corpus-report.json"
    ) throws -> URL {
        let reportURL = outputDirectory.appending(path: fileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let reportData = try encoder.encode(report)
        try reportData.write(to: reportURL, options: [.atomic])
        return reportURL
    }

    private func emit(
        _ event: DRCCorpusRunEvent,
        using handler: DRCCorpusRunEventHandler?
    ) async {
        guard let handler else { return }
        await handler(event)
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func validateBudget(_ value: Double?, label: String) throws {
        guard let value else { return }
        guard value.isFinite, value > 0 else {
            throw DRCError.invalidInput("\(label) must be positive finite seconds")
        }
    }

    private func executionTimeoutSeconds(for budget: Double?) -> Double {
        // Very small budgets cannot be observed reliably after process
        // startup and input preparation. Keep the declared budget for the
        // verdict, while using a bounded minimum for backend execution.
        max(budget ?? DRCOptions().timeoutSeconds, 1)
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
        expectedPrimaryActiveRuleIDs: [String],
        expectedOracleActiveRuleIDs: [String]?,
        primaryDiagnosticSummary: DRCDiagnosticSummary,
        primaryMarkerFingerprints: [String],
        timeoutSeconds: Double?,
        requireMarkerCorrelation: Bool,
        requireSignedArtifacts: Bool,
        trustedArtifactPublicKey: String?,
        requireAntennaRules: Bool
    ) async -> DRCCorpusOracleResult? {
        guard let oracleBackendID else {
            return nil
        }
        let primaryIdentity = engine.backendIdentity(for: primaryBackendID)
            ?? DRCBackendIdentity(backendID: primaryBackendID)
        let oracleIdentity = engine.backendIdentity(for: oracleBackendID)
            ?? DRCBackendIdentity(backendID: oracleBackendID)
        let primaryFamilyIsKnown = primaryIdentity.implementationFamily != .unknown
        if let independenceFailureCode = primaryIdentity.independenceFailureCode(comparedTo: oracleIdentity),
           independenceFailureCode != "reference_independence_unproven"
            || (independenceFailureCode == "reference_independence_unproven"
                && primaryFamilyIsKnown
                && !engine.hasBackend(oracleBackendID)) {
            return rejectedOracleResult(
                backendID: oracleBackendID,
                backendIdentity: oracleIdentity,
                failureCode: independenceFailureCode,
                primaryBackendID: primaryBackendID,
                primaryPassed: primaryPassed,
                primaryActiveRuleIDs: primaryActiveRuleIDs,
                primaryDiagnosticSummary: primaryDiagnosticSummary,
                primaryMarkerFingerprints: primaryMarkerFingerprints,
                durationSeconds: 0
            )
        }
        if let timeoutSeconds, timeoutSeconds <= 0 {
            return failedOracleResult(
                backendID: oracleBackendID,
                backendIdentity: oracleIdentity,
                durationSeconds: 0,
                error: DRCError.timedOut(
                    "DRC corpus case exhausted its duration budget before oracle execution."
                )
            )
        }
        let oracleDirectory = caseDirectory
            .appending(path: "oracle-\(DRCCorpusNamespace.safePathComponent(oracleBackendID))")
        let startedAt = Date()
        do {
            try FileManager.default.createDirectory(at: oracleDirectory, withIntermediateDirectories: true)
        } catch {
            return failedOracleResult(
                backendID: oracleBackendID,
                backendIdentity: oracleIdentity,
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
            options: DRCOptions(
                timeoutSeconds: executionTimeoutSeconds(for: timeoutSeconds),
                additionalEnvironment: corpusCase.additionalEnvironment,
                requireSignedArtifacts: requireSignedArtifacts,
                trustedArtifactPublicKey: trustedArtifactPublicKey,
                requireAntennaRules: requireAntennaRules
            ),
            designRevision: corpusCase.designRevision,
            canonicalStateDigest: corpusCase.canonicalStateDigest
        )
        let executionResult: DRCExecutionResult
        do {
            executionResult = try await engine.run(request)
        } catch {
            return failedOracleResult(
                backendID: oracleBackendID,
                backendIdentity: oracleIdentity,
                durationSeconds: Date().timeIntervalSince(startedAt),
                error: error
            )
        }
        let durationSeconds = Date().timeIntervalSince(startedAt)
        let oracleRuleIDs = activeErrorRuleIDs(in: executionResult.result.diagnostics)
        let oracleDiagnosticSummary = diagnosticSummary(executionResult.result.diagnostics)
        let oracleMarkerFingerprints = DRCCorpusMarkerFingerprint.fingerprints(
            from: executionResult.result.diagnostics
        )
        let readinessDiagnostics = oracleReadinessDiagnostics(for: executionResult.result)
        let readinessStatus: DRCCorpusOracleReadinessStatus = readinessDiagnostics.isEmpty ? .ready : .blocked
        let executionError = readinessDiagnostics.first
        let readinessFailureReasons = executionError.map { ["oracle_execution_failed:\($0)"] } ?? []
        let ruleAssertionsMatched = expectedOracleActiveRuleIDs.map {
            primaryActiveRuleIDs == expectedPrimaryActiveRuleIDs && oracleRuleIDs == $0
        } ?? (oracleRuleIDs == primaryActiveRuleIDs)
        let agreementPassed = executionResult.result.passed == primaryPassed
            && ruleAssertionsMatched
            && (!requireMarkerCorrelation || oracleMarkerFingerprints == primaryMarkerFingerprints)
        let markerSetMatched = oracleMarkerFingerprints == primaryMarkerFingerprints
        let comparison = DRCCorpusOracleComparison(
            primaryBackendID: primaryBackendID,
            oracleBackendID: executionResult.result.backendID,
            passedMatched: executionResult.result.passed == primaryPassed,
            activeErrorRuleIDsMatched: oracleRuleIDs == primaryActiveRuleIDs,
            ruleAssertionsMatched: ruleAssertionsMatched,
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
                ruleAssertionsMatched: ruleAssertionsMatched,
                primaryDiagnosticSummary: primaryDiagnosticSummary,
                oracleDiagnosticSummary: oracleDiagnosticSummary,
                primaryMarkerFingerprints: primaryMarkerFingerprints,
                oracleMarkerFingerprints: oracleMarkerFingerprints,
                requireMarkerCorrelation: requireMarkerCorrelation,
                oracleFailureReasons: readinessFailureReasons + ["oracle_agreement_mismatch"]
            ),
            agreementPassed: agreementPassed && readinessFailureReasons.isEmpty,
            primaryMarkerFingerprints: primaryMarkerFingerprints,
            oracleMarkerFingerprints: oracleMarkerFingerprints,
            markerSetMatched: markerSetMatched,
            markerCorrelationRequired: requireMarkerCorrelation
        )
        return DRCCorpusOracleResult(
            backendID: executionResult.result.backendID,
            backendIdentity: executionResult.result.backendIdentity,
            passed: executionResult.result.passed,
            activeErrorRuleIDs: oracleRuleIDs,
            diagnosticSummary: oracleDiagnosticSummary,
            durationSeconds: durationSeconds,
            agreementPassed: comparison.agreementPassed && readinessStatus == .ready,
            readinessStatus: readinessStatus,
            readinessDiagnostics: readinessDiagnostics,
            failureReasons: comparison.mismatchReasons,
            markerFingerprints: oracleMarkerFingerprints,
            executionError: executionError,
            reportPath: executionResult.reportURL?.path(percentEncoded: false),
            manifestPath: executionResult.artifactManifestURL?.path(percentEncoded: false),
            provenance: provenance(for: executionResult)
        )
    }

    private func rejectedOracleResult(
        backendID: String,
        backendIdentity: DRCBackendIdentity,
        failureCode: String,
        primaryBackendID: String,
        primaryPassed: Bool,
        primaryActiveRuleIDs: [String],
        primaryDiagnosticSummary: DRCDiagnosticSummary,
        primaryMarkerFingerprints: [String],
        durationSeconds: Double
    ) -> DRCCorpusOracleResult {
        let message = "Oracle backend '\(backendID)' is not independent from primary backend '\(primaryBackendID)': \(failureCode)."
        return DRCCorpusOracleResult(
            backendID: backendID,
            backendIdentity: backendIdentity,
            passed: primaryPassed,
            activeErrorRuleIDs: primaryActiveRuleIDs,
            diagnosticSummary: primaryDiagnosticSummary,
            durationSeconds: durationSeconds,
            agreementPassed: false,
            readinessStatus: .blocked,
            readinessDiagnostics: [message],
            failureReasons: [failureCode],
            markerFingerprints: primaryMarkerFingerprints,
            reportPath: nil,
            manifestPath: nil
        )
    }

    private func failedOracleResult(
        backendID: String,
        backendIdentity: DRCBackendIdentity,
        durationSeconds: Double,
        error: any Error
    ) -> DRCCorpusOracleResult {
        let message = executionErrorMessage(error)
        return DRCCorpusOracleResult(
            backendID: backendID,
            backendIdentity: backendIdentity,
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
                backendIdentity: executionResult.result.backendIdentity,
                reportPath: executionResult.reportURL?.path(percentEncoded: false),
                manifestPath: manifestURL.path(percentEncoded: false)
            )
        }

        return DRCCorpusCaseProvenance(
            backendID: executionResult.result.backendID,
            backendIdentity: executionResult.result.backendIdentity,
            inputArtifacts: manifest.inputs,
                outputArtifacts: manifest.outputs,
                reportPath: executionResult.reportURL?.path(percentEncoded: false),
                manifestPath: manifestURL.path(percentEncoded: false),
                runID: manifest.runID,
                requestSHA256: manifest.requestSHA256,
                requestEnvironmentSHA256: manifest.requestEnvironmentSHA256,
                artifactRootSHA256: manifest.artifactRootSHA256
            )
    }

    private func oracleComparison(
        primaryBackendID: String,
        primaryPassed: Bool,
        primaryActiveRuleIDs: [String],
        expectedPrimaryActiveRuleIDs: [String],
        expectedOracleActiveRuleIDs: [String]?,
        primaryDiagnosticSummary: DRCDiagnosticSummary,
        primaryMarkerFingerprints: [String],
        oracleResult: DRCCorpusOracleResult,
        requireMarkerCorrelation: Bool
    ) -> DRCCorpusOracleComparison {
        let markerSetMatched = primaryMarkerFingerprints == oracleResult.markerFingerprints
        let ruleAssertionsMatched = expectedOracleActiveRuleIDs.map {
            primaryActiveRuleIDs == expectedPrimaryActiveRuleIDs
                && oracleResult.activeErrorRuleIDs == $0
        } ?? (primaryActiveRuleIDs == oracleResult.activeErrorRuleIDs)
        return DRCCorpusOracleComparison(
            primaryBackendID: primaryBackendID,
            oracleBackendID: oracleResult.backendID,
            passedMatched: primaryPassed == oracleResult.passed,
            activeErrorRuleIDsMatched: primaryActiveRuleIDs == oracleResult.activeErrorRuleIDs,
            ruleAssertionsMatched: ruleAssertionsMatched,
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
                ruleAssertionsMatched: ruleAssertionsMatched,
                primaryDiagnosticSummary: primaryDiagnosticSummary,
                oracleDiagnosticSummary: oracleResult.diagnosticSummary,
                primaryMarkerFingerprints: primaryMarkerFingerprints,
                oracleMarkerFingerprints: oracleResult.markerFingerprints,
                requireMarkerCorrelation: requireMarkerCorrelation,
                oracleFailureReasons: oracleResult.failureReasons
            ),
            agreementPassed: oracleResult.agreementPassed
                && (!requireMarkerCorrelation || markerSetMatched),
            primaryMarkerFingerprints: primaryMarkerFingerprints,
            oracleMarkerFingerprints: oracleResult.markerFingerprints,
            markerSetMatched: markerSetMatched,
            markerCorrelationRequired: requireMarkerCorrelation
        )
    }

    private func oracleMismatchReasons(
        primaryPassed: Bool,
        oraclePassed: Bool,
        primaryActiveRuleIDs: [String],
        oracleActiveRuleIDs: [String],
        ruleAssertionsMatched: Bool? = nil,
        primaryDiagnosticSummary: DRCDiagnosticSummary,
        oracleDiagnosticSummary: DRCDiagnosticSummary,
        primaryMarkerFingerprints: [String] = [],
        oracleMarkerFingerprints: [String] = [],
        requireMarkerCorrelation: Bool = false,
        oracleFailureReasons: [String]
    ) -> [String] {
        var reasons: [String] = []
        if primaryPassed != oraclePassed {
            reasons.append("passed_mismatch")
        }
        if !(ruleAssertionsMatched ?? (primaryActiveRuleIDs == oracleActiveRuleIDs)) {
            reasons.append("active_error_rule_ids_mismatch")
        }
        if primaryDiagnosticSummary != oracleDiagnosticSummary {
            reasons.append("diagnostic_summary_mismatch")
        }
        if requireMarkerCorrelation && primaryMarkerFingerprints != oracleMarkerFingerprints {
            reasons.append("marker_set_mismatch")
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

}

struct PreparedDRCCorpusInputs: Sendable {
    let layoutURL: URL
    let layoutFormat: DRCLayoutFormat?
    let technologyURL: URL?
}
