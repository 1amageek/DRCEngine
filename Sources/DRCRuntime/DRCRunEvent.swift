import Foundation
import DRCCore

public enum DRCRunEvent: Sendable {
    case started(at: Date)
    case stateChanged(DRCRunSessionState)
    case completed(DRCExecutionResult)
    case failed(message: String)
    case cancelled(reason: String)
}
