import Foundation
import DRCCore

public struct DRCArtifactStore: Sendable {
    public init() {}

    public func save(_ executionResult: DRCExecutionResult, to directory: URL) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let reportURL = directory.appending(path: "drc-report-\(UUID().uuidString).json")
            let data = try encoder.encode(executionResult)
            try data.write(to: reportURL, options: [.atomic])
            return reportURL
        } catch {
            throw DRCError.artifactWriteFailed(error.localizedDescription)
        }
    }
}
