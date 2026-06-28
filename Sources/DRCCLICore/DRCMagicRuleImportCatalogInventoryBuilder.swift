import Foundation
import DRCEngine

public struct DRCMagicRuleImportCatalogInventoryBuilder: Sendable {
    private struct CatalogSource: Sendable, Hashable {
        var catalogURL: URL
        var pdkRootURL: URL?
    }

    public let maxDiscoveryDepth: Int
    public let maxDiscoveredCatalogsPerRoot: Int

    public init(
        maxDiscoveryDepth: Int = 5,
        maxDiscoveredCatalogsPerRoot: Int = 64
    ) {
        self.maxDiscoveryDepth = maxDiscoveryDepth
        self.maxDiscoveredCatalogsPerRoot = maxDiscoveredCatalogsPerRoot
    }

    public func build(
        catalogURLs: [URL],
        pdkRootURLs: [URL] = []
    ) -> DRCMagicRuleImportCatalogInventory {
        var rootInventories: [DRCMagicRuleImportCatalogRootInventory] = []
        var discoveredCatalogSources: [CatalogSource] = []
        for pdkRootURL in pdkRootURLs {
            let discovery = discoverCatalogs(in: pdkRootURL, requireCatalog: catalogURLs.isEmpty)
            rootInventories.append(discovery.inventory)
            discoveredCatalogSources.append(contentsOf: discovery.catalogURLs.map {
                CatalogSource(catalogURL: $0, pdkRootURL: pdkRootURL)
            })
        }

        let explicitCatalogSources = catalogURLs.map {
            CatalogSource(catalogURL: $0, pdkRootURL: pdkRootURL(for: $0, pdkRootURLs: pdkRootURLs))
        }
        let allCatalogSources = deduplicated(explicitCatalogSources + discoveredCatalogSources)
        var issues: [DRCMagicRuleImportCatalogInventoryIssue] = []
        if allCatalogSources.isEmpty {
            issues.append(DRCMagicRuleImportCatalogInventoryIssue(
                code: "no-catalogs-found",
                message: "No Magic rule import catalogs were provided or discovered."
            ))
        }

        let catalogInventories = allCatalogSources.map { inventory(for: $0) }
        issues.append(contentsOf: rootInventories.flatMap(\.issues))
        let status: DRCMagicRuleImportCatalogInventoryStatus = issues.isEmpty
            && catalogInventories.allSatisfy { $0.status == .passed }
            ? .passed
            : .failed
        return DRCMagicRuleImportCatalogInventory(
            catalogCount: catalogInventories.count,
            pdkRoots: rootInventories,
            catalogs: catalogInventories,
            status: status,
            issues: issues
        )
    }

    private func inventory(for source: CatalogSource) -> DRCMagicRuleImportCatalogInventoryItem {
        let catalogURL = source.catalogURL
        let catalogPath = catalogURL.path(percentEncoded: false)
        do {
            let data = try Data(contentsOf: catalogURL)
            let catalog = try JSONDecoder().decode(DRCMagicRuleImportCatalog.self, from: data)
            guard catalog.schemaVersion == 1 else {
                let issue = DRCMagicRuleImportCatalogInventoryIssue(
                    code: "unsupported-schema-version",
                    message: "Magic rule import catalog schemaVersion must be 1.",
                    path: catalogPath,
                    field: "schemaVersion"
                )
                return DRCMagicRuleImportCatalogInventoryItem(
                    catalogPath: catalogPath,
                    entryCount: catalog.entries.count,
                    entries: [],
                    status: .failed,
                    issues: [issue]
                )
            }
            let entries = catalog.entries.map {
                entryInventory($0, catalogURL: catalogURL, pdkRootURL: source.pdkRootURL)
            }
            let status: DRCMagicRuleImportCatalogInventoryStatus = entries.allSatisfy { $0.status == .passed }
                ? .passed
                : .failed
            return DRCMagicRuleImportCatalogInventoryItem(
                catalogPath: catalogPath,
                entryCount: entries.count,
                entries: entries,
                status: status
            )
        } catch {
            let issue = DRCMagicRuleImportCatalogInventoryIssue(
                code: "catalog-read-failed",
                message: "Magic rule import catalog could not be read or decoded: \(error.localizedDescription)",
                path: catalogPath
            )
            return DRCMagicRuleImportCatalogInventoryItem(
                catalogPath: catalogPath,
                entryCount: 0,
                entries: [],
                status: .failed,
                issues: [issue]
            )
        }
    }

    private func entryInventory(
        _ entry: DRCMagicRuleImportCatalog.Entry,
        catalogURL: URL,
        pdkRootURL: URL?
    ) -> DRCMagicRuleImportCatalogEntryInventory {
        let requiredFiles = (entry.requiredFiles ?? []).map {
            requiredFileInventory($0, catalogURL: catalogURL, pdkRootURL: pdkRootURL)
        }
        var issues = requiredFiles.flatMap(\.issues)
        let profileResourceName = entry.metadata?["magicLayoutTechProfileResource"]
            ?? entry.metadata?["magic-layouttech-profile-resource"]
        let profileResourceAvailable: Bool?
        if let profileResourceName {
            do {
                _ = try MagicDRCLayoutTechImportProfile.bundledMagicLayoutTechProfileURL(
                    resourceName: profileResourceName
                )
                profileResourceAvailable = true
            } catch {
                profileResourceAvailable = false
                issues.append(DRCMagicRuleImportCatalogInventoryIssue(
                    code: "profile-resource-missing",
                    message: "Bundled Magic LayoutTech profile resource could not be found.",
                    field: "metadata.magicLayoutTechProfileResource"
                ))
            }
        } else {
            profileResourceAvailable = nil
        }

        let hasMagicTech = requiredFiles.contains {
            ["magic-drc-tech", "magic-tech"].contains($0.purpose) && $0.exists
        }
        if !hasMagicTech {
            issues.append(DRCMagicRuleImportCatalogInventoryIssue(
                code: "magic-tech-missing",
                message: "Catalog entry must provide an existing Magic DRC tech file.",
                field: "requiredFiles.magic-drc-tech"
            ))
        }
        let hasProfileFile = requiredFiles.contains {
            $0.purpose == "magic-layouttech-profile" && $0.exists
        }
        if !hasProfileFile && profileResourceAvailable != true {
            issues.append(DRCMagicRuleImportCatalogInventoryIssue(
                code: "profile-reference-missing",
                message: "Catalog entry must provide a profile file or bundled profile resource.",
                field: "requiredFiles.magic-layouttech-profile"
            ))
        }

        return DRCMagicRuleImportCatalogEntryInventory(
            technologyCatalogID: entry.technologyCatalogID,
            pdkID: entry.pdkID,
            profileIDs: entry.profileIDs ?? [],
            profileResourceName: profileResourceName,
            profileResourceAvailable: profileResourceAvailable,
            requiredFiles: requiredFiles,
            status: issues.isEmpty ? .passed : .failed,
            issues: issues
        )
    }

    private func requiredFileInventory(
        _ requiredFile: DRCMagicRuleImportCatalog.RequiredFile,
        catalogURL: URL,
        pdkRootURL: URL?
    ) -> DRCMagicRuleImportCatalogRequiredFileInventory {
        let resolvedURL = resolvedURL(for: requiredFile.path, catalogURL: catalogURL, pdkRootURL: pdkRootURL)
        let resolvedPath = resolvedURL.path(percentEncoded: false)
        let exists = FileManager.default.fileExists(atPath: resolvedPath)
        let issue = exists ? nil : DRCMagicRuleImportCatalogInventoryIssue(
            code: "required-file-missing",
            message: "Catalog required file is missing.",
            path: resolvedPath,
            field: "requiredFiles.\(requiredFile.purpose)"
        )
        return DRCMagicRuleImportCatalogRequiredFileInventory(
            purpose: requiredFile.purpose,
            declaredPath: requiredFile.path,
            resolvedPath: resolvedPath,
            exists: exists,
            status: exists ? .passed : .failed,
            issues: issue.map { [$0] } ?? []
        )
    }

    private func discoverCatalogs(
        in pdkRootURL: URL,
        requireCatalog: Bool
    ) -> (inventory: DRCMagicRuleImportCatalogRootInventory, catalogURLs: [URL]) {
        let rootPath = pdkRootURL.path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: rootPath) else {
            let issue = DRCMagicRuleImportCatalogInventoryIssue(
                code: "pdk-root-missing",
                message: "PDK root does not exist.",
                path: rootPath
            )
            return (
                DRCMagicRuleImportCatalogRootInventory(
                    pdkRootPath: rootPath,
                    discoveredCatalogPaths: [],
                    status: .failed,
                    issues: [issue]
                ),
                []
            )
        }

        var discovered: [URL] = []
        var issues: [DRCMagicRuleImportCatalogInventoryIssue] = []
        var queue: [(url: URL, depth: Int)] = [(pdkRootURL, 0)]
        while !queue.isEmpty && discovered.count < maxDiscoveredCatalogsPerRoot {
            let next = queue.removeFirst()
            guard next.depth <= maxDiscoveryDepth else { continue }
            let children: [URL]
            do {
                children = try FileManager.default.contentsOfDirectory(
                    at: next.url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
            } catch {
                issues.append(DRCMagicRuleImportCatalogInventoryIssue(
                    code: "catalog-discovery-read-failed",
                    message: "Directory could not be read during catalog discovery: \(error.localizedDescription)",
                    path: next.url.path(percentEncoded: false)
                ))
                continue
            }
            for child in children.sorted(by: { $0.path(percentEncoded: false) < $1.path(percentEncoded: false) }) {
                if child.lastPathComponent == "magic-rule-import-catalog.json" {
                    discovered.append(child)
                    continue
                }
                do {
                    let values = try child.resourceValues(forKeys: [.isDirectoryKey])
                    guard values.isDirectory == true else { continue }
                    queue.append((child, next.depth + 1))
                } catch {
                    issues.append(DRCMagicRuleImportCatalogInventoryIssue(
                        code: "catalog-discovery-resource-failed",
                        message: "Path metadata could not be read during catalog discovery: \(error.localizedDescription)",
                        path: child.path(percentEncoded: false)
                    ))
                }
            }
        }

        let paths = discovered.map { $0.path(percentEncoded: false) }
        if paths.isEmpty && requireCatalog {
            issues.append(DRCMagicRuleImportCatalogInventoryIssue(
                code: "no-catalogs-found",
                message: "No magic-rule-import-catalog.json files were discovered under the PDK root.",
                path: rootPath
            ))
        }
        return (
            DRCMagicRuleImportCatalogRootInventory(
                pdkRootPath: rootPath,
                discoveredCatalogPaths: paths,
                status: issues.isEmpty ? .passed : .failed,
                issues: issues
            ),
            discovered
        )
    }

    private func pdkRootURL(for catalogURL: URL, pdkRootURLs: [URL]) -> URL? {
        let standardizedCatalogPath = catalogURL.standardizedFileURL.path(percentEncoded: false)
        let matchingRoots = pdkRootURLs
            .map(\.standardizedFileURL)
            .filter {
                isPath(standardizedCatalogPath, insideOrEqualTo: $0.path(percentEncoded: false))
            }
            .sorted {
                $0.path(percentEncoded: false).count > $1.path(percentEncoded: false).count
            }
        if let matchedRoot = matchingRoots.first {
            return matchedRoot
        }
        return pdkRootURLs.count == 1 ? pdkRootURLs.first : nil
    }

    private func isPath(_ path: String, insideOrEqualTo rootPath: String) -> Bool {
        let normalizedRoot = rootPath.hasSuffix("/")
            ? String(rootPath.dropLast())
            : rootPath
        return path == normalizedRoot || path.hasPrefix("\(normalizedRoot)/")
    }

    private func resolvedURL(for path: String, catalogURL: URL, pdkRootURL: URL?) -> URL {
        if path.hasPrefix("/") {
            return URL(filePath: path)
        }
        if let pdkRootURL {
            let pdkRelativeURL = pdkRootURL.appending(path: path)
            if FileManager.default.fileExists(atPath: pdkRelativeURL.path(percentEncoded: false)) {
                return pdkRelativeURL
            }
        }
        return catalogURL.deletingLastPathComponent().appending(path: path)
    }

    private func deduplicated(_ sources: [CatalogSource]) -> [CatalogSource] {
        var seen: Set<String> = []
        var result: [CatalogSource] = []
        for source in sources {
            let path = source.catalogURL.standardizedFileURL.path(percentEncoded: false)
            if seen.insert(path).inserted {
                result.append(source)
            } else if
                let index = result.firstIndex(where: {
                    $0.catalogURL.standardizedFileURL.path(percentEncoded: false) == path
                }),
                result[index].pdkRootURL == nil,
                source.pdkRootURL != nil
            {
                result[index] = source
            }
        }
        return result
    }
}
