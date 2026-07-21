import Foundation
import CryptoKit
import CircuiteFoundation
import DRCCore

public struct DRCArtifactSaveResult: Sendable, Hashable {
    public let reportURL: URL
    public let manifestURL: URL
    public let runID: String?

    public init(reportURL: URL, manifestURL: URL, runID: String? = nil) {
        self.reportURL = reportURL
        self.manifestURL = manifestURL
        self.runID = runID
    }
}

public struct DRCArtifactStore: Sendable {
    private let signer: (any DRCArtifactSigner)?

    public init(signer: (any DRCArtifactSigner)? = nil) {
        self.signer = signer
    }

    public func save(_ executionResult: DRCExecutionResult, to directory: URL) throws -> DRCArtifactSaveResult {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let runID = UUID().uuidString.lowercased()
            let reportURL = directory.appending(path: "drc-report-\(runID).json")
            let manifestURL = directory.appending(path: "drc-artifact-manifest-\(runID).json")
            let storedResult = DRCExecutionResult(
                request: executionResult.request,
                result: executionResult.result,
                waiverReport: executionResult.waiverReport,
                repairHintGeometry: executionResult.repairHintGeometry,
                reportURL: reportURL,
                artifactManifestURL: manifestURL,
                artifactRunID: runID,
                provenance: executionResult.provenance
            )
            let data = try encoder.encode(storedResult)
            try data.write(to: reportURL, options: [.atomic])

            let manifest = try makeManifest(
                for: storedResult,
                reportURL: reportURL,
                manifestURL: manifestURL,
                baseDirectory: directory,
                runID: runID
            )
            let signedManifest: DRCArtifactManifest
            if let signer {
                let canonicalEncoder = JSONEncoder()
                canonicalEncoder.outputFormatting = [.sortedKeys]
                let unsignedData = try canonicalEncoder.encode(manifest.withSignature(nil))
                signedManifest = manifest.withSignature(try signer.sign(unsignedData))
            } else {
                signedManifest = manifest
            }
            let manifestData = try encoder.encode(signedManifest)
            try manifestData.write(to: manifestURL, options: [.atomic])
            return DRCArtifactSaveResult(reportURL: reportURL, manifestURL: manifestURL, runID: runID)
        } catch {
            throw DRCError.artifactWriteFailed(error.localizedDescription)
        }
    }

    private func makeManifest(
        for executionResult: DRCExecutionResult,
        reportURL: URL,
        manifestURL: URL,
        baseDirectory: URL,
        runID: String
    ) throws -> DRCArtifactManifest {
        var inputs = [
            try record(
                id: "input-layout",
                kind: .layout,
                url: executionResult.request.layoutURL,
                baseDirectory: baseDirectory,
                sourceReferences: executionResult.provenance.inputs,
                expectedArtifactKind: .layout
            ),
        ]
        if let technologyURL = executionResult.request.technologyURL {
            inputs.append(try record(
                id: "input-technology",
                kind: .technology,
                url: technologyURL,
                baseDirectory: baseDirectory,
                sourceReferences: executionResult.provenance.inputs,
                expectedArtifactKind: .technology
            ))
        }
        if let waiverURL = executionResult.request.waiverURL {
            inputs.append(try record(
                id: "input-waivers",
                kind: .waiver,
                url: waiverURL,
                baseDirectory: baseDirectory,
                sourceReferences: executionResult.provenance.inputs,
                expectedArtifactKind: .constraint
            ))
        }

        var outputs = [
            try record(
                id: "report",
                kind: .report,
                url: reportURL,
                baseDirectory: baseDirectory
            ),
        ]
        let logURL = URL(filePath: executionResult.result.logPath)
        if !executionResult.result.logPath.isEmpty,
           FileManager.default.fileExists(atPath: logURL.path(percentEncoded: false)) {
            outputs.append(try record(id: "log", kind: .log, url: logURL, baseDirectory: baseDirectory))
        }
        outputs.append(DRCArtifactRecord(
            id: "manifest",
            kind: .manifest,
            path: relativePath(for: manifestURL, baseDirectory: baseDirectory),
            byteCount: nil,
            sha256: nil
        ))

        let requestSHA256 = try digest(executionResult.request)
        let requestEnvironmentSHA256 = digestEnvironment(executionResult.request.options.additionalEnvironment)
        let artifactRootSHA256 = digestArtifactRecords(inputs: inputs, outputs: outputs)
        return DRCArtifactManifest(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            backendID: executionResult.result.backendID,
            backendIdentity: executionResult.result.backendIdentity,
            producer: executionResult.provenance.producer,
            toolName: executionResult.result.toolName,
            passed: executionResult.result.passed,
            completed: executionResult.result.completed,
            verdict: executionResult.result.verdict,
            inputs: inputs,
            outputs: outputs,
            diagnosticSummary: diagnosticSummary(executionResult.result.diagnostics),
            waiverReport: executionResult.waiverReport,
            runID: runID,
            requestSHA256: requestSHA256,
            requestEnvironmentSHA256: requestEnvironmentSHA256,
            artifactRootSHA256: artifactRootSHA256
        )
    }

    private func digest<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func digestEnvironment(_ environment: [String: String]) -> String {
        let canonical = environment.keys.sorted().map { key in
            key + "=" + (environment[key] ?? "")
        }.joined(separator: "\n")
        return SHA256.hash(data: Data(canonical.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func digestArtifactRecords(inputs: [DRCArtifactRecord], outputs: [DRCArtifactRecord]) -> String {
        let canonical = (inputs + outputs)
            .filter { $0.kind != .manifest }
            .sorted { $0.id < $1.id }
            .map { record in
                [
                    record.id,
                    record.kind.rawValue,
                    record.path,
                    String(record.byteCount ?? -1),
                    record.sha256 ?? "",
                    artifactReferenceIdentity(record.sourceReference),
                ].joined(separator: "|")
            }
            .joined(separator: "\n")
        return SHA256.hash(data: Data(canonical.utf8)).map { String(format: "%02x", $0) }.joined()
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

    private func record(
        id: String,
        kind: DRCArtifactRecord.Kind,
        url: URL,
        baseDirectory: URL,
        sourceReferences: [ArtifactReference] = [],
        expectedArtifactKind: ArtifactKind? = nil
    ) throws -> DRCArtifactRecord {
        guard url.isFileURL else {
            throw DRCError.artifactWriteFailed("non-file artifact URL is not supported for \(id): \(url.absoluteString)")
        }
        let data = try Data(contentsOf: url)
        let sourceReference: ArtifactReference?
        if let expectedArtifactKind {
            sourceReference = try uniqueSourceReference(
                for: url,
                data: data,
                expectedKind: expectedArtifactKind,
                among: sourceReferences,
                recordID: id
            )
        } else {
            sourceReference = nil
        }
        let retainedURL = try retainedArtifactURL(
            for: url,
            id: id,
            data: data,
            baseDirectory: baseDirectory
        )
        return DRCArtifactRecord(
            id: id,
            kind: kind,
            path: relativePath(for: retainedURL, baseDirectory: baseDirectory),
            byteCount: data.count,
            sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
            sourceReference: sourceReference
        )
    }

    private func uniqueSourceReference(
        for url: URL,
        data: Data,
        expectedKind: ArtifactKind,
        among references: [ArtifactReference],
        recordID: String
    ) throws -> ArtifactReference {
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let matches = references.filter { reference in
            reference.locator.kind == expectedKind
                && reference.digest.algorithm == .sha256
                && reference.digest.hexadecimalValue == digest
                && reference.byteCount == UInt64(data.count)
                && sourceLocation(reference.locator.location, matches: url)
        }
        guard matches.count == 1, let match = matches.first else {
            throw DRCError.artifactWriteFailed(
                "DRC manifest input \(recordID) requires exactly one matching execution provenance artifact; found \(matches.count)."
            )
        }
        return match
    }

    private func sourceLocation(_ location: ArtifactLocation, matches url: URL) -> Bool {
        let sourcePath = url.resolvingSymlinksInPath().standardizedFileURL.path(percentEncoded: false)
        switch location.storage {
        case .absoluteFileURL:
            guard let referenceURL = URL(string: location.value), referenceURL.isFileURL else {
                return false
            }
            return referenceURL.resolvingSymlinksInPath().standardizedFileURL
                .path(percentEncoded: false) == sourcePath
        case .workspaceRelative:
            let relativePath = location.value.split(separator: "/", omittingEmptySubsequences: true)
                .map(String.init)
                .joined(separator: "/")
            return sourcePath == "/" + relativePath || sourcePath.hasSuffix("/" + relativePath)
        }
    }

    private func artifactReferenceIdentity(_ reference: ArtifactReference?) -> String {
        guard let reference else { return "" }
        let producer = reference.producer.map {
            [$0.kind.rawValue, $0.identifier, $0.version, $0.build ?? ""].joined(separator: "\u{001F}")
        } ?? ""
        return [
            reference.id.rawValue,
            reference.locator.location.storage.rawValue,
            reference.locator.location.value,
            reference.locator.role.rawValue,
            reference.locator.kind.rawValue,
            reference.locator.format.rawValue,
            reference.digest.algorithm.rawValue,
            reference.digest.hexadecimalValue,
            String(reference.byteCount),
            producer,
        ].joined(separator: "\u{001E}")
    }

    private func retainedArtifactURL(
        for url: URL,
        id: String,
        data: Data,
        baseDirectory: URL
    ) throws -> URL {
        if isContained(url, in: baseDirectory) {
            return url
        }
        let fileName = safeFileName(url.lastPathComponent, fallback: "artifact")
        let retainedDirectory = baseDirectory
            .appending(path: "retained-artifacts")
            .appending(path: safeFileName(id, fallback: "artifact"))
        let retainedURL = retainedDirectory.appending(path: fileName)
        try FileManager.default.createDirectory(
            at: retainedDirectory,
            withIntermediateDirectories: true
        )
        try ensureRetainedDirectoryIsInsideBase(retainedDirectory, baseDirectory: baseDirectory)
        try data.write(to: retainedURL, options: [.atomic])
        return retainedURL
    }

    private func isContained(_ url: URL, in baseDirectory: URL) -> Bool {
        containmentRelativePath(for: url, baseDirectory: baseDirectory) != nil
    }

    private func safeFileName(_ value: String, fallback: String) -> String {
        let candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, candidate != ".", candidate != ".." else {
            return fallback
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let sanitized = candidate.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }
        let name = String(sanitized)
        return name.isEmpty ? fallback : name
    }

    private func relativePath(for url: URL, baseDirectory: URL) -> String {
        if let relativePath = containmentRelativePath(for: url, baseDirectory: baseDirectory) {
            return relativePath
        }
        return url.standardizedFileURL.path(percentEncoded: false)
    }

    private func ensureRetainedDirectoryIsInsideBase(_ directoryURL: URL, baseDirectory: URL) throws {
        let resolvedBasePath = directoryPath(normalizedPath(baseDirectory))
        let resolvedDirectoryPath = directoryPath(normalizedPath(directoryURL))
        guard resolvedDirectoryPath == resolvedBasePath || resolvedDirectoryPath.hasPrefix(resolvedBasePath + "/") else {
            throw DRCError.artifactWriteFailed(
                "retained artifact directory escapes the run directory: \(directoryURL.path(percentEncoded: false))"
            )
        }
    }

    private func containmentRelativePath(for url: URL, baseDirectory: URL) -> String? {
        let resolvedBasePath = directoryPath(normalizedPath(baseDirectory))
        let resolvedArtifactPath = normalizedPath(url)
        guard resolvedArtifactPath.hasPrefix(resolvedBasePath + "/") else {
            return nil
        }
        return String(resolvedArtifactPath.dropFirst(resolvedBasePath.count + 1))
    }

    private func normalizedPath(_ url: URL) -> String {
        if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            return url
                .resolvingSymlinksInPath()
                .standardizedFileURL
                .path(percentEncoded: false)
        }
        let resolvedParent = url
            .deletingLastPathComponent()
            .resolvingSymlinksInPath()
            .standardizedFileURL
        return resolvedParent
            .appending(path: url.lastPathComponent)
            .standardizedFileURL
            .path(percentEncoded: false)
    }

    private func directoryPath(_ path: String) -> String {
        var result = path
        while result.count > 1 && result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }
}
