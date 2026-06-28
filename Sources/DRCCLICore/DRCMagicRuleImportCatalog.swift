import Foundation

public struct DRCMagicRuleImportCatalog: Sendable, Hashable, Codable {
    public struct Entry: Sendable, Hashable, Codable {
        public var technologyCatalogID: String
        public var pdkID: String
        public var profileIDs: [String]?
        public var requiredFiles: [RequiredFile]?
        public var metadata: [String: String]?

        public init(
            technologyCatalogID: String,
            pdkID: String,
            profileIDs: [String]? = nil,
            requiredFiles: [RequiredFile]? = nil,
            metadata: [String: String]? = nil
        ) {
            self.technologyCatalogID = technologyCatalogID
            self.pdkID = pdkID
            self.profileIDs = profileIDs
            self.requiredFiles = requiredFiles
            self.metadata = metadata
        }
    }

    public struct RequiredFile: Sendable, Hashable, Codable {
        public var purpose: String
        public var path: String
        public var description: String?

        public init(
            purpose: String,
            path: String,
            description: String? = nil
        ) {
            self.purpose = purpose
            self.path = path
            self.description = description
        }
    }

    public var schemaVersion: Int
    public var entries: [Entry]

    public init(
        schemaVersion: Int = 1,
        entries: [Entry]
    ) {
        self.schemaVersion = schemaVersion
        self.entries = entries
    }
}
