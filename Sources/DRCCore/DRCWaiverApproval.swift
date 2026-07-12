import Foundation

public struct DRCWaiverApproval: Sendable, Hashable, Codable {
    public let approvedBy: String
    public let approvedAt: String
    public let expiresAt: String?
    public let reference: String

    public init(
        approvedBy: String,
        approvedAt: String,
        expiresAt: String? = nil,
        reference: String
    ) {
        self.approvedBy = approvedBy
        self.approvedAt = approvedAt
        self.expiresAt = expiresAt
        self.reference = reference
    }

    public func validationMessage() -> String? {
        guard !approvedBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "approvedBy must not be empty."
        }
        guard !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "reference must not be empty."
        }
        guard let approvedDate = parseDate(approvedAt) else {
            return "approvedAt must be a valid ISO-8601 timestamp."
        }
        if let expiresAt {
            guard let expiresDate = parseDate(expiresAt) else {
                return "expiresAt must be a valid ISO-8601 timestamp."
            }
            guard expiresDate > approvedDate else {
                return "expiresAt must be later than approvedAt."
            }
        }
        return nil
    }

    public func isActive(at date: Date = Date()) -> Bool {
        guard validationMessage() == nil,
              let approvedDate = parseDate(approvedAt),
              approvedDate <= date else {
            return false
        }
        guard let expiresAt else { return true }
        guard let expiresDate = parseDate(expiresAt) else { return false }
        return date < expiresDate
    }

    private func parseDate(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}
