public struct DRCCapabilitySnapshotProvider: Sendable {
    public init() {}

    public func snapshot() -> DRCCapabilitySnapshot {
        DRCCapabilitySnapshot(
            engineID: "drcengine",
            ownerPackage: "DRCEngine",
            status: "standalone-native-core",
            preferredBackendID: "native-gds",
            backends: [
                nativeBackend(),
                nativeGDSBackend(),
                magicBackend(),
            ],
            artifacts: artifactContracts(),
            corpus: corpusContract(),
            actionDomain: DRCActionDomainExporter().snapshot(),
            agentContracts: [
                "CLI emits structured JSON for single-run, corpus, qualification, coverage-audit, evidence, foundry-deck semantic inventory, foundry-rule seed import, action-domain, and capability queries.",
                "API exposes typed request/result, diagnostics, summary, manifest, corpus, coverage-audit, evidence, action-domain, and capability models.",
                "Retained corpus reports can be audited through DRCCorpusCoverageAuditor and drcengine --audit-corpus-coverage to expose missing Magic oracle coverage, blocked readiness, duration-budget, and standard-input dimensions without prescribing a fixed repair flow.",
                "Foundry deck semantic inspection is exposed through drcengine --foundry-deck-semantics and the signoff-foundry-deck-semantics artifact contract.",
                "Generic Magic DRC LayoutTech seed import is exposed through the MagicDRCLayoutTechImporter API and drcengine --import-magic-rules with either explicit --magic-tech plus one of --profile or --profile-resource, or a catalog selector via --catalog, --catalog-id, --pdk-id, --profile-id, and optional --pdk-root; all paths emit structured JSON provenance.",
                "Installed foundry Magic DRC import is exposed through drcengine --import-foundry-magic-rules using signoff profile readiness plus an explicit or bundled Magic LayoutTech import profile; drcengine --import-sky130-magic-rules is retained only as a deprecated compatibility route.",
                "Magic rule import catalog readiness is inspectable before import through drcengine --inspect-magic-rule-import-catalog with explicit --catalog inputs or bounded --pdk-root discovery, producing a drc-magic-rule-import-catalog-inventory JSON artifact with required-file and bundled-profile-resource status.",
                "Sky130 Magic DRC width, same-layer spacing, cross-layer spacing, area, notch, rect-only, angle, surround enclosure, same-layer widespacing, overhang extension, exact-overlap including one-of secondary layer sets, MiM derived-layer, Sky130 hole-empty cifmaxwidth rules, dependency-ordered templayer marker materialization for and/or/and-not/grow/shrink operations, non-hole cifmaxwidth forbidden-marker source contracts, and generic Magic-deck minimum-cut/cut-count source policies can be imported into a partial LayoutTechDatabase seed through the generic drcengine --import-magic-rules catalog/profile-resource path or drcengine --import-foundry-magic-rules with Magic types/aliases layer-expression expansion, source contact-stack connectivity, derived via/contact definitions, derived minimum-cut seed rules, sourceCutLayerNames/sourceCutAliasCount, sourceContactStacks/sourceContactStackCount, sourceContactDefinitionIDs/sourceContactDefinitionCount, sourceExactOverlapRules/sourceExactOverlapRuleCount, sourceEnclosedHoleRules/sourceEnclosedHoleRuleCount evidence, sourceForbiddenMarkerRules/sourceForbiddenMarkerRuleCount evidence, sourceTempLayerDefinitions/sourceTempLayerOperationCounts evidence, sourceTempLayerMaterializedRuleIDs/sourceTempLayerMaterializedRuleCount evidence, sourceMinimumCutPolicies/sourceMinimumCutPolicyCount evidence, LayoutSpacingRule records, LayoutDerivedLayerRule records, LayoutExactOverlapRule records, LayoutForbiddenLayerRule records, allowedAngleStepDegrees records, minEnclosedArea records, LayoutMinimumCutRule minimumCount records, and an auditable drc-foundry-rule-import-report.",
                "Diagnostics carry rule, layer, measured/required values, region, related shape/net IDs, waiver state, and suggested fix fields.",
                "Saved DRC reports can be converted into typed repair hints for executable layout operations without log scraping.",
                "Spacing and overlap diagnostics export translation repair hints with executable deltaX/deltaY vectors when backend-provided repair geometry is available, including native JSON and standard layout inputs.",
                "Minimum-cut diagnostics export via repair hints with inferred viaDefinitionID, candidate position, existing/required/missing cut counts, and typed relatedViaIDs for existing cut references.",
                "Minimum enclosed-area diagnostics export fill-rectangle repair hints with explicit origin, size, area evidence, and native LVS verification gating.",
                "Minimum-density diagnostics export fill-rectangle repair hints with explicit density-window geometry, measured/required density evidence, target fill area, and native LVS verification gating.",
                "Corpus reports are immutable evidence and can be requalified without rerunning the engine.",
            ],
            openMilestones: [
                "Broaden Magic multi-cut/cut-count import from the current generic minimum-cut source-policy seed into real-deck syntax variants, remaining unsupported templayer operations for non-hole cifmaxwidth marker rules, golden foundry DRC cases, and broader Magic oracle agreement.",
                "Broaden standard mask input lanes from deterministic clean/equivalence fixtures into larger foundry-oriented coverage.",
                "Add larger benchmark suites with public PDK-derived rule decks and regression budgets.",
                "Expand repair hint normalization beyond current width, spacing, overlap, notch, enclosed-area, minimum-density, split, and via-cut edits until every active diagnostic kind has a benchmarked executable layout operation.",
            ]
        )
    }

    private func nativeBackend() -> DRCCapabilitySnapshot.Backend {
        DRCCapabilitySnapshot.Backend(
            backendID: "native",
            maturity: "implemented",
            executionMode: "in-process",
            requiresExternalTool: false,
            inputFormats: ["native-json"],
            requiredInputs: ["layout-json-with-rules", "top-cell"],
            producedArtifacts: ["drc-report", "drc-artifact-manifest", "drc-summary"],
            diagnosticKinds: diagnosticKinds(),
            qualificationTags: [
                "drc.clean",
                "drc.grid",
                "drc.width",
                "drc.area",
                "drc.density",
                "drc.antenna",
                "drc.cut",
                "drc.notch",
                "drc.enclosed-area",
                "drc.spacing",
                "drc.spacing.wide",
                "drc.enclosure",
                "drc.extension",
                "drc.overlap",
                "drc.overlap.exact",
                "drc.short",
                "drc.waiver",
            ],
            limitations: [
                "Native JSON input is a kernel fixture format, not a standard mask exchange format.",
            ]
        )
    }

    private func nativeGDSBackend() -> DRCCapabilitySnapshot.Backend {
        DRCCapabilitySnapshot.Backend(
            backendID: "native-gds",
            maturity: "implemented",
            executionMode: "in-process",
            requiresExternalTool: false,
            inputFormats: ["gds", "oasis", "cif", "dxf", "native-json", "layout-tech-json"],
            requiredInputs: ["standard-layout-file", "technology-json", "top-cell"],
            producedArtifacts: ["drc-report", "drc-artifact-manifest", "drc-summary"],
            diagnosticKinds: diagnosticKinds() + ["angle"],
            qualificationTags: [
                "drc.input.cif",
                "drc.input.dxf",
                "drc.input.gds",
                "drc.input.oasis",
                "drc.tech.layer-map",
                "drc.clean",
                "drc.angle",
                "drc.overlap",
                "drc.overlap.exact",
            ],
            limitations: [
                "Current standard-input qualification is focused on deterministic generated standard-mask fixtures.",
                "Rule-deck coverage is limited to the LayoutTech rule model currently implemented by LayoutVerify.",
            ]
        )
    }

    private func magicBackend() -> DRCCapabilitySnapshot.Backend {
        DRCCapabilitySnapshot.Backend(
            backendID: "magic",
            maturity: "external-oracle-adapter",
            executionMode: "headless-batch-process",
            requiresExternalTool: true,
            inputFormats: ["gds", "magic-layout"],
            requiredInputs: ["layout", "top-cell", "magic-pdk-environment"],
            producedArtifacts: ["drc-report", "drc-artifact-manifest", "tool-log"],
            diagnosticKinds: ["external-tool-report"],
            qualificationTags: ["drc.oracle.magic"],
            limitations: [
                "Requires Magic and PDK setup outside the Swift process.",
                "Used for oracle and PDK deck compatibility, not as the preferred standalone path.",
            ]
        )
    }

    private func diagnosticKinds() -> [String] {
        [
            "manufacturingGrid",
            "minimumWidth",
            "minimumArea",
            "maximumDensity",
            "minimumDensity",
            "maximumAntennaRatio",
            "minimumCut",
            "minimumNotch",
            "minimumEnclosedArea",
            "minimumSpacing",
            "minimumEnclosure",
            "minimumExtension",
            "forbiddenOverlap",
            "exactOverlap",
            "differentNetOverlap",
        ]
    }

    private func artifactContracts() -> [DRCCapabilitySnapshot.ArtifactContract] {
        [
            DRCCapabilitySnapshot.ArtifactContract(
                artifactID: "drc-report",
                format: "json",
                producer: "DRCPersistence.DRCArtifactStore",
                consumer: ["Agent", "Human review", "Xcircuite", "DesignFlowKernel"]
            ),
            DRCCapabilitySnapshot.ArtifactContract(
                artifactID: "drc-artifact-manifest",
                format: "json",
                producer: "DRCPersistence.DRCArtifactStore",
                consumer: ["artifact-integrity-gate", "Xcircuite", "CI"]
            ),
            DRCCapabilitySnapshot.ArtifactContract(
                artifactID: "drc-summary",
                format: "json",
                producer: "DRCPersistence.DRCRunSummaryBuilder",
                consumer: ["Agent planning", "Human review", "Xcircuite planning/problem generator"]
            ),
            DRCCapabilitySnapshot.ArtifactContract(
                artifactID: "drc-repair-hints",
                format: "json",
                producer: "DRCCore.DRCRepairHintBuilder",
                consumer: ["Agent planning", "Xcircuite candidate plan generation", "Human review"]
            ),
            DRCCapabilitySnapshot.ArtifactContract(
                artifactID: "signoff-foundry-deck-semantics",
                format: "json",
                producer: "SignoffToolSupport.SignoffDeckSemanticInventory",
                consumer: ["Agent tool selection", "Xcircuite trust gate", "CI", "Human review"]
            ),
            DRCCapabilitySnapshot.ArtifactContract(
                artifactID: "drc-foundry-rule-import-report",
                format: "json",
                producer: "DRCNative.MagicDRCLayoutTechImporter",
                consumer: ["Agent tool selection", "native-gds planning", "CI", "Human review"]
            ),
            DRCCapabilitySnapshot.ArtifactContract(
                artifactID: "drc-corpus-coverage-audit",
                format: "json",
                producer: "DRCCore.DRCCorpusCoverageAuditor",
                consumer: ["Agent gap analysis", "Human review", "CI", "DesignFlowKernel"]
            ),
            DRCCapabilitySnapshot.ArtifactContract(
                artifactID: "drc-magic-rule-import-catalog-inventory",
                format: "json",
                producer: "DRCCLICore.DRCMagicRuleImportCatalogInventoryBuilder",
                consumer: ["Agent preflight", "CI", "Human review"]
            ),
            DRCCapabilitySnapshot.ArtifactContract(
                artifactID: "layout-tech-database",
                format: "json",
                producer: "DRCNative.MagicDRCLayoutTechImporter",
                consumer: ["DRCNative.LayoutGDSDRCBackend", "Agent planning", "Human review"]
            ),
        ]
    }

    private func corpusContract() -> DRCCapabilitySnapshot.CorpusContract {
        DRCCapabilitySnapshot.CorpusContract(
            runner: "DRCCorpusRunner",
            cliFlag: "--corpus",
            committedSpecPath: "Tests/DRCCLICoreTests/Fixtures/DRCCorpus/drc-corpus.json",
            reportArtifact: "drc-corpus-report.json",
            evidenceExportFlag: "--evidence-from-corpus-report",
            qualificationPolicy: "strict unless overridden by corpus spec or --qualification-policy",
            requiredCoverageTags: [
                "drc.antenna",
                "drc.antenna.multi-layer",
                "drc.antenna.process-step",
                "drc.antenna.via-aware",
                "drc.antenna.via-topology",
                "drc.area",
                "drc.clean",
                "drc.cut",
                "drc.cut.minimum",
                "drc.density",
                "drc.density.minimum",
                "drc.enclosed-area",
                "drc.enclosure",
                "drc.extension",
                "drc.extension.minimum",
                "drc.grid",
                "drc.grid.manufacturing",
                "drc.input.cif",
                "drc.input.dxf",
                "drc.input.gds",
                "drc.input.oasis",
                "drc.notch",
                "drc.overlap",
                "drc.overlap.different-net",
                "drc.overlap.exact",
                "drc.overlap.forbidden",
                "drc.short",
                "drc.spacing",
                "drc.spacing.different-net",
                "drc.spacing.directional",
                "drc.spacing.end-of-line",
                "drc.spacing.layer-pair",
                "drc.spacing.net-scope",
                "drc.spacing.parallel-run-length",
                "drc.spacing.same-net",
                "drc.spacing.wide",
                "drc.tech.layer-map",
                "drc.waiver",
                "drc.width",
            ]
        )
    }
}
