import Foundation

public enum DRCMagicRuleImportCatalogInventoryStatus: String, Sendable, Hashable, Codable {
    case passed
    case failed
}

public struct DRCMagicRuleImportCatalogInventoryIssue: Sendable, Hashable, Codable {
    public var code: String
    public var message: String
    public var path: String?
    public var field: String?

    public init(
        code: String,
        message: String,
        path: String? = nil,
        field: String? = nil
    ) {
        self.code = code
        self.message = message
        self.path = path
        self.field = field
    }
}

public struct DRCMagicRuleImportCatalogRequiredFileInventory: Sendable, Hashable, Codable {
    public var purpose: String
    public var declaredPath: String
    public var resolvedPath: String
    public var exists: Bool
    public var status: DRCMagicRuleImportCatalogInventoryStatus
    public var issues: [DRCMagicRuleImportCatalogInventoryIssue]

    public init(
        purpose: String,
        declaredPath: String,
        resolvedPath: String,
        exists: Bool,
        status: DRCMagicRuleImportCatalogInventoryStatus,
        issues: [DRCMagicRuleImportCatalogInventoryIssue] = []
    ) {
        self.purpose = purpose
        self.declaredPath = declaredPath
        self.resolvedPath = resolvedPath
        self.exists = exists
        self.status = status
        self.issues = issues
    }
}

public struct DRCMagicRuleImportCatalogEntryInventory: Sendable, Hashable, Codable {
    public var technologyCatalogID: String
    public var pdkID: String
    public var profileIDs: [String]
    public var profileResourceName: String?
    public var profileResourceAvailable: Bool?
    public var requiredFiles: [DRCMagicRuleImportCatalogRequiredFileInventory]
    public var status: DRCMagicRuleImportCatalogInventoryStatus
    public var issues: [DRCMagicRuleImportCatalogInventoryIssue]

    public init(
        technologyCatalogID: String,
        pdkID: String,
        profileIDs: [String],
        profileResourceName: String? = nil,
        profileResourceAvailable: Bool? = nil,
        requiredFiles: [DRCMagicRuleImportCatalogRequiredFileInventory],
        status: DRCMagicRuleImportCatalogInventoryStatus,
        issues: [DRCMagicRuleImportCatalogInventoryIssue] = []
    ) {
        self.technologyCatalogID = technologyCatalogID
        self.pdkID = pdkID
        self.profileIDs = profileIDs
        self.profileResourceName = profileResourceName
        self.profileResourceAvailable = profileResourceAvailable
        self.requiredFiles = requiredFiles
        self.status = status
        self.issues = issues
    }
}

public struct DRCMagicRuleImportCatalogInventoryItem: Sendable, Hashable, Codable {
    public var catalogPath: String
    public var entryCount: Int
    public var entries: [DRCMagicRuleImportCatalogEntryInventory]
    public var status: DRCMagicRuleImportCatalogInventoryStatus
    public var issues: [DRCMagicRuleImportCatalogInventoryIssue]

    public init(
        catalogPath: String,
        entryCount: Int,
        entries: [DRCMagicRuleImportCatalogEntryInventory],
        status: DRCMagicRuleImportCatalogInventoryStatus,
        issues: [DRCMagicRuleImportCatalogInventoryIssue] = []
    ) {
        self.catalogPath = catalogPath
        self.entryCount = entryCount
        self.entries = entries
        self.status = status
        self.issues = issues
    }
}

public struct DRCMagicRuleImportCatalogRootInventory: Sendable, Hashable, Codable {
    public var pdkRootPath: String
    public var discoveredCatalogPaths: [String]
    public var status: DRCMagicRuleImportCatalogInventoryStatus
    public var issues: [DRCMagicRuleImportCatalogInventoryIssue]

    public init(
        pdkRootPath: String,
        discoveredCatalogPaths: [String],
        status: DRCMagicRuleImportCatalogInventoryStatus,
        issues: [DRCMagicRuleImportCatalogInventoryIssue] = []
    ) {
        self.pdkRootPath = pdkRootPath
        self.discoveredCatalogPaths = discoveredCatalogPaths
        self.status = status
        self.issues = issues
    }
}

public struct DRCMagicRuleImportCatalogInventory: Sendable, Hashable, Codable {
    public var schemaVersion: Int
    public var kind: String
    public var catalogCount: Int
    public var pdkRoots: [DRCMagicRuleImportCatalogRootInventory]
    public var catalogs: [DRCMagicRuleImportCatalogInventoryItem]
    public var status: DRCMagicRuleImportCatalogInventoryStatus
    public var issues: [DRCMagicRuleImportCatalogInventoryIssue]

    public init(
        schemaVersion: Int = 1,
        kind: String = "drc-magic-rule-import-catalog-inventory",
        catalogCount: Int,
        pdkRoots: [DRCMagicRuleImportCatalogRootInventory] = [],
        catalogs: [DRCMagicRuleImportCatalogInventoryItem],
        status: DRCMagicRuleImportCatalogInventoryStatus,
        issues: [DRCMagicRuleImportCatalogInventoryIssue] = []
    ) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.catalogCount = catalogCount
        self.pdkRoots = pdkRoots
        self.catalogs = catalogs
        self.status = status
        self.issues = issues
    }
}
