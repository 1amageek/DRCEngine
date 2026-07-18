import Foundation
import Testing
import DRCCore
import DRCCLICore
import DRCFoundryImport
import DRCNative
import LayoutCore
import LayoutTech
import SignoffToolSupport


extension DRCCLIOptionsTests {
    @Test func actionDomainOptionsParseJSONFlag() throws {
        let options = try DRCActionDomainCLIOptions(arguments: ["--action-domain", "--json"])

        #expect(options.emitJSON)
    }

    @Test func capabilityOptionsParseJSONFlag() throws {
        let options = try DRCCapabilityCLIOptions(arguments: ["--capabilities", "--json"])

        #expect(options.emitJSON)
    }

    @Test func foundryDeckSemanticOptionsParsePDKRootAndRequirePassed() throws {
        let options = try DRCFoundryDeckSemanticCLIOptions(arguments: [
            "--foundry-deck-semantics",
            "--pdk-root", "/tmp/pdks",
            "--require-passed",
            "--json",
        ])

        #expect(options.pdkRoot == "/tmp/pdks")
        #expect(options.requirePassed)
        #expect(options.emitJSON)
        #expect(options.environment(overriding: [:])["PDK_ROOT"] == "/tmp/pdks")
    }

    @Test func foundryRuleImportOptionsParseOutputsAndCompletionGate() throws {
        let options = try DRCFoundryRuleImportCLIOptions(arguments: [
            "--import-foundry-magic-rules",
            "--pdk-root", "/tmp/pdks",
            "--tech-out", "/tmp/foundry-layout-tech.json",
            "--report-out", "/tmp/foundry-rule-import.json",
            "--native-antenna-out", "/tmp/foundry-native-antenna-artifact.json",
            "--require-complete",
            "--json",
        ])

        #expect(options.pdkRoot == "/tmp/pdks")
        #expect(options.technologyOutputURL.path(percentEncoded: false) == "/tmp/foundry-layout-tech.json")
        #expect(options.reportOutputURL?.path(percentEncoded: false) == "/tmp/foundry-rule-import.json")
        #expect(options.nativeAntennaOutputURL?.path(percentEncoded: false) == "/tmp/foundry-native-antenna-artifact.json")
        #expect(options.requireComplete)
        #expect(options.emitJSON)
        #expect(options.environment(overriding: [:])["PDK_ROOT"] == "/tmp/pdks")
    }

    @Test func nativeAntennaAssessmentOptionsParseInputs() throws {
        let options = try DRCNativeAntennaAssessmentCLIOptions(arguments: [
            "--assess-native-antenna",
            "--native-antenna-artifact", "/tmp/native-antenna-artifact.json",
            "--oracle-evidence", "/tmp/magic-oracle-evidence.json",
            "--out", "/tmp/native-antenna-qualified.json",
            "--json",
        ])

        #expect(options.artifactURL.path(percentEncoded: false) == "/tmp/native-antenna-artifact.json")
        #expect(options.oracleEvidenceURL.path(percentEncoded: false) == "/tmp/magic-oracle-evidence.json")
        #expect(options.outputURL.path(percentEncoded: false) == "/tmp/native-antenna-qualified.json")
        #expect(options.emitJSON)
    }

    @Test func foundryRuleImportOptionsRejectRemovedSky130Alias() throws {
        #expect(throws: DRCCLIError.self) {
            try DRCFoundryRuleImportCLIOptions(arguments: [
                "--import-sky130-magic-rules",
                "--tech-out", "/tmp/layout-tech.json",
            ])
        }
    }

    @Test func magicRuleImportOptionsParseProfileAndOutputs() throws {
        let options = try DRCMagicRuleImportCLIOptions(arguments: [
            "--import-magic-rules",
            "--magic-tech", "/tmp/pdk/libs.tech/magic/generic.tech",
            "--profile", "/tmp/pdk/profile.json",
            "--tech-out", "/tmp/layout-tech.json",
            "--report-out", "/tmp/rule-import.json",
            "--native-antenna-out", "/tmp/native-antenna-rules.json",
            "--require-complete",
            "--json",
        ])

        #expect(options.magicTechURL.path(percentEncoded: false) == "/tmp/pdk/libs.tech/magic/generic.tech")
        #expect(options.profileURL.path(percentEncoded: false) == "/tmp/pdk/profile.json")
        #expect(options.technologyOutputURL.path(percentEncoded: false) == "/tmp/layout-tech.json")
        #expect(options.reportOutputURL?.path(percentEncoded: false) == "/tmp/rule-import.json")
        #expect(options.nativeAntennaOutputURL?.path(percentEncoded: false) == "/tmp/native-antenna-rules.json")
        #expect(options.requireComplete)
        #expect(options.emitJSON)
    }

    @Test func magicRuleImportOptionsParseBundledProfileResource() throws {
        let options = try DRCMagicRuleImportCLIOptions(arguments: [
            "--import-magic-rules",
            "--magic-tech", "/tmp/pdk/libs.tech/magic/process.tech",
            "--profile-resource", "sky130-magic-layouttech-profile",
            "--tech-out", "/tmp/layout-tech.json",
        ])

        #expect(options.magicTechURL.path(percentEncoded: false) == "/tmp/pdk/libs.tech/magic/process.tech")
        #expect(options.profileURL.lastPathComponent == "sky130-magic-layouttech-profile.json")
        #expect(options.profileResourceName == "sky130-magic-layouttech-profile")
        #expect(options.technologyOutputURL.path(percentEncoded: false) == "/tmp/layout-tech.json")
    }

    @Test func magicRuleImportCatalogInventoryOptionsParseInputs() throws {
        let options = try DRCMagicRuleImportCatalogInventoryCLIOptions(arguments: [
            "--inspect-magic-rule-import-catalog",
            "--catalog", "/tmp/pdk/tech/magic-rule-import-catalog.json",
            "--pdk-root", "/tmp/pdk",
            "--out", "/tmp/catalog-inventory.json",
            "--require-passed",
            "--json",
        ])

        #expect(options.catalogURLs.map { $0.path(percentEncoded: false) } == [
            "/tmp/pdk/tech/magic-rule-import-catalog.json",
        ])
        #expect(options.pdkRootURLs.map { $0.path(percentEncoded: false) } == ["/tmp/pdk"])
        #expect(options.outputURL?.path(percentEncoded: false) == "/tmp/catalog-inventory.json")
        #expect(options.requirePassed)
        #expect(options.emitJSON)
    }

    @Test func magicRuleImportOptionsResolveCatalogEntry() throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        try writeImportableMagicDRCDeck(root: root)
        let catalogURL = try writeMagicRuleImportCatalog(root: root)

        let options = try DRCMagicRuleImportCLIOptions(arguments: [
            "--import-magic-rules",
            "--catalog", catalogURL.path(percentEncoded: false),
            "--catalog-id", "sky130-open-pdk",
            "--pdk-id", "sky130A",
            "--profile-id", "sky130.magic.layouttech",
            "--pdk-root", root.path(percentEncoded: false),
            "--tech-out", "/tmp/layout-tech.json",
        ])

        #expect(options.magicTechURL.path(percentEncoded: false).hasSuffix("sky130A/libs.tech/magic/sky130A.tech"))
        #expect(options.profileURL.lastPathComponent == "sky130-magic-layouttech-profile.json")
        #expect(options.profileResourceName == "sky130-magic-layouttech-profile")
        #expect(options.catalogURL?.path(percentEncoded: false) == catalogURL.path(percentEncoded: false))
        #expect(options.technologyCatalogID == "sky130-open-pdk")
        #expect(options.pdkID == "sky130A")
        #expect(options.profileID == "sky130.magic.layouttech")
    }

    @Test func magicRuleImportCatalogInventoryDiscoversPDKRootCatalog() throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        try writeImportableMagicDRCDeck(root: root)
        _ = try writeMagicRuleImportCatalog(root: root)

        let inventory = DRCMagicRuleImportCatalogInventoryBuilder().build(
            catalogURLs: [],
            pdkRootURLs: [root]
        )

        #expect(inventory.status == .passed)
        #expect(inventory.catalogCount == 1)
        #expect(inventory.pdkRoots.first?.discoveredCatalogPaths.count == 1)
        #expect(inventory.pdkRoots.first?.discoveredCatalogPaths.first?.hasSuffix(
            "/tech/magic-rule-import-catalog.json"
        ) == true)
        let catalog = try #require(inventory.catalogs.first)
        #expect(catalog.status == .passed)
        let entry = try #require(catalog.entries.first)
        #expect(entry.technologyCatalogID == "sky130-open-pdk")
        #expect(entry.pdkID == "sky130A")
        #expect(entry.profileResourceName == "sky130-magic-layouttech-profile")
        #expect(entry.profileResourceAvailable == true)
        #expect(entry.requiredFiles.first?.exists == true)
    }

    @Test func magicRuleImportCatalogInventoryUsesPDKRootForExplicitCatalogRequiredFiles() throws {
        let pdkRoot = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(pdkRoot) }
        let catalogRoot = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(catalogRoot) }
        try writeImportableMagicDRCDeck(root: pdkRoot)
        let catalogURL = try writeMagicRuleImportCatalog(root: catalogRoot)

        let inventory = DRCMagicRuleImportCatalogInventoryBuilder().build(
            catalogURLs: [catalogURL],
            pdkRootURLs: [pdkRoot]
        )

        #expect(inventory.status == .passed)
        #expect(inventory.catalogCount == 1)
        #expect(inventory.pdkRoots.first?.status == .passed)
        #expect(inventory.pdkRoots.first?.discoveredCatalogPaths.isEmpty == true)
        let requiredFile = try #require(inventory.catalogs.first?.entries.first?.requiredFiles.first)
        #expect(requiredFile.exists)
        #expect(requiredFile.resolvedPath.hasSuffix("sky130A/libs.tech/magic/sky130A.tech"))
    }

    @Test func magicRuleImportCatalogInventoryCLIWritesReport() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        try writeImportableMagicDRCDeck(root: root)
        _ = try writeMagicRuleImportCatalog(root: root)
        let inventoryURL = root.appending(path: "outputs/magic-rule-import-catalog-inventory.json")

        let exitCode = await DRCCLI.run(arguments: [
            "--inspect-magic-rule-import-catalog",
            "--pdk-root", root.path(percentEncoded: false),
            "--out", inventoryURL.path(percentEncoded: false),
            "--require-passed",
            "--json",
        ])

        #expect(exitCode == 0)
        let inventory = try JSONDecoder().decode(
            DRCMagicRuleImportCatalogInventory.self,
            from: Data(contentsOf: inventoryURL)
        )
        #expect(inventory.status == .passed)
        #expect(inventory.catalogCount == 1)
        #expect(inventory.catalogs.first?.entries.first?.requiredFiles.first?.exists == true)
    }

    @Test func magicRuleImportOptionsAllowCatalogDeckWithExplicitProfile() throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        try writeImportableMagicDRCDeck(root: root)
        let catalogURL = try writeMagicRuleImportCatalog(root: root, includeProfileResource: false)
        let profileURL = root.appending(path: "profiles/sky130-magic-layouttech-profile.json")
        try FileManager.default.createDirectory(
            at: profileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let profile = try MagicDRCLayoutTechImportProfile.bundledMagicLayoutTechProfile(
            resourceName: "sky130-magic-layouttech-profile"
        )
        try writeJSON(profile, to: profileURL)

        let options = try DRCMagicRuleImportCLIOptions(arguments: [
            "--import-magic-rules",
            "--catalog", catalogURL.path(percentEncoded: false),
            "--pdk-root", root.path(percentEncoded: false),
            "--profile", profileURL.path(percentEncoded: false),
            "--tech-out", "/tmp/layout-tech.json",
        ])

        #expect(options.magicTechURL.path(percentEncoded: false).hasSuffix("sky130A/libs.tech/magic/sky130A.tech"))
        #expect(options.profileURL.path(percentEncoded: false) == profileURL.path(percentEncoded: false))
        #expect(options.profileResourceName == nil)
        #expect(options.technologyCatalogID == "sky130-open-pdk")
        #expect(options.pdkID == "sky130A")
    }

    @Test func magicRuleImportOptionsRejectDuplicateProfileSources() throws {
        let error = try captureError {
            _ = try DRCMagicRuleImportCLIOptions(arguments: [
                "--import-magic-rules",
                "--magic-tech", "/tmp/pdk/libs.tech/magic/process.tech",
                "--profile", "/tmp/pdk/profile.json",
                "--profile-resource", "sky130-magic-layouttech-profile",
                "--tech-out", "/tmp/layout-tech.json",
            ])
        }

        #expect(error == .invalidValue(
            argument: "--profile-resource",
            value: "sky130-magic-layouttech-profile",
            expected: "only one of --profile or --profile-resource; received /tmp/pdk/profile.json"
        ))
    }

    @Test func capabilitySnapshotDescribesStandaloneEngineSurface() throws {
        let snapshot = DRCCapabilitySnapshotProvider().snapshot()

        #expect(snapshot.schemaVersion == 2)
        #expect(snapshot.engineID == "drcengine")
        #expect(snapshot.ownerPackage == "DRCEngine")
        #expect(snapshot.status == "development-native-core")
        #expect(snapshot.preferredBackendID == "native-gds")
        #expect(snapshot.actionDomain.domainID == "drc-signoff")
        #expect(snapshot.corpus.committedSpecPath == "Tests/DRCCLICoreTests/Fixtures/DRCCorpus/drc-corpus.json")
        #expect(snapshot.corpus.requiredCoverageTags.contains("drc.input.gds"))
        #expect(snapshot.corpus.requiredCoverageTags.contains("drc.input.oasis"))
        #expect(snapshot.corpus.requiredCoverageTags.contains("drc.input.cif"))
        #expect(snapshot.corpus.requiredCoverageTags.contains("drc.input.dxf"))
        #expect(snapshot.corpus.requiredCoverageTags.contains("drc.spacing.parallel-run-length"))
        #expect(snapshot.corpus.requiredCoverageTags.contains("drc.spacing.wide"))
        #expect(snapshot.corpus.requiredCoverageTags.contains("drc.overlap.exact"))
        #expect(snapshot.corpus.requiredCoverageTags.contains("drc.enclosure.composite"))

        let native = try #require(snapshot.backends.first { $0.backendID == "native" })
        #expect(native.executionMode == "in-process")
        #expect(native.diagnosticKinds.contains("exactOverlap"))
        #expect(native.coverageTags.contains("drc.overlap.exact"))
        #expect(native.coverageTags.contains("drc.spacing.wide"))
        #expect(native.coverageTags.contains("drc.enclosure.composite"))

        let nativeGDS = try #require(snapshot.backends.first { $0.backendID == "native-gds" })
        #expect(nativeGDS.executionMode == "in-process")
        #expect(!nativeGDS.requiresExternalTool)
        #expect(nativeGDS.inputFormats.contains("gds"))
        #expect(nativeGDS.inputFormats.contains("oasis"))
        #expect(nativeGDS.inputFormats.contains("cif"))
        #expect(nativeGDS.inputFormats.contains("dxf"))
        #expect(nativeGDS.inputFormats.contains("native-json"))
        #expect(nativeGDS.requiredInputs.contains("technology-json"))
        #expect(nativeGDS.coverageTags.contains("drc.input.gds"))
        #expect(nativeGDS.coverageTags.contains("drc.input.oasis"))
        #expect(nativeGDS.coverageTags.contains("drc.input.cif"))
        #expect(nativeGDS.coverageTags.contains("drc.input.dxf"))
        #expect(nativeGDS.coverageTags.contains("drc.angle"))
        #expect(nativeGDS.coverageTags.contains("drc.overlap.exact"))
        #expect(nativeGDS.diagnosticKinds.contains("angle"))

        let magic = try #require(snapshot.backends.first { $0.backendID == "magic" })
        #expect(magic.requiresExternalTool)
        #expect(magic.maturity == "independent-reference-adapter")

        #expect(snapshot.artifacts.contains { $0.artifactID == "drc-summary" })
        #expect(snapshot.artifacts.contains { $0.artifactID == "drc-repair-hints" })
        #expect(snapshot.artifacts.contains { $0.artifactID == "signoff-foundry-deck-semantics" })
        #expect(snapshot.artifacts.contains { $0.artifactID == "drc-foundry-rule-import-report" })
        #expect(snapshot.artifacts.contains { $0.artifactID == "drc-corpus-coverage-audit" })
        #expect(snapshot.artifacts.contains { $0.artifactID == "drc-magic-rule-import-catalog-inventory" })
        #expect(snapshot.artifacts.contains { $0.artifactID == "layout-tech-database" })
        #expect(snapshot.artifacts.allSatisfy { !$0.integrityEvidenceFields.isEmpty })
        #expect(snapshot.artifacts.allSatisfy { !$0.currentnessVerifier.isEmpty })
        #expect(snapshot.artifacts.allSatisfy { !$0.verdictFields.isEmpty })
        let reportContract = try #require(snapshot.artifacts.first { $0.artifactID == "drc-report" })
        #expect(reportContract.integrityEvidenceFields == ["path", "byteCount", "sha256"])
        #expect(reportContract.currentnessVerifier == "drc-artifact-manifest-record")
        #expect(reportContract.verdictFields.contains("passed"))
        #expect(reportContract.verdictFields.contains("completed"))
        let manifestContract = try #require(snapshot.artifacts.first { $0.artifactID == "drc-artifact-manifest" })
        #expect(manifestContract.integrityEvidenceFields == [
            "path",
            "runID",
            "requestSHA256",
            "requestEnvironmentSHA256",
            "artifactRootSHA256",
            "signature",
        ])
        #expect(manifestContract.currentnessVerifier == "outer-run-ledger-reference")
        #expect(manifestContract.verdictFields.contains("diagnosticSummary"))
        #expect(snapshot.agentContracts.contains { $0.contains("typed request/result") })
        #expect(snapshot.agentContracts.contains { $0.contains("--audit-corpus-coverage") })
        #expect(snapshot.agentContracts.contains { $0.contains("typed repair hints") })
        #expect(snapshot.agentContracts.contains { $0.contains("backend-provided repair geometry") })
        #expect(snapshot.agentContracts.contains { $0.contains("--foundry-deck-semantics") })
        #expect(snapshot.agentContracts.contains { $0.contains("--import-magic-rules") })
        #expect(snapshot.agentContracts.contains { $0.contains("--inspect-magic-rule-import-catalog") })
        #expect(snapshot.agentContracts.contains { $0.contains("--import-foundry-magic-rules") })
        #expect(!snapshot.agentContracts.contains { $0.contains("--import-sky130-magic-rules") })
        #expect(snapshot.agentContracts.contains { $0.contains("sourceCutLayerNames/sourceCutAliasCount") })
        #expect(snapshot.agentContracts.contains { $0.contains("sourceContactDefinitionIDs/sourceContactDefinitionCount") })
        #expect(snapshot.agentContracts.contains { $0.contains("sourceExactOverlapRules/sourceExactOverlapRuleCount") })
        #expect(snapshot.agentContracts.contains { $0.contains("sourceEnclosedHoleRules/sourceEnclosedHoleRuleCount") })
        #expect(snapshot.agentContracts.contains { $0.contains("sourceTempLayerDefinitions/sourceTempLayerOperationCounts") })
        #expect(snapshot.agentContracts.contains { $0.contains("sourceTempLayerMaterializedRuleIDs/sourceTempLayerMaterializedRuleCount") })
        #expect(snapshot.agentContracts.contains { $0.contains("and/or/and-not/xor/grow/grow-min/shrink/bridge/close") })
        #expect(snapshot.agentContracts.contains { $0.contains("sourceMinimumCutPolicies/sourceMinimumCutPolicyCount") })
        #expect(snapshot.agentContracts.contains { $0.contains("unique stack inference") })
        #expect(snapshot.agentContracts.contains { $0.contains("LayoutExactOverlapRule") })
        #expect(snapshot.agentContracts.contains { $0.contains("allowedAngleStepDegrees") })
        #expect(snapshot.agentContracts.contains { $0.contains("minEnclosedArea") })
        #expect(snapshot.agentContracts.contains { $0.contains("composite rectangular cover") })
        #expect(snapshot.openMilestones.contains { $0.contains("multi-numeric or ambiguous real-deck variants") })
        #expect(snapshot.openMilestones.contains { $0.contains("future templayer operations") })
        #expect(!snapshot.openMilestones.contains { $0.contains("angle semantics") })

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(DRCCapabilitySnapshot.self, from: data)
        #expect(decoded == snapshot)
    }

    @Test func capabilitiesCLIReturnsSuccess() async throws {
        let exitCode = await DRCCLI.run(arguments: ["--capabilities", "--json"])

        #expect(exitCode == 0)
    }

    @Test func capabilitiesCLIEmitsDecodableSnapshot() async throws {
        let invocation = await DRCCLI.invoke(arguments: ["--capabilities", "--json"])

        #expect(invocation.exitCode == 0)
        #expect(invocation.standardError.isEmpty)

        let snapshot = try JSONDecoder().decode(
            DRCCapabilitySnapshot.self,
            from: Data(invocation.standardOutput.utf8)
        )
        #expect(snapshot == DRCCapabilitySnapshotProvider().snapshot())
        #expect(snapshot.backends.allSatisfy { !$0.backendID.isEmpty && !$0.producedArtifacts.isEmpty })
        #expect(snapshot.artifacts.allSatisfy { !$0.artifactID.isEmpty && !$0.consumer.isEmpty })
    }

    @Test func actionDomainCLIEmitsDecodablePlannerContract() async throws {
        let invocation = await DRCCLI.invoke(arguments: ["--action-domain", "--json"])

        #expect(invocation.exitCode == 0)
        #expect(invocation.standardError.isEmpty)

        let snapshot = try JSONDecoder().decode(
            DRCActionDomainSnapshot.self,
            from: Data(invocation.standardOutput.utf8)
        )
        #expect(snapshot.domainID == "drc-signoff")
        #expect(snapshot.ownerPackages == ["DRCEngine"])

        let operationIDs = Set(snapshot.operations.map(\.operationID))
        #expect(operationIDs.contains("drc.run-native"))
        #expect(operationIDs.contains("drc.export-repair-hints"))
        #expect(operationIDs.contains("drc.assess-corpus"))
        #expect(operationIDs.contains("drc.import-foundry-rule-seed"))
        #expect(operationIDs.contains("drc.assess-native-antenna"))
        #expect(snapshot.operations.allSatisfy { !$0.inputRefs.isEmpty && !$0.producedArtifacts.isEmpty })

        let nativeRun = try #require(snapshot.operations.first { $0.operationID == "drc.run-native" })
        #expect(nativeRun.inputRefs.contains("layout-ref"))
        #expect(nativeRun.inputRefs.contains("technology-ref"))
        #expect(nativeRun.verificationGates.contains("artifact-integrity"))
        #expect(nativeRun.producedArtifacts.contains("drc-artifact-manifest"))
        #expect(nativeRun.effects.contains("composite-enclosure-coverage-evaluated"))

        let importRuleSeed = try #require(snapshot.operations.first {
            $0.operationID == "drc.import-foundry-rule-seed"
        })
        #expect(importRuleSeed.maturity == "available-unqualified")
        #expect(importRuleSeed.inputRefs == [
            "magic-tech-ref-or-signoff-profile",
            "magic-layouttech-import-profile",
            "optional-pdk-root",
        ])
        #expect(importRuleSeed.producedArtifacts == [
            "layout-tech-database",
            "drc-foundry-rule-import-report",
        ])
        #expect(importRuleSeed.verificationGates == [
            "deck-readiness",
            "profile-coverage",
            "import-coverage",
            "artifact-integrity",
        ])
    }

    @Test func repairHintsOptionsParseJSONFlag() throws {
        let options = try DRCRepairHintsCLIOptions(arguments: [
            "--repair-hints-from-report", "/tmp/drc-report.json",
            "--json",
        ])

        #expect(options.reportURL.path(percentEncoded: false) == "/tmp/drc-report.json")
        #expect(options.emitJSON)
    }

    @Test func foundryDeckSemanticsCLIPassesWithMagicDeckOnly() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        try writeMagicDRCDeck(root: root)

        let exitCode = await DRCCLI.run(arguments: [
            "--foundry-deck-semantics",
            "--pdk-root", root.path(percentEncoded: false),
            "--require-passed",
            "--json",
        ])

        #expect(exitCode == 0)
    }

    @Test func foundryDeckSemanticsCLIBlocksMissingMagicDeckWhenRequired() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }

        let exitCode = await DRCCLI.run(arguments: [
            "--foundry-deck-semantics",
            "--pdk-root", root.path(percentEncoded: false),
            "--require-passed",
            "--json",
        ])

        #expect(exitCode == 2)
    }

    @Test func foundryRuleImportCLIWritesLayoutTechAndReport() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        try writeImportableMagicDRCDeck(root: root)
        let technologyURL = root.appending(path: "outputs/sky130-layout-tech.json")
        let reportURL = root.appending(path: "outputs/sky130-rule-import.json")
        let profileURL = root.appending(path: "outputs/sky130-magic-layouttech-profile.json")
        try FileManager.default.createDirectory(
            at: profileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let profile = try MagicDRCLayoutTechImportProfile.bundledMagicLayoutTechProfile(
            resourceName: "sky130-magic-layouttech-profile"
        )
        let profileEncoder = JSONEncoder()
        profileEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try profileEncoder.encode(profile).write(to: profileURL)

        let exitCode = await DRCCLI.run(arguments: [
            "--import-foundry-magic-rules",
            "--pdk-root", root.path(percentEncoded: false),
            "--profile", profileURL.path(percentEncoded: false),
            "--tech-out", technologyURL.path(percentEncoded: false),
            "--report-out", reportURL.path(percentEncoded: false),
            "--json",
        ])

        #expect(exitCode == 0)
        let technology = try JSONDecoder().decode(
            LayoutTechDatabase.self,
            from: Data(contentsOf: technologyURL)
        )
        let report = try JSONDecoder().decode(
            MagicDRCLayoutTechImportReport.self,
            from: Data(contentsOf: reportURL)
        )
        let met1 = LayoutLayerID(name: "MET1", purpose: "drawing")
        let via1 = LayoutLayerID(name: "VIA1", purpose: "cut")
        let met2 = LayoutLayerID(name: "MET2", purpose: "drawing")
        let diff = LayoutLayerID(name: "DIFF", purpose: "drawing")
        let poly = LayoutLayerID(name: "POLY", purpose: "drawing")
        #expect(technology.ruleSet(for: met1)?.minWidth == 0.14)
        #expect(technology.ruleSet(for: met1)?.minSpacing == 0.14)
        #expect(technology.ruleSet(for: met1)?.minArea == 0.083)
        #expect(technology.ruleSet(for: met1)?.minNotch == 0.28)
        #expect(technology.ruleSet(for: met1)?.wideWidthThreshold == 3.0)
        #expect(technology.ruleSet(for: met1)?.wideSpacing == 0.9)
        #expect(technology.ruleSet(for: met1)?.minEnclosedArea == 0.14)
        #expect(technology.ruleSet(for: met1)?.requiresRectangular == true)
        #expect(technology.ruleSet(for: met1)?.allowedAngleStepDegrees == 45)
        #expect(technology.ruleSet(for: via1)?.minWidth == 0.15)
        #expect(technology.ruleSet(for: via1)?.minSpacing == 0.17)
        #expect(technology.enclosureRule(outer: met1, inner: via1)?.minEnclosure == 0.03)
        #expect(technology.enclosureRule(outer: met2, inner: via1)?.minEnclosure == 0.04)
        #expect(technology.spacingRules.count == 1)
        #expect(technology.spacingRules.first?.primaryLayer == diff)
        #expect(technology.spacingRules.first?.secondaryLayer == poly)
        #expect(technology.spacingRules.first?.minSpacing == 0.09)
        let viaDefinition = technology.viaDefinition(for: "VIA1")
        #expect(viaDefinition?.cutLayer == via1)
        #expect(viaDefinition?.bottomLayer == met1)
        #expect(viaDefinition?.topLayer == met2)
        #expect(viaDefinition?.cutSize.width == 0.15)
        #expect(viaDefinition?.cutSize.height == 0.15)
        #expect(viaDefinition?.cutSpacing == 0.17)
        #expect(viaDefinition?.enclosure.bottom == 0.03)
        #expect(viaDefinition?.enclosure.top == 0.04)
        let minimumCutRule = technology.minimumCutRule(for: "mincut.VIA1")
        #expect(minimumCutRule?.cutLayer == via1)
        #expect(minimumCutRule?.bottomLayer == met1)
        #expect(minimumCutRule?.topLayer == met2)
        #expect(minimumCutRule?.minimumCount == 2)
        let exactOverlapRule = technology.exactOverlapRule(for: "exactOverlap.VIA1.MET1")
        #expect(exactOverlapRule?.primaryLayer == via1)
        #expect(exactOverlapRule?.secondaryLayer == met1)
        #expect(exactOverlapRule?.tolerance == 0)
        #expect(technology.extensionRule(extending: poly, enclosed: diff, direction: .horizontal)?.minExtension == 0.13)
        #expect(report.status == .complete)
        #expect(report.importedLayerNames == ["DIFF", "POLY", "MET1", "VIA1", "MET2"])
        #expect(report.sourceCutLayerNames == ["VIA1"])
        #expect(report.sourceCutAliasCount == 5)
        #expect(report.sourceContactDefinitionIDs == ["VIA1"])
        #expect(report.sourceContactDefinitionCount == 1)
        #expect(report.sourceExactOverlapRuleIDs == ["exactOverlap.VIA1.MET1"])
        #expect(report.sourceExactOverlapRuleCount == 1)
        #expect(report.sourceExactOverlapRules.first?.primaryLayerName == "VIA1")
        #expect(report.sourceExactOverlapRules.first?.secondaryLayerName == "MET1")
        #expect(report.sourceEnclosedHoleRuleIDs == ["enclosedHole.MET1"])
        #expect(report.sourceEnclosedHoleRuleCount == 1)
        #expect(report.sourceEnclosedHoleRules.first?.layerName == "MET1")
        #expect(report.sourceEnclosedHoleRules.first?.minimumArea == 0.14)
        #expect(report.sourceForbiddenMarkerRuleIDs.isEmpty)
        #expect(report.sourceForbiddenMarkerRuleCount == 0)
        #expect(report.sourceMinimumCutPolicyIDs == ["sourceMinimumCut.VIA1"])
        #expect(report.sourceMinimumCutPolicyCount == 1)
        #expect(report.sourceMinimumCutPolicies.first?.interconnectID == "VIA1")
        #expect(report.sourceMinimumCutPolicies.first?.cutLayerName == "VIA1")
        #expect(report.sourceMinimumCutPolicies.first?.bottomLayerName == "MET1")
        #expect(report.sourceMinimumCutPolicies.first?.topLayerName == "MET2")
        #expect(report.sourceMinimumCutPolicies.first?.minimumCount == 2)
        #expect(report.sourceTempLayerDefinitionIDs == [
            "tempLayer.m1_small_hole",
            "tempLayer.m1_hole_empty",
        ])
        #expect(report.sourceTempLayerDefinitionCount == 2)
        #expect(report.sourceTempLayerOperationCounts["close"] == 1)
        #expect(report.sourceTempLayerOperationCounts["and-not"] == 1)
        #expect(report.sourceTempLayerMaterializedRuleIDs.isEmpty)
        #expect(report.sourceTempLayerMaterializedRuleCount == 0)
        #expect(technology.forbiddenLayerRules.isEmpty)
        #expect(report.derivedViaDefinitionIDs == ["VIA1"])
        #expect(report.derivedContactDefinitionIDs.isEmpty)
        #expect(report.derivedMinimumCutRuleIDs == ["mincut.VIA1"])
        #expect(report.importedFamilyCounts["width"] == 2)
        #expect(report.importedFamilyCounts["spacing"] == 3)
        #expect(report.importedFamilyCounts["notch"] == 1)
        #expect(report.importedFamilyCounts["rect_only"] == 1)
        #expect(report.importedFamilyCounts["surround"] == 2)
        #expect(report.importedFamilyCounts["widespacing"] == 1)
        #expect(report.importedFamilyCounts["overhang"] == 1)
        #expect(report.importedFamilyCounts["exact_overlap"] == 1)
        #expect(report.importedFamilyCounts["angles"] == 1)
        #expect(report.importedFamilyCounts["cifmaxwidth"] == 1)
        #expect(report.importedFamilyCounts["minimum_cut"] == 1)
        #expect(report.skippedFamilyCounts["angles"] == nil)
        #expect(report.skippedFamilyCounts["exact_overlap"] == nil)
        #expect(report.skippedFamilyCounts["cifmaxwidth"] == nil)
    }

    @Test func foundryRuleImportCLIEmitsDecodableAgentEnvelope() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        try writeImportableMagicDRCDeck(root: root)
        let technologyURL = root.appending(path: "outputs/agent-layout-tech.json")
        let reportURL = root.appending(path: "outputs/agent-rule-import.json")

        let invocation = await DRCCLI.invoke(arguments: [
            "--import-foundry-magic-rules",
            "--pdk-root", root.path(percentEncoded: false),
            "--tech-out", technologyURL.path(percentEncoded: false),
            "--report-out", reportURL.path(percentEncoded: false),
            "--json",
        ])

        #expect(invocation.exitCode == 0)
        #expect(invocation.standardError.isEmpty)
        #expect(invocation.standardOutput.contains(#""semanticReport""#))
        #expect(invocation.standardOutput.contains(#""importReport""#))

        let output = try JSONDecoder().decode(
            DRCFoundryRuleImportCLIOutput.self,
            from: Data(invocation.standardOutput.utf8)
        )
        let importReport = try #require(output.importReport)

        #expect(output.status == "complete")
        #expect(output.technologyPath == technologyURL.path(percentEncoded: false))
        #expect(output.reportPath == reportURL.path(percentEncoded: false))
        #expect(output.semanticReport.status == .passed)
        #expect(output.semanticReport.pdkRoot == root.path(percentEncoded: false))
        #expect(importReport.kind == "drc-foundry-rule-import")
        #expect(importReport.status == .complete)
        #expect(importReport.sourcePath.hasSuffix("sky130A/libs.tech/magic/sky130A.tech"))
        #expect(importReport.importedFamilyCounts["minimum_cut"] == 1)
        #expect(importReport.sourceMinimumCutPolicyCount == 1)
        #expect(FileManager.default.fileExists(atPath: technologyURL.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: reportURL.path(percentEncoded: false)))
    }

    @Test func foundryRuleImportCLIEmitsBlockedEnvelopeWhenDeckReadinessFails() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let technologyURL = root.appending(path: "outputs/blocked-layout-tech.json")
        let reportURL = root.appending(path: "outputs/blocked-rule-import.json")

        let invocation = await DRCCLI.invoke(arguments: [
            "--import-foundry-magic-rules",
            "--pdk-root", root.path(percentEncoded: false),
            "--tech-out", technologyURL.path(percentEncoded: false),
            "--report-out", reportURL.path(percentEncoded: false),
            "--json",
        ])

        #expect(invocation.exitCode == 2)
        #expect(invocation.standardError.isEmpty)

        let output = try JSONDecoder().decode(
            DRCFoundryRuleImportCLIOutput.self,
            from: Data(invocation.standardOutput.utf8)
        )

        #expect(output.status == "blocked")
        #expect(output.technologyPath == nil)
        #expect(output.reportPath == nil)
        #expect(output.importReport == nil)
        #expect(output.semanticReport.status == .blocked)
        #expect(output.semanticReport.coverageTagResults.allSatisfy { $0.status == .blocked })
        #expect(!FileManager.default.fileExists(atPath: technologyURL.path(percentEncoded: false)))
        #expect(!FileManager.default.fileExists(atPath: reportURL.path(percentEncoded: false)))
    }

    @Test func magicRuleImportCLIWritesLayoutTechFromExternalProfile() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let magicTechURL = root.appending(path: "generic.magic.tech")
        let profileURL = root.appending(path: "generic-magic-profile.json")
        let technologyURL = root.appending(path: "outputs/generic-layout-tech.json")
        let reportURL = root.appending(path: "outputs/generic-rule-import.json")
        let profile = MagicDRCLayoutTechImportProfile(
            profileID: "test.magic.layouttech",
            layerOrder: ["METX", "CUTX", "METY"],
            cutLayerNames: ["CUTX"],
            layerPurposes: ["CUTX": "cut"],
            layerDisplayNames: ["METX": "Metal X"],
            baseLayerNames: ["METX", "CUTX", "METY"],
            cutStackConnections: [
                MagicDRCLayoutTechCutStackConnection(
                    id: "CUTX",
                    cutLayerName: "CUTX",
                    bottomLayerName: "METX",
                    topLayerName: "METY",
                    kind: "via"
                ),
            ]
        )
        try writeJSON(profile, to: profileURL)
        try writeText(
            """
            style gdsii
            layer METX metx
              calma 10 0
            layer CUTX cutx
              calma 11 0
            layer METY mety
              calma 12 0
            cut cutx via CUTX
            drc
              width metx 100 "Metal X width"
              width cutx 50 "Cut X width"
              spacing cutx cutx 60 touching_illegal "Cut X spacing"
              surround cutx metx 20 absence_illegal "Bottom overlap"
              surround cutx mety 30 absence_illegal "Top overlap"
              cutcount cutx metx mety 3 "Cut X needs three cuts"
            end
            """,
            to: magicTechURL
        )

        let exitCode = await DRCCLI.run(arguments: [
            "--import-magic-rules",
            "--magic-tech", magicTechURL.path(percentEncoded: false),
            "--profile", profileURL.path(percentEncoded: false),
            "--tech-out", technologyURL.path(percentEncoded: false),
            "--report-out", reportURL.path(percentEncoded: false),
            "--require-complete",
            "--json",
        ])

        #expect(exitCode == 0)
        let technology = try JSONDecoder().decode(
            LayoutTechDatabase.self,
            from: Data(contentsOf: technologyURL)
        )
        let report = try JSONDecoder().decode(
            MagicDRCLayoutTechImportReport.self,
            from: Data(contentsOf: reportURL)
        )
        let metX = LayoutLayerID(name: "METX", purpose: "drawing")
        let cutX = LayoutLayerID(name: "CUTX", purpose: "cut")
        let metY = LayoutLayerID(name: "METY", purpose: "drawing")
        #expect(report.status == .complete)
        #expect(report.importedLayerNames == ["METX", "CUTX", "METY"])
        #expect(report.sourceCutLayerNames == ["CUTX"])
        #expect(technology.layerDefinition(for: metX)?.displayName == "Metal X")
        #expect(technology.ruleSet(for: cutX)?.minWidth == 0.05)
        let via = technology.viaDefinition(for: "CUTX")
        #expect(via?.cutLayer == cutX)
        #expect(via?.bottomLayer == metX)
        #expect(via?.topLayer == metY)
        #expect(via?.cutSpacing == 0.06)
        #expect(via?.enclosure.bottom == 0.02)
        #expect(via?.enclosure.top == 0.03)
        #expect(report.derivedViaDefinitionIDs == ["CUTX"])
        #expect(report.derivedMinimumCutRuleIDs == ["mincut.CUTX"])
        #expect(technology.minimumCutRule(for: "mincut.CUTX")?.minimumCount == 3)
        #expect(report.importedFamilyCounts["minimum_cut"] == 1)
        #expect(report.sourceMinimumCutPolicyIDs == ["sourceMinimumCut.CUTX"])
        #expect(report.sourceMinimumCutPolicyCount == 1)
        #expect(report.sourceMinimumCutPolicies.first?.minimumCount == 3)
    }

    @Test func magicRuleImportCLIFailsClosedOnPartialImportByDefault() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let magicTechURL = root.appending(path: "partial.magic.tech")
        let profileURL = root.appending(path: "partial-profile.json")
        let technologyURL = root.appending(path: "outputs/partial-layout-tech.json")
        let reportURL = root.appending(path: "outputs/partial-rule-import.json")
        try writePartialMagicRuleImportFixture(magicTechURL: magicTechURL, profileURL: profileURL)

        let invocation = await DRCCLI.invoke(arguments: [
            "--import-magic-rules",
            "--magic-tech", magicTechURL.path(percentEncoded: false),
            "--profile", profileURL.path(percentEncoded: false),
            "--tech-out", technologyURL.path(percentEncoded: false),
            "--report-out", reportURL.path(percentEncoded: false),
            "--json",
        ])

        #expect(invocation.exitCode == 2)
        #expect(invocation.standardError.isEmpty)
        let output = try JSONDecoder().decode(
            DRCMagicRuleImportCLIOutput.self,
            from: Data(invocation.standardOutput.utf8)
        )
        #expect(output.importReport.status == .partial)
        #expect(output.importReport.skippedFamilyCounts["edge4way"] == 1)
        #expect(FileManager.default.fileExists(atPath: technologyURL.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: reportURL.path(percentEncoded: false)))
    }

    @Test func magicRuleImportCLIAllowsPartialImportOnlyWhenExplicitlyRequested() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let magicTechURL = root.appending(path: "partial.magic.tech")
        let profileURL = root.appending(path: "partial-profile.json")
        let technologyURL = root.appending(path: "outputs/partial-layout-tech.json")
        let reportURL = root.appending(path: "outputs/partial-rule-import.json")
        try writePartialMagicRuleImportFixture(magicTechURL: magicTechURL, profileURL: profileURL)

        let invocation = await DRCCLI.invoke(arguments: [
            "--import-magic-rules",
            "--magic-tech", magicTechURL.path(percentEncoded: false),
            "--profile", profileURL.path(percentEncoded: false),
            "--tech-out", technologyURL.path(percentEncoded: false),
            "--report-out", reportURL.path(percentEncoded: false),
            "--allow-partial",
            "--json",
        ])

        #expect(invocation.exitCode == 0)
        let output = try JSONDecoder().decode(
            DRCMagicRuleImportCLIOutput.self,
            from: Data(invocation.standardOutput.utf8)
        )
        #expect(output.importReport.status == .partial)
        #expect(output.importReport.skippedFamilyCounts["edge4way"] == 1)
    }

    @Test func magicRuleImportCLIBlocksInvalidExternalProfileAsStructuredReport() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let magicTechURL = root.appending(path: "invalid-profile.magic.tech")
        let profileURL = root.appending(path: "invalid-magic-profile.json")
        let technologyURL = root.appending(path: "outputs/invalid-layout-tech.json")
        let reportURL = root.appending(path: "outputs/invalid-rule-import.json")
        let profile = MagicDRCLayoutTechImportProfile(
            profileID: "test.magic.invalid-profile",
            layerOrder: ["METX", "CUTX", "METY"],
            cutLayerNames: ["CUTX"],
            baseLayerNames: ["METX", "CUTX", "METY"],
            derivedLayerSeeds: [
                MagicDRCLayoutTechDerivedLayerSeed(
                    id: "invalid.derived",
                    targetLayerName: "METY",
                    sourceLayerNames: ["METX"],
                    operation: "unsupported-operation"
                ),
            ],
            cutStackConnections: [
                MagicDRCLayoutTechCutStackConnection(
                    id: "CUTX",
                    cutLayerName: "CUTX",
                    bottomLayerName: "METX",
                    topLayerName: "METY",
                    kind: "unsupported-kind"
                ),
            ]
        )
        try writeJSON(profile, to: profileURL)
        try writeText(
            """
            style gdsii
            layer METX metx
              calma 10 0
            drc
              width metx 100 "Metal X width"
            end
            """,
            to: magicTechURL
        )

        let invocation = await DRCCLI.invoke(arguments: [
            "--import-magic-rules",
            "--magic-tech", magicTechURL.path(percentEncoded: false),
            "--profile", profileURL.path(percentEncoded: false),
            "--tech-out", technologyURL.path(percentEncoded: false),
            "--report-out", reportURL.path(percentEncoded: false),
            "--json",
        ])

        #expect(invocation.exitCode == 2)
        #expect(invocation.standardError.isEmpty)
        let output = try JSONDecoder().decode(
            DRCMagicRuleImportCLIOutput.self,
            from: Data(invocation.standardOutput.utf8)
        )
        let technology = try JSONDecoder().decode(
            LayoutTechDatabase.self,
            from: Data(contentsOf: technologyURL)
        )
        let persistedReport = try JSONDecoder().decode(
            MagicDRCLayoutTechImportReport.self,
            from: Data(contentsOf: reportURL)
        )

        #expect(output.status == "blocked")
        #expect(output.importReport.status == .blocked)
        #expect(output.importReport.diagnostics.first?.code == "magic_drc_layouttech_profile_validation_failed")
        #expect(output.importReport.diagnostics.first?.message.contains("unsupportedDerivedLayerOperation") == true)
        #expect(output.importReport.diagnostics.first?.message.contains("unsupportedCutStackKind") == true)
        #expect(persistedReport == output.importReport)
        #expect(technology.layers.isEmpty)
        #expect(technology.derivedLayerRules.isEmpty)
        #expect(technology.vias.isEmpty)
    }

    @Test func magicRuleImportCLIWritesLayoutTechFromBundledProfileResource() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        try writeImportableMagicDRCDeck(root: root)
        let magicTechURL = root.appending(path: "sky130A/libs.tech/magic/sky130A.tech")
        let technologyURL = root.appending(path: "outputs/generic-sky130-layout-tech.json")
        let reportURL = root.appending(path: "outputs/generic-sky130-rule-import.json")

        let exitCode = await DRCCLI.run(arguments: [
            "--import-magic-rules",
            "--magic-tech", magicTechURL.path(percentEncoded: false),
            "--profile-resource", "sky130-magic-layouttech-profile",
            "--tech-out", technologyURL.path(percentEncoded: false),
            "--report-out", reportURL.path(percentEncoded: false),
            "--json",
        ])

        #expect(exitCode == 0)
        let technology = try JSONDecoder().decode(
            LayoutTechDatabase.self,
            from: Data(contentsOf: technologyURL)
        )
        let report = try JSONDecoder().decode(
            MagicDRCLayoutTechImportReport.self,
            from: Data(contentsOf: reportURL)
        )
        let met1 = LayoutLayerID(name: "MET1", purpose: "drawing")
        let via1 = LayoutLayerID(name: "VIA1", purpose: "cut")
        #expect(report.status == .complete)
        #expect(report.importedLayerNames == ["DIFF", "POLY", "MET1", "VIA1", "MET2"])
        #expect(technology.ruleSet(for: met1)?.minWidth == 0.14)
        #expect(technology.ruleSet(for: via1)?.minSpacing == 0.17)
        #expect(report.derivedMinimumCutRuleIDs == ["mincut.VIA1"])
        #expect(technology.minimumCutRule(for: "mincut.VIA1")?.minimumCount == 2)
        #expect(report.sourceMinimumCutPolicyIDs == ["sourceMinimumCut.VIA1"])
        #expect(report.sourceMinimumCutPolicyCount == 1)
    }

    @Test func magicRuleImportCLIWritesProvenanceBoundNativeAntennaArtifact() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let magicTechURL = root.appending(path: "antenna.magic.tech")
        let profileURL = root.appending(path: "antenna-profile.json")
        let technologyURL = root.appending(path: "outputs/antenna-layout-tech.json")
        let reportURL = root.appending(path: "outputs/antenna-report.json")
        let artifactURL = root.appending(path: "outputs/antenna-artifact.json")
        let profile = MagicDRCLayoutTechImportProfile(
            profileID: "test.magic.cli.antenna",
            layerOrder: ["MET1"],
            baseLayerNames: ["MET1"]
        )
        try writeJSON(profile, to: profileURL)
        try writeText(
            """
            style gdsii
            layer MET1 met1
              calma 68 20
            drc
              width met1 100 "Metal width"
            end
            extract
              model partial surface
              antenna met1 10 none
            """,
            to: magicTechURL
        )

        let exitCode = await DRCCLI.run(arguments: [
            "--import-magic-rules",
            "--magic-tech", magicTechURL.path(percentEncoded: false),
            "--profile", profileURL.path(percentEncoded: false),
            "--tech-out", technologyURL.path(percentEncoded: false),
            "--report-out", reportURL.path(percentEncoded: false),
            "--native-antenna-out", artifactURL.path(percentEncoded: false),
            "--allow-partial",
            "--json",
        ])

        #expect(exitCode == 0)
        let artifact = try JSONDecoder().decode(
            NativeDRCAntennaArtifact.self,
            from: Data(contentsOf: artifactURL)
        )
        try artifact.validate()
        #expect(artifact.profileID == profile.profileID)
        #expect(artifact.sourceAntennaRules.count == 1)
        #expect(artifact.nativeRules.count == 1)
        #expect(artifact.assessment.satisfied == false)
        #expect(artifact.assessment.failureCodes == ["oracle_evidence_missing", "independent_oracle_unverified"])
    }

    @Test func nativeAntennaAssessmentCLIRebindsOracleEvidence() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let artifactURL = root.appending(path: "native-antenna-artifact.json")
        let evidenceURL = root.appending(path: "magic-oracle-evidence.json")
        let outputURL = root.appending(path: "native-antenna-qualified.json")
        let sourceReport = MagicDRCLayoutTechImportReport(
            generatedAt: "2026-07-12T00:00:00Z",
            status: .partial,
            sourcePath: "/tmp/qualification-cli.magic.tech",
            sourceDigest: String(repeating: "a", count: 64),
            profileDigest: String(repeating: "b", count: 64),
            profileID: "test.magic.cli.qualification",
            profileLayerOrder: ["MET1"],
            supportedRuleFamilies: [],
            importedRuleCount: 1,
            skippedRuleCount: 1,
            importedFamilyCounts: ["width": 1],
            skippedFamilyCounts: ["antenna": 1],
            importedLayerNames: ["MET1"],
            sourceAntennaRules: [MagicDRCSourceAntennaRule(
                id: "antenna.MET1.surface.1",
                layerNames: ["MET1"],
                measurement: .surface,
                model: .partial,
                maxRatio: 10,
                diffusionCorrection: MagicDRCAntennaDiffusionCorrection.none,
                sourceLineNumber: 1,
                sourceLine: "antenna met1 10 none"
            )],
            sourceLayerCount: 1,
            importedRules: [],
            diagnostics: [MagicDRCImportDiagnostic(
                code: "magic_drc_antenna_rule_not_materialized",
                message: "source evidence",
                sourceLineNumber: 1,
                sourceLine: "antenna met1 10 none"
            )]
        )
        let nativeRules = try NativeDRCAntennaRuleFactory.makeRules(from: sourceReport)
        let artifact = NativeDRCAntennaArtifact(
            sourceReport: sourceReport,
            nativeRules: nativeRules,
            oracleEvidence: nil
        )
        try writeJSON(artifact, to: artifactURL)
        let evidence = NativeDRCAntennaOracleEvidence(
            oracleID: "magic",
            executableDigest: String(repeating: "c", count: 64),
            ruleDeckDigest: String(repeating: "d", count: 64),
            technologyDigest: String(repeating: "e", count: 64),
            sourceDigest: try #require(artifact.sourceDigest),
            profileDigest: try #require(artifact.profileDigest),
            nativeRuleDigest: try #require(artifact.assessment.nativeRuleDigest),
            layoutCorpusDigest: String(repeating: "f", count: 64),
            comparisonArtifactDigest: String(repeating: "0", count: 64),
            evaluatedCaseCount: 1,
            agreedCaseCount: 1,
            passed: true,
            generatedAt: "2026-07-12T00:00:00Z"
        )
        try writeJSON(evidence, to: evidenceURL)

        let invocation = await DRCCLI.invoke(arguments: [
            "--assess-native-antenna",
            "--native-antenna-artifact", artifactURL.path(percentEncoded: false),
            "--oracle-evidence", evidenceURL.path(percentEncoded: false),
            "--out", outputURL.path(percentEncoded: false),
            "--json",
        ])

        #expect(invocation.exitCode == 0)
        let output = try JSONDecoder().decode(
            DRCNativeAntennaAssessmentCLIOutput.self,
            from: Data(invocation.standardOutput.utf8)
        )
        let reassessedArtifact = try JSONDecoder().decode(
            NativeDRCAntennaArtifact.self,
            from: Data(contentsOf: outputURL)
        )
        try reassessedArtifact.validate()
        #expect(output.status == "satisfied")
        #expect(output.assessment.satisfied)
        #expect(reassessedArtifact.assessment.oracleEvidence?.oracleID == "magic")
    }

    @Test func magicRuleImportCLIWritesLayoutTechFromCatalogEntry() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        try writeImportableMagicDRCDeck(root: root)
        let catalogURL = try writeMagicRuleImportCatalog(root: root)
        let technologyURL = root.appending(path: "outputs/catalog-sky130-layout-tech.json")
        let reportURL = root.appending(path: "outputs/catalog-sky130-rule-import.json")

        let exitCode = await DRCCLI.run(arguments: [
            "--import-magic-rules",
            "--catalog", catalogURL.path(percentEncoded: false),
            "--catalog-id", "sky130-open-pdk",
            "--pdk-id", "sky130A",
            "--profile-id", "sky130.magic.layouttech",
            "--pdk-root", root.path(percentEncoded: false),
            "--tech-out", technologyURL.path(percentEncoded: false),
            "--report-out", reportURL.path(percentEncoded: false),
            "--json",
        ])

        #expect(exitCode == 0)
        let technology = try JSONDecoder().decode(
            LayoutTechDatabase.self,
            from: Data(contentsOf: technologyURL)
        )
        let report = try JSONDecoder().decode(
            MagicDRCLayoutTechImportReport.self,
            from: Data(contentsOf: reportURL)
        )
        let met1 = LayoutLayerID(name: "MET1", purpose: "drawing")
        let via1 = LayoutLayerID(name: "VIA1", purpose: "cut")
        #expect(report.status == .complete)
        #expect(report.importedLayerNames == ["DIFF", "POLY", "MET1", "VIA1", "MET2"])
        #expect(technology.ruleSet(for: met1)?.minWidth == 0.14)
        #expect(technology.ruleSet(for: via1)?.minSpacing == 0.17)
        #expect(report.derivedMinimumCutRuleIDs == ["mincut.VIA1"])
        #expect(technology.minimumCutRule(for: "mincut.VIA1")?.minimumCount == 2)
        #expect(report.sourceMinimumCutPolicyIDs == ["sourceMinimumCut.VIA1"])
        #expect(report.sourceMinimumCutPolicyCount == 1)
    }

    @Test func foundryRuleImportCLIRequireCompleteAcceptsBridgeTemplayerImport() async throws {
        let root = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        try writeImportableMagicDRCDeck(root: root, includeUnsupportedRule: true)
        let technologyURL = root.appending(path: "sky130-layout-tech.json")
        let reportURL = root.appending(path: "sky130-rule-import.json")

        let exitCode = await DRCCLI.run(arguments: [
            "--import-foundry-magic-rules",
            "--pdk-root", root.path(percentEncoded: false),
            "--tech-out", technologyURL.path(percentEncoded: false),
            "--report-out", reportURL.path(percentEncoded: false),
            "--require-complete",
            "--json",
        ])

        #expect(exitCode == 0)
        let technology = try JSONDecoder().decode(
            LayoutTechDatabase.self,
            from: Data(contentsOf: technologyURL)
        )
        let report = try JSONDecoder().decode(
            MagicDRCLayoutTechImportReport.self,
            from: Data(contentsOf: reportURL)
        )
        #expect(report.status == .complete)
        #expect(report.skippedFamilyCounts["cifmaxwidth"] == nil)
        #expect(report.sourceForbiddenMarkerRuleIDs == ["forbiddenMarker.nwell_missing"])
        #expect(report.sourceForbiddenMarkerRuleCount == 1)
        let tempLayer = report.sourceTempLayerDefinitions.first { $0.name == "nwell_missing" }
        #expect(tempLayer?.id == "tempLayer.nwell_missing")
        #expect(tempLayer?.initialTerms == ["nwell"])
        #expect(tempLayer?.operations.map(\.command) == ["bridge", "and-not"])
        #expect(tempLayer?.referencedLayerNames == ["DNWELL", "NWELL"])
        #expect(tempLayer?.unresolvedReferences.isEmpty == true)
        #expect(report.sourceTempLayerMaterializedRuleIDs == ["magic.templayer.nwell_missing"])
        #expect(report.sourceTempLayerMaterializedRuleCount == 1)
        #expect(technology.derivedLayerRules.contains { rule in
            rule.id == "magic.templayer.nwell_missing.step1"
                && rule.operation == .bridge
                && rule.operationDistance == 0.4
                && rule.operationWidth == 0.4
        })
        #expect(technology.derivedLayerRules.contains { rule in
            rule.id == "magic.templayer.nwell_missing"
                && rule.operation == .difference
        })
        #expect(report.sourceMinimumCutPolicyIDs == ["sourceMinimumCut.VIA1"])
        #expect(report.sourceMinimumCutPolicyCount == 1)
        #expect(!report.diagnostics.contains {
            $0.code == "magic_drc_cifmaxwidth_marker_materialization_deferred"
        })
        let rule = technology.forbiddenLayerRule(for: "forbiddenMarker.nwell_missing")
        #expect(rule?.layer.name == "nwell_missing")
        #expect(rule?.layer.purpose == "marker")
    }

    @Test func actionDomainExporterDescribesDRCPlanningOperations() throws {
        let snapshot = DRCActionDomainExporter().snapshot()

        #expect(snapshot.schemaVersion == 1)
        #expect(snapshot.domainID == "drc-signoff")
        #expect(snapshot.ownerPackages == ["DRCEngine"])

        let operationIDs = Set(snapshot.operations.map(\.operationID))
        #expect(operationIDs.contains("drc.run-native"))
        #expect(operationIDs.contains("drc.inspect-foundry-deck-semantics"))
        #expect(operationIDs.contains("drc.import-foundry-rule-seed"))
        #expect(operationIDs.contains("drc.assess-native-antenna"))
        #expect(operationIDs.contains("drc.export-repair-hints"))
        #expect(operationIDs.contains("drc.assess-corpus"))
        #expect(operationIDs.contains("drc.audit-corpus-coverage"))
        #expect(operationIDs.contains("drc.export-corpus-observations"))
        #expect(operationIDs.contains("drc.export-evidence-packet"))
        #expect(operationIDs.contains("drc.waiver-review"))
        #expect(!operationIDs.contains("drc.diagnostic-to-repair-objective"))

        let run = try #require(snapshot.operations.first { $0.operationID == "drc.run-native" })
        #expect(run.maturity == "preview-verified")
        #expect(run.producedArtifacts.contains("drc-summary"))
        #expect(run.verificationGates.contains("drc-artifacts"))
        #expect(run.effects.contains("composite-enclosure-coverage-evaluated"))

        let deckSemantics = try #require(snapshot.operations.first {
            $0.operationID == "drc.inspect-foundry-deck-semantics"
        })
        #expect(deckSemantics.producedArtifacts == ["signoff-foundry-deck-semantics"])
        #expect(deckSemantics.preconditions == ["magic-drc-deck-readable"])
        #expect(deckSemantics.verificationGates.contains("semantic-coverage"))

        let ruleSeedImport = try #require(snapshot.operations.first {
            $0.operationID == "drc.import-foundry-rule-seed"
        })
        #expect(ruleSeedImport.maturity == "available-unqualified")
        #expect(ruleSeedImport.inputRefs == [
            "magic-tech-ref-or-signoff-profile",
            "magic-layouttech-import-profile",
            "optional-pdk-root",
        ])
        #expect(ruleSeedImport.effects == [
            "layout-tech-seed-produced",
            "foundry-rule-import-report-produced",
        ])
        #expect(ruleSeedImport.producedArtifacts == [
            "layout-tech-database",
            "drc-foundry-rule-import-report",
        ])
        #expect(ruleSeedImport.verificationGates == [
            "deck-readiness",
            "profile-coverage",
            "import-coverage",
            "artifact-integrity",
        ])

        let audit = try #require(snapshot.operations.first { $0.operationID == "drc.audit-corpus-coverage" })
        #expect(audit.producedArtifacts == ["drc-corpus-coverage-audit"])
        #expect(audit.verificationGates.contains("oracle-readiness"))
    }

    private func writePartialMagicRuleImportFixture(magicTechURL: URL, profileURL: URL) throws {
        let profile = MagicDRCLayoutTechImportProfile(
            profileID: "test.magic.partial",
            layerOrder: ["METX"],
            baseLayerNames: ["METX"]
        )
        try writeJSON(profile, to: profileURL)
        try writeText(
            """
            style gdsii
            layer METX metx
              calma 10 0
            drc
              width metx 100 "Metal X width"
              edge4way metx 100 "Unsupported edge four-way rule"
            end
            """,
            to: magicTechURL
        )
    }
}
