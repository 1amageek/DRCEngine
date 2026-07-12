import Foundation
import DRCCore

public enum DRCCorpusRunEvent: Sendable {
    case started(runID: String, caseCount: Int, resumedFromRunID: String?)
    case caseStarted(caseID: String, index: Int)
    case caseResumed(caseID: String, index: Int)
    case caseCompleted(caseID: String, index: Int, result: DRCCorpusCaseResult)
    case checkpointWritten(URL)
    case completed(DRCCorpusReport)
    case cancelled(runID: String)
}

public typealias DRCCorpusRunEventHandler = @Sendable (DRCCorpusRunEvent) async -> Void
