import Foundation
import Testing
import DRCCLICore

extension DRCCLIOptionsTests {
    @Test func magicRuleImportCatalogInventoryRejectsStructurallyInvalidCatalog() throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let catalogURL = root.appending(path: "magic-rule-import-catalog.json")
        let catalog = DRCMagicRuleImportCatalog(
            entries: [
                DRCMagicRuleImportCatalog.Entry(
                    technologyCatalogID: "",
                    pdkID: "sky130A",
                    profileIDs: ["duplicate", "duplicate"],
                    requiredFiles: [
                        DRCMagicRuleImportCatalog.RequiredFile(purpose: "", path: ""),
                        DRCMagicRuleImportCatalog.RequiredFile(purpose: "magic-drc-tech", path: "deck.tech"),
                        DRCMagicRuleImportCatalog.RequiredFile(purpose: "magic-drc-tech", path: "deck2.tech"),
                    ]
                ),
            ]
        )
        try writeJSON(catalog, to: catalogURL)

        let inventory = DRCMagicRuleImportCatalogInventoryBuilder().build(
            catalogURLs: [catalogURL]
        )

        #expect(inventory.status == .failed)
        let item = try #require(inventory.catalogs.first)
        #expect(item.status == .failed)
        #expect(item.issues.contains { $0.code == "invalid-technology-catalog-id" })
        #expect(item.issues.contains { $0.code == "duplicate-profile-id" })
        #expect(item.issues.contains { $0.code == "duplicate-required-file-purpose" })
        #expect(item.entries.count == 1)

        #expect(throws: DRCCLIError.self) {
            _ = try DRCMagicRuleImportCatalogResolver(catalogURL: catalogURL).resolve(
                selection: DRCMagicRuleImportCatalogResolver.Selection(),
                requireProfileReference: false
            )
        }
    }

    @Test func magicRuleImportCatalogInventoryRejectsRequiredFileOutsidePDKRoot() throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let pdkRoot = root.appending(path: "pdk")
        let outsideTechURL = root.appending(path: "outside/sky130A.tech")
        try writeText("drc\nend\n", to: outsideTechURL)
        let catalogURL = try writeMagicRuleImportCatalog(
            root: pdkRoot,
            requiredFilePath: "../outside/sky130A.tech"
        )

        let inventory = DRCMagicRuleImportCatalogInventoryBuilder().build(
            catalogURLs: [catalogURL],
            pdkRootURLs: [pdkRoot]
        )

        #expect(inventory.status == .failed)
        let requiredFile = try #require(inventory.catalogs.first?.entries.first?.requiredFiles.first)
        #expect(requiredFile.exists)
        #expect(requiredFile.status == .failed)
        #expect(requiredFile.issues.contains { $0.code == "required-file-outside-pdk-root" })

        let error = try captureError {
            _ = try DRCMagicRuleImportCatalogResolver(
                catalogURL: catalogURL,
                pdkRootURL: pdkRoot
            ).resolve(
                selection: DRCMagicRuleImportCatalogResolver.Selection(
                    technologyCatalogID: "sky130-open-pdk"
                ),
                requireProfileReference: false
            )
        }
        #expect(error == .invalidValue(
            argument: "--catalog",
            value: "../outside/sky130A.tech",
            expected: "required file for purpose magic-drc-tech inside PDK root"
        ))
    }

    @Test func magicRuleImportCatalogInventorySkipsSymlinkedDiscoveryPath() throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let pdkRoot = root.appending(path: "pdk")
        let externalRoot = root.appending(path: "external")
        try FileManager.default.createDirectory(at: pdkRoot, withIntermediateDirectories: true)
        _ = try writeMagicRuleImportCatalog(root: externalRoot)
        try FileManager.default.createSymbolicLink(
            at: pdkRoot.appending(path: "linked"),
            withDestinationURL: externalRoot
        )

        let inventory = DRCMagicRuleImportCatalogInventoryBuilder().build(
            catalogURLs: [],
            pdkRootURLs: [pdkRoot]
        )

        #expect(inventory.status == .failed)
        #expect(inventory.catalogCount == 0)
        #expect(inventory.pdkRoots.first?.discoveredCatalogPaths.isEmpty == true)
        #expect(inventory.pdkRoots.first?.issues.contains {
            $0.code == "catalog-discovery-symlink-skipped"
        } == true)
        #expect(inventory.pdkRoots.first?.issues.contains { $0.code == "no-catalogs-found" } == true)
    }

    @Test func magicRuleImportCatalogInventoryReportsDiscoveryLimit() throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        try writeImportableMagicDRCDeck(root: root)
        _ = try writeMagicRuleImportCatalog(root: root, catalogPath: "a/magic-rule-import-catalog.json")
        _ = try writeMagicRuleImportCatalog(root: root, catalogPath: "b/magic-rule-import-catalog.json")

        let inventory = DRCMagicRuleImportCatalogInventoryBuilder(
            maxDiscoveredCatalogsPerRoot: 1
        ).build(
            catalogURLs: [],
            pdkRootURLs: [root]
        )

        #expect(inventory.status == .failed)
        #expect(inventory.catalogCount == 1)
        #expect(inventory.pdkRoots.first?.discoveredCatalogPaths.count == 1)
        #expect(inventory.pdkRoots.first?.issues.contains {
            $0.code == "catalog-discovery-limit-reached"
        } == true)
    }

    @Test func magicRuleImportCatalogInventoryRejectsFilePDKRoot() throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let fileURL = root.appending(path: "not-a-directory")
        try writeText("not a directory", to: fileURL)

        let inventory = DRCMagicRuleImportCatalogInventoryBuilder().build(
            catalogURLs: [],
            pdkRootURLs: [fileURL]
        )

        #expect(inventory.status == .failed)
        #expect(inventory.catalogCount == 0)
        #expect(inventory.pdkRoots.first?.issues == [
            DRCMagicRuleImportCatalogInventoryIssue(
                code: "pdk-root-not-directory",
                message: "PDK root must be a directory.",
                path: fileURL.path(percentEncoded: false)
            ),
        ])
    }

    @Test func magicRuleImportCatalogInventoryCLIEmitsStructuredFailure() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }

        let invocation = await DRCCLI.invoke(arguments: [
            "--inspect-magic-rule-import-catalog",
            "--pdk-root", root.path(percentEncoded: false),
            "--require-passed",
            "--json",
        ])

        #expect(invocation.exitCode == 2)
        let inventory = try JSONDecoder().decode(
            DRCMagicRuleImportCatalogInventory.self,
            from: Data(invocation.standardOutput.utf8)
        )
        #expect(inventory.status == .failed)
        #expect(inventory.catalogCount == 0)
        #expect(inventory.issues.contains { $0.code == "no-catalogs-found" })
        #expect(inventory.pdkRoots.first?.issues.contains { $0.code == "no-catalogs-found" } == true)
    }
}
