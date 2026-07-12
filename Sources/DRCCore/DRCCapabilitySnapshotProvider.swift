public struct DRCCapabilitySnapshotProvider: Sendable {
    public init() {}

    public func snapshot() -> DRCCapabilitySnapshot {
        DRCCapabilitySnapshot(
            engineID: "drcengine",
            ownerPackage: "DRCEngine",
            status: "development-native-core",
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
                "Installed foundry Magic DRC import is exposed through drcengine --import-foundry-magic-rules using signoff profile readiness plus an explicit or bundled Magic LayoutTech import profile; the same route can emit the provenance-bound NativeDRCAntennaArtifact with --native-antenna-out, and a retained independent comparison can be attached through --qualify-native-antenna.",
                "Magic rule import catalog readiness is inspectable before import through drcengine --inspect-magic-rule-import-catalog with explicit --catalog inputs or bounded --pdk-root discovery, producing a drc-magic-rule-import-catalog-inventory JSON artifact with required-file and bundled-profile-resource status.",
                "Sky130 Magic DRC width, same-layer spacing, cross-layer spacing, area, notch, rect-only, angle, surround enclosure, same-layer widespacing, overhang extension, exact-overlap including one-of secondary layer sets, MiM derived-layer, Sky130 hole-empty cifmaxwidth rules, dependency-ordered templayer marker materialization for and/or/and-not/xor/grow/grow-min/shrink/bridge/close operations, non-hole cifmaxwidth forbidden-marker source contracts, and generic Magic-deck minimum-cut/cut-count source policies can be imported into a partial LayoutTechDatabase seed through the generic drcengine --import-magic-rules catalog/profile-resource path or drcengine --import-foundry-magic-rules with Magic types/aliases layer-expression expansion, source contact-stack connectivity, unique stack inference for cut/count source policy lines, derived via/contact definitions, derived minimum-cut seed rules, sourceCutLayerNames/sourceCutAliasCount, sourceContactStacks/sourceContactStackCount, sourceContactDefinitionIDs/sourceContactDefinitionCount, sourceExactOverlapRules/sourceExactOverlapRuleCount, sourceEnclosedHoleRules/sourceEnclosedHoleRuleCount evidence, sourceForbiddenMarkerRules/sourceForbiddenMarkerRuleCount evidence, sourceTempLayerDefinitions/sourceTempLayerOperationCounts evidence, sourceTempLayerMaterializedRuleIDs/sourceTempLayerMaterializedRuleCount evidence, sourceMinimumCutPolicies/sourceMinimumCutPolicyCount evidence, sourceAntennaRules/sourceAntennaRuleCount/sourceAntennaThicknesses evidence for Magic sidewall/surface declarations, and NativeDRCAntennaRuleFactory lowering through drcengine --native-antenna-out; LayoutSpacingRule records, LayoutDerivedLayerRule records, LayoutExactOverlapRule records, allowedAngleStepDegrees records, minEnclosedArea records, LayoutMinimumCutRule minimumCount records, and an auditable drc-foundry-rule-import-report.",
                "Diagnostics carry rule, layer, measured/required values, region, related shape/net IDs, waiver state, and suggested fix fields.",
                "native-gds signoff execution uses LayoutDRCService exact-only geometry mode; PATH and non-rectilinear geometry emit blocking drc.unsupported_exact_geometry diagnostics.",
                "DRCRunSession and DRCCorpusRunSession expose actor-isolated lifecycle events, cooperative cancellation, terminal state, resumable corpus checkpoints, and shutdown that finishes their AsyncStreams.",
                "DefaultDRCEngine validates top-cell, backend identity, timeout, and POSIX environment contracts before backend lookup or execution, enforces the timeout cooperatively for in-process backends, and persists the resolved backend identity into result and manifest artifacts.",
                "Persisted DRC artifact manifests are verified against real files, path containment, byte counts, SHA-256 digests, resolved verdicts, request digests, environment digests, and artifact-root commitments before a run is returned; DRCArtifactManifestVerifier is also available for downstream artifact gates.",
                "Artifact manifests support canonical Ed25519 signatures with an injected DRCArtifactSigner, trusted public-key verification, and CLI key-file wiring; signed-artifact requests fail closed when the trust root is absent or invalid.",
                "Corpus tool evidence can be signed with the same DRCArtifactSigner and revalidated against the current corpus report through DRCCorpusToolEvidenceVerifier, including report digest and recomputed qualification.",
                "Native JSON inputs reject empty or duplicated rectangle/rule IDs, non-finite coordinates and parameters, and non-positive rectangle dimensions before physical rule evaluation; release-gated antenna runs additionally require NativeDRCAntennaMetadata completeness attestations and reject net-bearing antenna conductors without positive gate-area annotations.",
                "Corpus report consumers validate schema, case counts, result identity, duration values, and duplicate case IDs before qualification or coverage audit; coverage audit may intentionally recompute a retained summary from case results.",
                "Independent-correlation corpus evidence compares normalized diagnostic marker fingerprints (rule, kind, layer, region, and related IDs); regression evidence keeps the legacy rule-ID contract.",
                "Saved DRC reports can be converted into typed repair hints for executable layout operations without log scraping.",
                "Spacing and overlap diagnostics export translation repair hints with executable deltaX/deltaY vectors when backend-provided repair geometry is available, including native JSON and standard layout inputs.",
                "Minimum-cut diagnostics export via repair hints with inferred viaDefinitionID, candidate position, existing/required/missing cut counts, and typed relatedViaIDs for existing cut references.",
                "Native minimum-enclosure checks evaluate the union of same-layer rectangles so composite rectangular cover is judged as layout geometry rather than a single best rectangle.",
                "Minimum enclosed-area diagnostics export fill-rectangle repair hints with explicit origin, size, area evidence, and native LVS verification gating.",
                "Minimum-density diagnostics export fill-rectangle repair hints with explicit density-window geometry, measured/required density evidence, target fill area, and native LVS verification gating.",
                "Corpus reports carry run/spec/parent-run provenance, case checkpoints, and completed-state semantics; qualification consumers recompute derived summary and qualification fields before requalification.",
            ],
            openMilestones: [
                "Broaden Magic cut-count import beyond generic source-policy lines and unique stack inference into multi-numeric or ambiguous real-deck variants, remaining unsupported future templayer operations beyond the typed native materialization set, golden foundry DRC cases, and broader Magic oracle agreement.",
                "Broaden standard mask input lanes from deterministic clean/equivalence fixtures into larger foundry-oriented coverage.",
                "Qualify the lowered Magic antenna contract against retained foundry layouts and an independently identified Magic oracle; the native evaluator and source-to-rule lowering contract are implemented, but release evidence is still missing when those tools are unavailable.",
                "Add larger benchmark suites with public PDK-derived rule decks and regression budgets.",
                "Expand repair hint normalization beyond current width, spacing, overlap, notch, enclosed-area, minimum-density, split, and via-cut edits until every active diagnostic kind has a benchmarked executable layout operation.",
                "Add external trust-root rotation and key IDs for multi-tenant release workflows.",
            ]
        )
    }

    private func nativeBackend() -> DRCCapabilitySnapshot.Backend {
        DRCCapabilitySnapshot.Backend(
            backendID: "native",
            maturity: "preview-verified",
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
                "drc.width.maximum",
                "drc.marker",
                "drc.marker.forbidden-layer",
                "drc.area",
                "drc.density",
                "drc.antenna",
                "drc.antenna.cumulative",
                "drc.antenna.detailed",
                "drc.antenna.sidewall",
                "drc.cut",
                "drc.notch",
                "drc.enclosed-area",
                "drc.spacing",
                "drc.spacing.wide",
                "drc.enclosure",
                "drc.enclosure.composite",
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
            maturity: "available-unqualified",
            executionMode: "in-process",
            requiresExternalTool: false,
            inputFormats: ["gds", "oasis", "cif", "dxf", "native-json", "layout-tech-json"],
            requiredInputs: ["standard-layout-file", "technology-json", "top-cell"],
            producedArtifacts: ["drc-report", "drc-artifact-manifest", "drc-summary"],
            diagnosticKinds: nativeGDSDiagnosticKinds(),
            qualificationTags: [
                "drc.input.cif",
                "drc.input.dxf",
                "drc.input.gds",
                "drc.input.oasis",
                "drc.tech.layer-map",
                "drc.antenna",
                "drc.clean",
                "drc.angle",
                "drc.overlap",
                "drc.overlap.exact",
            ],
            limitations: [
                "Current standard-input qualification is focused on deterministic generated standard-mask fixtures.",
                "The standard-input native-gds lane remains limited to the LayoutTech rule model currently implemented by LayoutVerify; its Magic sidewall/surface declarations are still evidence-only, while canonical native-json detailed antenna rules are evaluated by NativeDRC.",
                "This backend is not signoff-qualified; unsupported derived geometry and rule semantics block a clean verdict.",
                "Independent cross-engine marker correlation is available only when the corpus spec opts into the independent-correlation evidence kind and an independently identified oracle is present.",
            ]
        )
    }

    private func magicBackend() -> DRCCapabilitySnapshot.Backend {
        DRCCapabilitySnapshot.Backend(
            backendID: "magic",
            maturity: "independent-reference-adapter",
            executionMode: "headless-batch-process",
            requiresExternalTool: true,
            inputFormats: ["gds", "magic-layout"],
            requiredInputs: ["layout", "top-cell", "magic-pdk-environment"],
            producedArtifacts: ["drc-report", "drc-artifact-manifest", "tool-log"],
            diagnosticKinds: ["external-tool-report"],
            qualificationTags: ["drc.oracle.magic"],
            limitations: [
                "Requires Magic and PDK setup outside the Swift process.",
                "Used as an independent reference lane when backend identity and marker parsing prove independence.",
            ]
        )
    }

    private func diagnosticKinds() -> [String] {
        [
            "manufacturingGrid",
            "minimumWidth",
            "maximumWidth",
            "forbiddenLayer",
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

    private func nativeGDSDiagnosticKinds() -> [String] {
        [
            "minWidth",
            "minSpacing",
            "minArea",
            "notch",
            "rectOnly",
            "angle",
            "minEnclosedArea",
            "enclosure",
            "minimumCut",
            "exactOverlap",
            "forbiddenLayer",
            "density",
            "extension",
            "ruleCoverage",
            "overlapShort",
            "disconnectedOpen",
            "antenna",
            "layout-diagnostic",
        ]
    }

    private func artifactContracts() -> [DRCCapabilitySnapshot.ArtifactContract] {
        [
            DRCCapabilitySnapshot.ArtifactContract(
                artifactID: "drc-report",
                format: "json",
                producer: "DRCPersistence.DRCArtifactStore",
                consumer: ["Agent", "Human review", "Xcircuite", "DesignFlowKernel"],
                integrityEvidenceFields: ["path", "byteCount", "sha256"],
                currentnessVerifier: "drc-artifact-manifest-record",
                verdictFields: ["passed", "completed", "diagnosticSummary"]
            ),
            DRCCapabilitySnapshot.ArtifactContract(
                artifactID: "drc-artifact-manifest",
                format: "json",
                producer: "DRCPersistence.DRCArtifactStore",
                consumer: ["artifact-integrity-gate", "Xcircuite", "CI"],
                integrityEvidenceFields: ["path", "runID", "requestSHA256", "requestEnvironmentSHA256", "artifactRootSHA256", "signature"],
                currentnessVerifier: "outer-run-ledger-reference",
                verdictFields: ["passed", "completed", "verdict", "diagnosticSummary"]
            ),
            DRCCapabilitySnapshot.ArtifactContract(
                artifactID: "drc-summary",
                format: "json",
                producer: "DRCPersistence.DRCRunSummaryBuilder",
                consumer: ["Agent planning", "Human review", "Xcircuite planning/problem generator"],
                integrityEvidenceFields: ["path", "byteCount", "sha256"],
                currentnessVerifier: "summary-artifact-reference",
                verdictFields: ["summary.status", "summary.passed", "summary.completed", "summary.diagnosticSummary"]
            ),
            DRCCapabilitySnapshot.ArtifactContract(
                artifactID: "drc-corpus-tool-evidence",
                format: "json",
                producer: "DRCCore.DRCCorpusToolEvidenceExport",
                consumer: ["Agent", "Human review", "CI", "DesignFlowKernel"],
                integrityEvidenceFields: ["reportPath", "reportSHA256", "summary", "qualification", "signature"],
                currentnessVerifier: "DRCCorpusToolEvidenceVerifier",
                verdictFields: ["status", "toolEvidence.qualification.qualified", "toolEvidence.qualification.failureCodes"]
            ),
            DRCCapabilitySnapshot.ArtifactContract(
                artifactID: "drc-repair-hints",
                format: "json",
                producer: "DRCCore.DRCRepairHintBuilder",
                consumer: ["Agent planning", "Xcircuite candidate plan generation", "Human review"],
                integrityEvidenceFields: ["path", "byteCount", "sha256"],
                currentnessVerifier: "repair-hint-source-report-reference",
                verdictFields: ["status", "activeDiagnosticCount", "hintCount", "unsupportedDiagnosticIndexes"]
            ),
            DRCCapabilitySnapshot.ArtifactContract(
                artifactID: "signoff-foundry-deck-semantics",
                format: "json",
                producer: "SignoffToolSupport.SignoffDeckSemanticInventory",
                consumer: ["Agent tool selection", "Xcircuite trust gate", "CI", "Human review"],
                integrityEvidenceFields: ["path", "byteCount", "sha256"],
                currentnessVerifier: "deck-semantic-inventory-input-reference",
                verdictFields: ["status", "coverageTagResults"]
            ),
            DRCCapabilitySnapshot.ArtifactContract(
                artifactID: "drc-foundry-rule-import-report",
                format: "json",
                producer: "DRCNative.MagicDRCLayoutTechImporter",
                consumer: ["Agent tool selection", "native-gds planning", "CI", "Human review"],
                integrityEvidenceFields: ["path", "byteCount", "sha256"],
                currentnessVerifier: "magic-rule-import-input-reference",
                verdictFields: ["status", "importedRuleCount", "skippedRuleCount", "diagnostics"]
            ),
            DRCCapabilitySnapshot.ArtifactContract(
                artifactID: "drc-native-antenna-artifact",
                format: "json",
                producer: "DRCNative.NativeDRCAntennaArtifact",
                consumer: ["NativeDRC", "Agent planning", "CI", "Human review"],
                integrityEvidenceFields: ["path", "byteCount", "sha256"],
                currentnessVerifier: "magic-rule-import-source-and-profile-digest-reference",
                verdictFields: ["schemaVersion", "sourceDigest", "profileDigest", "nativeRules", "qualification", "oracleEvidence"]
            ),
            DRCCapabilitySnapshot.ArtifactContract(
                artifactID: "drc-corpus-coverage-audit",
                format: "json",
                producer: "DRCCore.DRCCorpusCoverageAuditor",
                consumer: ["Agent gap analysis", "Human review", "CI", "DesignFlowKernel"],
                integrityEvidenceFields: ["path", "byteCount", "sha256"],
                currentnessVerifier: "corpus-report-reference",
                verdictFields: ["status", "coverageTagResults", "blockedReasonCounts"]
            ),
            DRCCapabilitySnapshot.ArtifactContract(
                artifactID: "drc-magic-rule-import-catalog-inventory",
                format: "json",
                producer: "DRCCLICore.DRCMagicRuleImportCatalogInventoryBuilder",
                consumer: ["Agent preflight", "CI", "Human review"],
                integrityEvidenceFields: ["path", "byteCount", "sha256"],
                currentnessVerifier: "catalog-input-reference",
                verdictFields: ["status", "items", "issues"]
            ),
            DRCCapabilitySnapshot.ArtifactContract(
                artifactID: "layout-tech-database",
                format: "json",
                producer: "DRCNative.MagicDRCLayoutTechImporter",
                consumer: ["DRCNative.LayoutGDSDRCBackend", "Agent planning", "Human review"],
                integrityEvidenceFields: ["path", "byteCount", "sha256"],
                currentnessVerifier: "drc-foundry-rule-import-report",
                verdictFields: ["schemaVersion", "name", "layers", "rules"]
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
                "drc.antenna.cumulative",
                "drc.antenna.detailed",
                "drc.antenna.multi-layer",
                "drc.antenna.process-step",
                "drc.antenna.sidewall",
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
                "drc.enclosure.composite",
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
