import Foundation
import DRCEngine

public struct DRCMagicRuleImportCatalogResolver: Sendable {
    public struct Selection: Sendable, Hashable {
        public var technologyCatalogID: String?
        public var pdkID: String?
        public var profileID: String?

        public init(
            technologyCatalogID: String? = nil,
            pdkID: String? = nil,
            profileID: String? = nil
        ) {
            self.technologyCatalogID = technologyCatalogID
            self.pdkID = pdkID
            self.profileID = profileID
        }
    }

    public struct ResolvedImport: Sendable, Hashable {
        public var magicTechURL: URL
        public var profileURL: URL?
        public var profileResourceName: String?
        public var technologyCatalogID: String
        public var pdkID: String
        public var profileID: String?

        public init(
            magicTechURL: URL,
            profileURL: URL? = nil,
            profileResourceName: String? = nil,
            technologyCatalogID: String,
            pdkID: String,
            profileID: String? = nil
        ) {
            self.magicTechURL = magicTechURL
            self.profileURL = profileURL
            self.profileResourceName = profileResourceName
            self.technologyCatalogID = technologyCatalogID
            self.pdkID = pdkID
            self.profileID = profileID
        }
    }

    public let catalogURL: URL
    public let pdkRootURL: URL?

    public init(catalogURL: URL, pdkRootURL: URL? = nil) {
        self.catalogURL = catalogURL
        self.pdkRootURL = pdkRootURL
    }

    public func resolve(
        selection: Selection,
        requireProfileReference: Bool = true
    ) throws -> ResolvedImport {
        let catalog = try loadCatalog()
        let entry = try selectEntry(from: catalog, selection: selection)
        let magicTechURL = try resolveRequiredFileURL(
            in: entry,
            purposes: ["magic-drc-tech", "magic-tech"],
            missingArgument: "--catalog magic-drc-tech"
        )
        let profileURL = try resolveOptionalRequiredFileURL(
            in: entry,
            purposes: ["magic-layouttech-profile"]
        )
        let profileResourceName = entry.metadata?["magicLayoutTechProfileResource"]
            ?? entry.metadata?["magic-layouttech-profile-resource"]
        if requireProfileReference && profileURL == nil && profileResourceName == nil {
            throw DRCCLIError.missingRequired("--profile, --profile-resource, or catalog magic-layouttech-profile")
        }
        if let profileResourceName {
            _ = try MagicDRCLayoutTechImportProfile.bundledMagicLayoutTechProfileURL(
                resourceName: profileResourceName
            )
        }

        return ResolvedImport(
            magicTechURL: magicTechURL,
            profileURL: profileURL,
            profileResourceName: profileResourceName,
            technologyCatalogID: entry.technologyCatalogID,
            pdkID: entry.pdkID,
            profileID: selection.profileID ?? entry.profileIDs?.first
        )
    }

    private func loadCatalog() throws -> DRCMagicRuleImportCatalog {
        let data = try Data(contentsOf: catalogURL)
        let catalog = try JSONDecoder().decode(DRCMagicRuleImportCatalog.self, from: data)
        guard catalog.schemaVersion == 1 else {
            throw DRCCLIError.invalidValue(
                argument: "--catalog",
                value: "\(catalog.schemaVersion)",
                expected: "schemaVersion 1"
            )
        }
        return catalog
    }

    private func selectEntry(
        from catalog: DRCMagicRuleImportCatalog,
        selection: Selection
    ) throws -> DRCMagicRuleImportCatalog.Entry {
        let matches = catalog.entries.filter { entry in
            if let technologyCatalogID = selection.technologyCatalogID,
               entry.technologyCatalogID != technologyCatalogID {
                return false
            }
            if let pdkID = selection.pdkID,
               entry.pdkID != pdkID {
                return false
            }
            if let profileID = selection.profileID {
                guard let profileIDs = entry.profileIDs,
                      profileIDs.contains(profileID) else {
                    return false
                }
            }
            return true
        }
        guard matches.count == 1, let match = matches.first else {
            throw DRCCLIError.invalidValue(
                argument: "--catalog",
                value: catalogURL.path(percentEncoded: false),
                expected: matches.isEmpty ? "one matching catalog entry" : "selectors that resolve exactly one catalog entry"
            )
        }
        return match
    }

    private func resolveRequiredFileURL(
        in entry: DRCMagicRuleImportCatalog.Entry,
        purposes: [String],
        missingArgument: String
    ) throws -> URL {
        guard let url = try resolveOptionalRequiredFileURL(in: entry, purposes: purposes) else {
            throw DRCCLIError.missingRequired(missingArgument)
        }
        return url
    }

    private func resolveOptionalRequiredFileURL(
        in entry: DRCMagicRuleImportCatalog.Entry,
        purposes: [String]
    ) throws -> URL? {
        let matches = (entry.requiredFiles ?? []).filter { purposes.contains($0.purpose) }
        guard matches.count <= 1 else {
            throw DRCCLIError.invalidValue(
                argument: "--catalog",
                value: entry.technologyCatalogID,
                expected: "at most one required file for \(purposes.joined(separator: " or "))"
            )
        }
        guard let match = matches.first else { return nil }
        let url = try resolvedURL(for: match.path, purpose: match.purpose)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            throw DRCCLIError.invalidValue(
                argument: "--catalog",
                value: match.path,
                expected: "existing required file for purpose \(match.purpose)"
            )
        }
        return url
    }

    private func resolvedURL(for path: String, purpose: String) throws -> URL {
        let url: URL
        if path.hasPrefix("/") {
            url = URL(filePath: path)
        } else if let pdkRootURL {
            let pdkRelativeURL = pdkRootURL.appending(path: path)
            if FileManager.default.fileExists(atPath: pdkRelativeURL.path(percentEncoded: false)) {
                url = pdkRelativeURL
            } else {
                url = catalogURL.deletingLastPathComponent().appending(path: path)
            }
        } else {
            url = catalogURL.deletingLastPathComponent().appending(path: path)
        }

        if let pdkRootURL {
            let resolvedPath = url.standardizedFileURL.resolvingSymlinksInPath().path(percentEncoded: false)
            let rootPath = pdkRootURL.standardizedFileURL.resolvingSymlinksInPath().path(percentEncoded: false)
            guard isPath(resolvedPath, insideOrEqualTo: rootPath) else {
                throw DRCCLIError.invalidValue(
                    argument: "--catalog",
                    value: path,
                    expected: "required file for purpose \(purpose) inside PDK root"
                )
            }
        }

        return url
    }

    private func isPath(_ path: String, insideOrEqualTo rootPath: String) -> Bool {
        let normalizedRoot = rootPath.hasSuffix("/")
            ? String(rootPath.dropLast())
            : rootPath
        return path == normalizedRoot || path.hasPrefix("\(normalizedRoot)/")
    }
}
