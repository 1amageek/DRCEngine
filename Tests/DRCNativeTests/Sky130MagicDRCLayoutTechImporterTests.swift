import Foundation
import DRCFoundryImport
import LayoutCore
import LayoutTech
import Testing
@testable import DRCNative

@Suite("Sky130 Magic DRC LayoutTech importer")
struct Sky130MagicDRCLayoutTechImporterTests {
    @Test func exactOverlapSourceRuleRejectsEmptySecondaryLayers() {
        #expect(throws: MagicDRCSourceRuleValidationError.emptyExactOverlapSecondaryLayers(ruleID: "exactOverlap.invalid")) {
            _ = try MagicDRCSourceExactOverlapRule(
                id: "exactOverlap.invalid",
                primaryLayerName: "CONT",
                secondaryLayerNames: [],
                sourceLineNumber: 1,
                sourceLine: "exact_overlap (empty)/a"
            )
        }
        #expect(throws: MagicDRCSourceRuleValidationError.emptyExactOverlapSecondaryLayers(ruleID: "exactOverlap.invalid")) {
            _ = try MagicDRCSourceExactOverlapRule(
                validatingID: "exactOverlap.invalid",
                primaryLayerName: "CONT",
                secondaryLayerNames: [],
                sourceLineNumber: 1,
                sourceLine: "exact_overlap (empty)/a"
            )
        }
    }

    @Test func invalidImportProfileBlocksImportInsteadOfDroppingUnsupportedFeatures() {
        let profile = MagicDRCLayoutTechImportProfile(
            profileID: "test.magic.invalid-profile",
            layerOrder: ["METX", "CUTX", "METY"],
            cutLayerNames: ["CUTX"],
            layerPurposes: ["CUTX": "cut"],
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
                    kind: "unsupported-kind",
                    minimumCutCount: 0
                ),
            ]
        )

        let issueCodes = Set(profile.validationIssues().map(\.code))
        #expect(issueCodes.contains(.unsupportedDerivedLayerOperation))
        #expect(issueCodes.contains(.unsupportedCutStackKind))
        #expect(issueCodes.contains(.invalidMinimumCutCount))

        let result = MagicDRCLayoutTechImporter.importTechnology(
            text: """
            style gdsii
            layer METX metx
              calma 10 0
            drc
              width metx 100 "Metal X width"
            end
            """,
            sourcePath: "/tmp/invalid-profile.magic.tech",
            profile: profile,
            generatedAt: "2026-07-04T00:00:00Z"
        )

        #expect(result.report.status == .blocked)
        #expect(result.report.importedRuleCount == 0)
        #expect(result.report.importedLayerNames.isEmpty)
        #expect(result.technology.layers.isEmpty)
        #expect(result.technology.derivedLayerRules.isEmpty)
        #expect(result.technology.vias.isEmpty)
        #expect(result.report.diagnostics.count == 1)
        #expect(result.report.diagnostics.first?.code == "magic_drc_layouttech_profile_validation_failed")
        #expect(result.report.diagnostics.first?.message.contains("unsupportedDerivedLayerOperation") == true)
        #expect(result.report.diagnostics.first?.message.contains("unsupportedCutStackKind") == true)
        #expect(result.report.diagnostics.first?.message.contains("invalidMinimumCutCount") == true)
    }

    @Test func bundledMagicLayoutTechProfileLoadsProcessDataAsArtifact() throws {
        let profile = try MagicDRCLayoutTechImportProfile.bundledMagicLayoutTechProfile(
            resourceName: "sky130-magic-layouttech-profile"
        )

        #expect(profile.schemaVersion == 1)
        #expect(profile.profileID == "sky130.magic.layouttech")
        #expect(profile.layerOrder.first == "DNWELL")
        #expect(profile.cutLayerNames.contains("VIA1"))
        #expect(profile.layerOrder.contains("HVI"))
        #expect(profile.baseLayerNames.contains("RPM"))
        #expect(profile.canonicalLayerAliases["URPM"]?.contains("urpm") == true)
        #expect(profile.planeBaseLayerNames["active"] == "DIFF")
        #expect(profile.canonicalLayerAliases["VIA1"]?.contains("v1") == true)
        #expect(profile.derivedLayerSeeds.contains { $0.targetLayerName == "MIMCC" })
        #expect(profile.cutStackConnections.contains {
            $0.id == "VIA1"
                && $0.cutLayerName == "VIA1"
                && $0.bottomLayerName == "MET1"
                && $0.topLayerName == "MET2"
                && $0.kind == "via"
        })
    }

    @Test func importProfileSuppliesProcessLayerAndCutStackData() throws {
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
                    kind: "via",
                    minimumCutCount: 2
                ),
            ]
        )
        let result = MagicDRCLayoutTechImporter.importTechnology(
            text: """
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
            end
            """,
            sourcePath: "/tmp/generic.magic.tech",
            profile: profile,
            generatedAt: "2026-06-24T00:00:00Z"
        )

        let metX = LayoutLayerID(name: "METX", purpose: "drawing")
        let cutX = LayoutLayerID(name: "CUTX", purpose: "cut")
        let metY = LayoutLayerID(name: "METY", purpose: "drawing")
        #expect(result.report.status == .complete)
        #expect(result.report.importedLayerNames == ["METX", "CUTX", "METY"])
        #expect(result.technology.layerDefinition(for: metX)?.displayName == "Metal X")
        #expect(result.technology.layerDefinition(for: cutX)?.gdsLayer == 11)
        let via = result.technology.viaDefinition(for: "CUTX")
        #expect(via?.cutLayer == cutX)
        #expect(via?.bottomLayer == metX)
        #expect(via?.topLayer == metY)
        #expect(via?.cutSize.width == 0.05)
        #expect(via?.cutSpacing == 0.06)
        #expect(via?.enclosure.bottom == 0.02)
        #expect(via?.enclosure.top == 0.03)
        #expect(result.report.derivedViaDefinitionIDs == ["CUTX"])
        #expect(result.report.derivedMinimumCutRuleIDs == ["mincut.CUTX"])
        #expect(result.report.profileMinimumCutPolicyIDs == ["profileMinimumCut.CUTX"])
        #expect(result.report.profileMinimumCutPolicyCount == 1)
        #expect(result.report.profileMinimumCutPolicies.first?.minimumCount == 2)
        let minimumCutRule = result.technology.minimumCutRule(for: "mincut.CUTX")
        #expect(minimumCutRule?.minimumCount == 2)
    }

    @Test func importProfileDoesNotFallbackToSky130LayerKnowledge() {
        let profile = MagicDRCLayoutTechImportProfile(
            profileID: "test.magic.no-sky130-fallback",
            layerOrder: ["METX"],
            baseLayerNames: ["METX"]
        )
        let result = MagicDRCLayoutTechImporter.importTechnology(
            text: """
            style gdsii
            layer METX metx
              calma 10 0
            layer VIA1 via1
              calma 11 0
            drc
              width metx 100 "Metal X width"
              width via1 50 "Via1 should not import without profile support"
              spacing active metx 60 touching_illegal "Active alias should not use Sky130 fallback"
            end
            """,
            sourcePath: "/tmp/no-sky130-fallback.magic.tech",
            profile: profile,
            generatedAt: "2026-06-24T00:00:00Z"
        )

        #expect(result.report.status == .partial)
        #expect(result.report.importedLayerNames == ["METX"])
        #expect(result.report.importedFamilyCounts["width"] == 1)
        #expect(result.report.skippedFamilyCounts["width"] == 1)
        #expect(result.report.skippedFamilyCounts["spacing"] == 1)
        #expect(result.report.importedRules.map(\.layerName) == ["METX"])
    }

    @Test func unsupportedMagicRuleFamiliesAreReportedAsPartialImport() {
        let profile = MagicDRCLayoutTechImportProfile(
            profileID: "test.magic.unsupported-families",
            layerOrder: ["METX"],
            baseLayerNames: ["METX"]
        )
        let result = MagicDRCLayoutTechImporter.importTechnology(
            text: """
            style gdsii
            layer METX metx
              calma 10 0
            drc
              width metx 100 "Metal X width"
              edge4way metx 100 "Unsupported edge rule"
              cifspacing metx 120 "Unsupported CIF spacing"
              extend metx 30 "Unsupported extend"
              cifwidth metx 80 "Unsupported CIF width"
            end
            """,
            sourcePath: "/tmp/unsupported-families.magic.tech",
            profile: profile,
            generatedAt: "2026-06-24T00:00:00Z"
        )

        #expect(result.report.status == .partial)
        #expect(result.report.importedFamilyCounts["width"] == 1)
        #expect(result.report.skippedFamilyCounts["edge4way"] == 1)
        #expect(result.report.skippedFamilyCounts["cifspacing"] == 1)
        #expect(result.report.skippedFamilyCounts["extend"] == 1)
        #expect(result.report.skippedFamilyCounts["cifwidth"] == 1)
        #expect(result.report.skippedRuleCount == 4)
        #expect(result.report.diagnostics.count == 4)
        #expect(result.report.diagnostics.allSatisfy { $0.code == "unsupported_magic_drc_family" })
    }

    @Test func unrecognizedMagicRuleFamiliesInsideDRCBlockAreReportedAsPartialImport() {
        let profile = MagicDRCLayoutTechImportProfile(
            profileID: "test.magic.unrecognized-family",
            layerOrder: ["METX"],
            baseLayerNames: ["METX"]
        )
        let result = MagicDRCLayoutTechImporter.importTechnology(
            text: """
            style gdsii
            layer METX metx
              calma 10 0
            drc
              width metx 100 "Metal X width"
              futurefamily metx 140 "Future Magic DRC family"
            end
            """,
            sourcePath: "/tmp/unrecognized-family.magic.tech",
            profile: profile,
            generatedAt: "2026-06-24T00:00:00Z"
        )

        #expect(result.report.status == .partial)
        #expect(result.report.importedFamilyCounts["width"] == 1)
        #expect(result.report.skippedFamilyCounts["futurefamily"] == 1)
        #expect(result.report.skippedRuleCount == 1)
        let diagnostic = result.report.diagnostics.first
        #expect(diagnostic?.code == "unsupported_magic_drc_family")
        #expect(diagnostic?.sourceLineNumber == 6)
    }

    @Test func importProfileLayerSetAliasesSupplyGenericActiveSemantics() {
        let profile = MagicDRCLayoutTechImportProfile(
            profileID: "test.magic.custom-active",
            layerOrder: ["METX"],
            baseLayerNames: ["METX"],
            layerSetAliases: ["active": ["METX"]]
        )
        let result = MagicDRCLayoutTechImporter.importTechnology(
            text: """
            style gdsii
            layer METX metx
              calma 10 0
            drc
              width metx 100 "Metal X width"
              spacing active metx 60 touching_illegal "Active alias comes from profile"
            end
            """,
            sourcePath: "/tmp/custom-active.magic.tech",
            profile: profile,
            generatedAt: "2026-06-24T00:00:00Z"
        )

        #expect(result.report.status == .complete)
        #expect(result.report.importedLayerNames == ["METX"])
        #expect(result.report.importedFamilyCounts["width"] == 1)
        #expect(result.report.importedFamilyCounts["spacing"] == 1)
        #expect(result.technology.ruleSet(for: LayoutLayerID(name: "METX", purpose: "drawing"))?.minSpacing == 0.06)
    }

    private static func importSky130Fixture(
        text: String,
        sourcePath: String,
        generatedAt: String? = nil
    ) throws -> MagicDRCLayoutTechImport {
        let profile = try MagicDRCLayoutTechImportProfile.bundledMagicLayoutTechProfile(
            resourceName: "sky130-magic-layouttech-profile"
        )
        return MagicDRCLayoutTechImporter.importTechnology(
            text: text,
            sourcePath: sourcePath,
            profile: profile,
            generatedAt: generatedAt
        )
    }

    private static func expectZeroRuleSet(
        _ technology: LayoutTechDatabase,
        for layerID: LayoutLayerID
    ) {
        let ruleSet = technology.ruleSet(for: layerID)
        #expect(ruleSet != nil)
        #expect(ruleSet?.minWidth == 0)
        #expect(ruleSet?.minSpacing == 0)
        #expect(ruleSet?.minArea == 0)
        #expect(ruleSet?.minDensity == 0)
        #expect(ruleSet?.maxDensity == 1)
    }

    @Test func importsRepresentableWidthSpacingAndAreaRules() throws {
        let result = try Self.importSky130Fixture(
            text: Self.fixtureMagicTech,
            sourcePath: "/tmp/sky130A.tech",
            generatedAt: "2026-06-23T00:00:00Z"
        )

        #expect(result.report.status == .complete)
        #expect(result.report.kind == "drc-foundry-rule-import")
        #expect(result.report.importedFamilyCounts["width"] == 2)
        #expect(result.report.importedFamilyCounts["spacing"] == 2)
        #expect(result.report.importedFamilyCounts["area"] == 1)
        #expect(result.report.importedFamilyCounts["notch"] == 1)
        #expect(result.report.importedFamilyCounts["rect_only"] == 1)
        #expect(result.report.importedFamilyCounts["surround"] == 2)
        #expect(result.report.importedFamilyCounts["widespacing"] == 1)
        #expect(result.report.importedFamilyCounts["overhang"] == 1)
        #expect(result.report.importedFamilyCounts["exact_overlap"] == 1)
        #expect(result.report.importedFamilyCounts["angles"] == 1)
        #expect(result.report.importedFamilyCounts["cifmaxwidth"] == 1)
        #expect(result.report.skippedFamilyCounts["angles"] == nil)
        #expect(result.report.skippedFamilyCounts["exact_overlap"] == nil)
        #expect(result.report.skippedFamilyCounts["cifmaxwidth"] == nil)
        #expect(result.report.importedLayerNames == ["DIFF", "POLY", "MET1", "VIA1", "MET2"])
        #expect(result.report.sourceCutLayerNames == ["VIA1"])
        #expect(result.report.sourceCutAliasCount == 5)
        #expect(result.report.sourceContactDefinitionIDs == ["VIA1"])
        #expect(result.report.sourceContactDefinitionCount == 1)
        #expect(result.report.sourceExactOverlapRuleIDs == ["exactOverlap.VIA1.MET1"])
        #expect(result.report.sourceExactOverlapRuleCount == 1)
        #expect(result.report.sourceExactOverlapRules.first?.primaryLayerName == "VIA1")
        #expect(result.report.sourceExactOverlapRules.first?.secondaryLayerName == "MET1")
        #expect(result.report.sourceEnclosedHoleRuleIDs == ["enclosedHole.MET1"])
        #expect(result.report.sourceEnclosedHoleRuleCount == 1)
        #expect(result.report.sourceEnclosedHoleRules.first?.layerName == "MET1")
        #expect(result.report.sourceEnclosedHoleRules.first?.holeLayerName == "m1_hole_empty")
        #expect(result.report.sourceEnclosedHoleRules.first?.smallHoleLayerName == "m1_small_hole")
        #expect(result.report.sourceEnclosedHoleRules.first?.minimumArea == 0.14)
        #expect(result.report.sourceTempLayerDefinitionIDs == [
            "tempLayer.m1_small_hole",
            "tempLayer.m1_hole_empty",
        ])
        #expect(result.report.sourceTempLayerDefinitionCount == 2)
        #expect(result.report.sourceTempLayerOperationCounts["close"] == 1)
        #expect(result.report.sourceTempLayerOperationCounts["and-not"] == 1)
        let holeEmptyTempLayer = result.report.sourceTempLayerDefinitions.first {
            $0.name == "m1_hole_empty"
        }
        #expect(holeEmptyTempLayer?.initialTerms == ["m1_small_hole"])
        #expect(holeEmptyTempLayer?.referencedTempLayerNames == ["m1_small_hole"])
        #expect(holeEmptyTempLayer?.operationNames == ["and-not"])
        #expect(result.report.derivedViaDefinitionIDs == ["VIA1"])
        #expect(result.report.derivedContactDefinitionIDs.isEmpty)
        #expect(result.report.derivedMinimumCutRuleIDs == ["mincut.VIA1"])

        let diff = LayoutLayerID(name: "DIFF", purpose: "drawing")
        let poly = LayoutLayerID(name: "POLY", purpose: "drawing")
        let met1 = LayoutLayerID(name: "MET1", purpose: "drawing")
        let met2 = LayoutLayerID(name: "MET2", purpose: "drawing")
        let via1 = LayoutLayerID(name: "VIA1", purpose: "cut")
        #expect(result.technology.layerDefinition(for: diff)?.gdsLayer == 65)
        #expect(result.technology.layerDefinition(for: poly)?.gdsLayer == 66)
        let layer = result.technology.layerDefinition(for: met1)
        #expect(layer?.gdsLayer == 68)
        #expect(layer?.gdsDatatype == 20)
        #expect(result.technology.layerDefinition(for: met2)?.gdsLayer == 69)
        #expect(result.technology.layerDefinition(for: via1)?.gdsLayer == 71)
        #expect(result.technology.layerDefinition(for: via1)?.gdsDatatype == 20)

        let rules = result.technology.ruleSet(for: met1)
        #expect(rules?.minWidth == 0.14)
        #expect(rules?.minSpacing == 0.14)
        #expect(rules?.minArea == 0.083)
        #expect(rules?.minNotch == 0.28)
        #expect(rules?.wideWidthThreshold == 3.0)
        #expect(rules?.wideSpacing == 0.9)
        #expect(rules?.minEnclosedArea == 0.14)
        #expect(rules?.requiresRectangular == true)
        #expect(rules?.allowedAngleStepDegrees == 45)
        #expect(result.technology.ruleSet(for: via1)?.minWidth == 0.15)
        #expect(result.technology.ruleSet(for: via1)?.minSpacing == 0.17)
        let enclosure = result.technology.enclosureRule(outer: met1, inner: via1)
        #expect(enclosure?.minEnclosure == 0.03)
        #expect(result.technology.enclosureRule(outer: met2, inner: via1)?.minEnclosure == 0.04)
        let viaDefinition = result.technology.viaDefinition(for: "VIA1")
        #expect(viaDefinition?.cutLayer == via1)
        #expect(viaDefinition?.bottomLayer == met1)
        #expect(viaDefinition?.topLayer == met2)
        #expect(viaDefinition?.cutSize.width == 0.15)
        #expect(viaDefinition?.cutSize.height == 0.15)
        #expect(viaDefinition?.cutSpacing == 0.17)
        #expect(viaDefinition?.enclosure.bottom == 0.03)
        #expect(viaDefinition?.enclosure.top == 0.04)
        let minimumCutRule = result.technology.minimumCutRule(for: "mincut.VIA1")
        #expect(minimumCutRule?.cutLayer == via1)
        #expect(minimumCutRule?.bottomLayer == met1)
        #expect(minimumCutRule?.topLayer == met2)
        #expect(minimumCutRule?.minimumCount == 1)
        let exactOverlapRule = result.technology.exactOverlapRule(for: "exactOverlap.VIA1.MET1")
        #expect(exactOverlapRule?.primaryLayer == via1)
        #expect(exactOverlapRule?.secondaryLayer == met1)
        #expect(exactOverlapRule?.tolerance == 0)
        let surroundRule = result.report.importedRules.first { $0.family == "surround" }
        #expect(surroundRule?.layerName == "MET1")
        #expect(surroundRule?.secondaryLayerName == "VIA1")
        #expect(surroundRule?.value == 0.03)
        let wideSpacingRule = result.report.importedRules.first { $0.family == "widespacing" }
        #expect(wideSpacingRule?.layerName == "MET1")
        #expect(wideSpacingRule?.thresholdValue == 3.0)
        #expect(wideSpacingRule?.value == 0.9)
        let notchRule = result.report.importedRules.first { $0.family == "notch" }
        #expect(notchRule?.layerName == "MET1")
        #expect(notchRule?.value == 0.28)
        let rectOnlyRule = result.report.importedRules.first { $0.family == "rect_only" }
        #expect(rectOnlyRule?.layerName == "MET1")
        #expect(rectOnlyRule?.value == 1)
        let angleRule = result.report.importedRules.first { $0.family == "angles" }
        #expect(angleRule?.layerName == "MET1")
        #expect(angleRule?.value == 45)
        let enclosedHoleRule = result.report.importedRules.first { $0.family == "cifmaxwidth" }
        #expect(enclosedHoleRule?.layerName == "MET1")
        #expect(enclosedHoleRule?.value == 0.14)
        let overhang = result.technology.extensionRule(extending: poly, enclosed: diff, direction: .horizontal)
        #expect(overhang?.minExtension == 0.13)
        let verticalOverhang = result.technology.extensionRule(extending: poly, enclosed: diff, direction: .vertical)
        #expect(verticalOverhang?.minExtension == 0.13)
        let overhangRule = result.report.importedRules.first { $0.family == "overhang" }
        #expect(overhangRule?.layerName == "POLY")
        #expect(overhangRule?.secondaryLayerName == "DIFF")
        #expect(overhangRule?.value == 0.13)
    }

    @Test func unresolvedLayerPairIsSkippedWithoutBlockingImportedSeed() throws {
        let result = try Self.importSky130Fixture(
            text: """
            style gdsii
            layer MET1 allm1
              calma 68 20
            types
              metal1 metal1,m1,met1
            end
            drc
              width m1 140 "Metal1 width"
              spacing m1 unknown_layer 140 touching_illegal "Unknown spacing"
            end
            """,
            sourcePath: "/tmp/sky130A.tech",
            generatedAt: "2026-06-23T00:00:00Z"
        )

        #expect(result.report.status == .partial)
        #expect(result.report.importedRuleCount == 1)
        #expect(result.report.skippedFamilyCounts["spacing"] == 1)
        #expect(result.report.diagnostics.contains { $0.code == "magic_drc_layer_pair_unresolved" })
    }

    @Test func blocksWhenNoRepresentableRulesAreImported() throws {
        let result = try Self.importSky130Fixture(
            text: """
            style gdsii
            layer MET1 allm1
              calma 68 20
            drc
              surround via1 met1 30 "Metal1 surround"
            end
            """,
            sourcePath: "/tmp/sky130A.tech",
            generatedAt: "2026-06-23T00:00:00Z"
        )

        #expect(result.report.status == .blocked)
        #expect(result.technology.layers.isEmpty)
        #expect(result.report.importedRuleCount == 0)
        #expect(result.report.skippedFamilyCounts["surround"] == 1)
    }

    @Test func importReportRejectsMissingEvidenceFields() {
        let data = Data("""
        {
          "schemaVersion": 1,
          "kind": "drc-foundry-rule-import",
          "generatedAt": "2026-06-23T00:00:00Z",
          "status": "partial",
          "sourcePath": "/tmp/sky130A.tech",
          "supportedRuleFamilies": ["width"],
          "importedRuleCount": 1,
          "skippedRuleCount": 0,
          "importedFamilyCounts": { "width": 1 },
          "skippedFamilyCounts": {},
          "importedLayerNames": ["MET1"],
          "sourceLayerCount": 1,
          "importedRules": [
            {
              "family": "width",
              "layerName": "MET1",
              "value": 0.14,
              "sourceLineNumber": 1,
              "sourceLine": "width met1 140"
            }
          ],
          "diagnostics": []
        }
        """.utf8)

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(MagicDRCLayoutTechImportReport.self, from: data)
        }
    }

    @Test func nonHoleCIFMaxWidthDirectBooleanMarkerMaterializes() throws {
        let result = try Self.importSky130Fixture(
            text: """
            style gdsii
            layer DNWELL dnwell
              calma 64 18
            layer NWELL nwell
              calma 64 20
            style drc
              templayer nwell_missing nwell
                and-not dnwell
            drc
              width nwell 840 "Nwell width"
              cifmaxwidth nwell_missing 0 bend_illegal "Nwell missing marker"
            end
            """,
            sourcePath: "/tmp/sky130A.tech",
            generatedAt: "2026-06-23T00:00:00Z"
        )

        #expect(result.report.status == .complete)
        #expect(result.report.importedRuleCount == 1)
        #expect(result.report.importedFamilyCounts["width"] == 1)
        #expect(result.report.skippedFamilyCounts["cifmaxwidth"] == nil)
        #expect(result.report.sourceEnclosedHoleRules.isEmpty)
        #expect(result.report.sourceForbiddenMarkerRuleIDs == ["forbiddenMarker.nwell_missing"])
        #expect(result.report.sourceForbiddenMarkerRuleCount == 1)
        #expect(result.report.sourceForbiddenMarkerRules.first?.markerLayerName == "nwell_missing")
        #expect(result.report.sourceForbiddenMarkerRules.first?.definitionLine?.contains("templayer nwell_missing") == true)
        let tempLayer = result.report.sourceTempLayerDefinitions.first { $0.name == "nwell_missing" }
        #expect(tempLayer?.id == "tempLayer.nwell_missing")
        #expect(tempLayer?.initialTerms == ["nwell"])
        #expect(tempLayer?.operations.map(\.command) == ["and-not"])
        #expect(tempLayer?.referencedLayerNames == ["DNWELL", "NWELL"])
        #expect(tempLayer?.referencedTempLayerNames.isEmpty == true)
        #expect(tempLayer?.unresolvedReferences.isEmpty == true)
        #expect(result.report.sourceTempLayerOperationCounts["and-not"] == 1)
        #expect(result.report.sourceTempLayerMaterializedRuleIDs == ["magic.templayer.nwell_missing"])
        #expect(result.report.sourceTempLayerMaterializedRuleCount == 1)
        #expect(result.technology.derivedLayerRules.contains { rule in
            rule.id == "magic.templayer.nwell_missing"
                && rule.targetLayer == LayoutLayerID(name: "nwell_missing", purpose: "marker")
                && rule.sourceLayers == [
                    LayoutLayerID(name: "NWELL", purpose: "drawing"),
                    LayoutLayerID(name: "DNWELL", purpose: "drawing"),
                ]
                && rule.operation == .difference
        })
        #expect(result.technology.forbiddenLayerRule(for: "forbiddenMarker.nwell_missing")?.layer.name == "nwell_missing")
        #expect(result.technology.forbiddenLayerRule(for: "forbiddenMarker.nwell_missing")?.layer.purpose == "marker")
        #expect(!result.report.diagnostics.contains {
            $0.code == "magic_drc_cifmaxwidth_marker_materialization_deferred"
        })
    }

    @Test func nonHoleCIFMaxWidthXORMarkerMaterializes() throws {
        let result = try Self.importSky130Fixture(
            text: """
            style gdsii
            layer DNWELL dnwell
              calma 64 18
            layer NWELL nwell
              calma 64 20
            style drc
              templayer nwell_missing nwell
                xor dnwell
            drc
              width nwell 840 "Nwell width"
              cifmaxwidth nwell_missing 0 bend_illegal "Nwell missing marker"
            end
            """,
            sourcePath: "/tmp/sky130A-xor-templayer.tech",
            generatedAt: "2026-06-23T00:00:00Z"
        )

        #expect(result.report.status == .complete)
        #expect(result.report.importedFamilyCounts["width"] == 1)
        #expect(result.report.skippedFamilyCounts["cifmaxwidth"] == nil)
        #expect(result.report.sourceForbiddenMarkerRuleIDs == ["forbiddenMarker.nwell_missing"])
        #expect(result.report.sourceForbiddenMarkerRuleCount == 1)
        let tempLayer = result.report.sourceTempLayerDefinitions.first { $0.name == "nwell_missing" }
        #expect(tempLayer?.operations.map(\.command) == ["xor"])
        #expect(tempLayer?.operationNames == ["xor"])
        #expect(result.report.sourceTempLayerOperationCounts["xor"] == 1)
        #expect(result.report.sourceTempLayerMaterializedRuleIDs == ["magic.templayer.nwell_missing"])
        #expect(result.report.sourceTempLayerMaterializedRuleCount == 1)
        #expect(result.technology.derivedLayerRules.contains { rule in
            rule.id == "magic.templayer.nwell_missing"
                && rule.targetLayer == LayoutLayerID(name: "nwell_missing", purpose: "marker")
                && rule.sourceLayers == [
                    LayoutLayerID(name: "NWELL", purpose: "drawing"),
                    LayoutLayerID(name: "DNWELL", purpose: "drawing"),
                ]
                && rule.operation == .xor
        })
        #expect(!result.report.diagnostics.contains {
            $0.code == "magic_drc_cifmaxwidth_marker_materialization_deferred"
        })
    }

    @Test func nonHoleCIFMaxWidthUnsupportedFutureTempLayerOperationStaysPartial() throws {
        let result = try Self.importSky130Fixture(
            text: """
            style gdsii
            layer DNWELL dnwell
              calma 64 18
            layer NWELL nwell
              calma 64 20
            style drc
              templayer nwell_missing nwell
                edge4way dnwell
            drc
              width nwell 840 "Nwell width"
              cifmaxwidth nwell_missing 0 bend_illegal "Nwell missing marker"
            end
            """,
            sourcePath: "/tmp/sky130A-unsupported-templayer.tech",
            generatedAt: "2026-06-23T00:00:00Z"
        )

        #expect(result.report.status == .partial)
        #expect(result.report.importedFamilyCounts["width"] == 1)
        #expect(result.report.skippedFamilyCounts["cifmaxwidth"] == 1)
        #expect(result.report.sourceForbiddenMarkerRuleIDs == ["forbiddenMarker.nwell_missing"])
        #expect(result.report.sourceForbiddenMarkerRuleCount == 1)
        let tempLayer = result.report.sourceTempLayerDefinitions.first { $0.name == "nwell_missing" }
        #expect(tempLayer?.operations.map(\.command) == ["edge4way"])
        #expect(tempLayer?.operationNames == ["edge4way"])
        #expect(result.report.sourceTempLayerOperationCounts["edge4way"] == 1)
        #expect(result.report.sourceTempLayerMaterializedRuleIDs.isEmpty)
        #expect(result.report.sourceTempLayerMaterializedRuleCount == 0)
        #expect(result.report.diagnostics.contains {
            $0.code == "magic_drc_cifmaxwidth_marker_materialization_deferred"
        })
        #expect(!result.technology.derivedLayerRules.contains {
            $0.id == "magic.templayer.nwell_missing"
        })
    }

    @Test func nonHoleCIFMaxWidthGrowShrinkMarkerMaterializes() throws {
        let result = try Self.importSky130Fixture(
            text: """
            style gdsii
            layer DNWELL dnwell
              calma 64 18
            layer NWELL nwell
              calma 64 20
            style drc
              templayer dnwell_shrink dnwell
                shrink 1000
              templayer nwell_missing dnwell
                grow 400
                and-not dnwell_shrink
                and-not nwell
            drc
              width dnwell 3000 "Deep nwell width"
              width nwell 840 "Nwell width"
              cifmaxwidth nwell_missing 0 bend_illegal "Nwell missing marker"
            end
            """,
            sourcePath: "/tmp/sky130A.tech",
            generatedAt: "2026-06-23T00:00:00Z"
        )

        #expect(result.report.status == .complete)
        #expect(result.report.importedRuleCount == 2)
        #expect(result.report.skippedFamilyCounts["cifmaxwidth"] == nil)
        #expect(result.report.sourceTempLayerMaterializedRuleIDs == ["magic.templayer.nwell_missing"])
        #expect(result.report.sourceTempLayerMaterializedRuleCount == 1)
        #expect(result.report.sourceTempLayerOperationCounts["grow"] == 1)
        #expect(result.report.sourceTempLayerOperationCounts["shrink"] == 1)
        #expect(result.report.sourceTempLayerOperationCounts["and-not"] == 2)
        #expect(result.technology.derivedLayerRules.contains { rule in
            rule.id == "magic.templayer.dnwell_shrink"
                && rule.targetLayer == LayoutLayerID(name: "dnwell_shrink", purpose: "derived")
                && rule.sourceLayers == [LayoutLayerID(name: "DNWELL", purpose: "drawing")]
                && rule.operation == .shrink
                && rule.operationDistance == 1.0
        })
        #expect(result.technology.derivedLayerRules.contains { rule in
            rule.id == "magic.templayer.nwell_missing.step1"
                && rule.operation == .grow
                && rule.operationDistance == 0.4
        })
        #expect(result.technology.derivedLayerRules.contains { rule in
            rule.id == "magic.templayer.nwell_missing"
                && rule.targetLayer == LayoutLayerID(name: "nwell_missing", purpose: "marker")
                && rule.operation == .difference
        })
        #expect(!result.report.diagnostics.contains {
            $0.code == "magic_drc_cifmaxwidth_marker_materialization_deferred"
        })
    }

    @Test func nonHoleCIFMaxWidthGrowMinMarkerMaterializes() throws {
        let result = try Self.importSky130Fixture(
            text: """
            style gdsii
            layer MET1 allm1
              calma 68 20
            types
              metal1 metal1,m1,met1
            end
            style drc
              templayer m1_short_marker m1
                grow-min 200
            drc
              width m1 140 "Metal1 width"
              cifmaxwidth m1_short_marker 0 bend_illegal "Metal1 short marker"
            end
            """,
            sourcePath: "/tmp/sky130A.tech",
            generatedAt: "2026-06-25T00:00:00Z"
        )

        #expect(result.report.status == .complete)
        #expect(result.report.skippedFamilyCounts["cifmaxwidth"] == nil)
        #expect(result.report.sourceTempLayerOperationCounts["grow-min"] == 1)
        #expect(result.report.sourceTempLayerMaterializedRuleIDs == ["magic.templayer.m1_short_marker"])
        #expect(result.report.sourceTempLayerMaterializedRuleCount == 1)
        #expect(result.technology.derivedLayerRules.contains { rule in
            rule.id == "magic.templayer.m1_short_marker"
                && rule.targetLayer == LayoutLayerID(name: "m1_short_marker", purpose: "marker")
                && rule.sourceLayers == [LayoutLayerID(name: "MET1", purpose: "drawing")]
                && rule.operation == .growMin
                && rule.operationDistance == 0.2
        })
        #expect(!result.report.diagnostics.contains {
            $0.code == "magic_drc_cifmaxwidth_marker_materialization_deferred"
        })
    }

    @Test func nonHoleCIFMaxWidthBridgeMarkerMaterializes() throws {
        let result = try Self.importSky130Fixture(
            text: """
            style gdsii
            layer NWELL nwell
              calma 64 20
            style drc
              templayer nwell_corner_bridge nwell
                bridge 400
                and-not nwell
            drc
              width nwell 840 "Nwell width"
              cifmaxwidth nwell_corner_bridge 0 bend_illegal "Nwell bridge marker"
            end
            """,
            sourcePath: "/tmp/sky130A.tech",
            generatedAt: "2026-06-28T00:00:00Z"
        )

        #expect(result.report.status == .complete)
        #expect(result.report.skippedFamilyCounts["cifmaxwidth"] == nil)
        #expect(result.report.sourceTempLayerOperationCounts["bridge"] == 1)
        #expect(result.report.sourceTempLayerOperationCounts["and-not"] == 1)
        #expect(result.report.sourceTempLayerMaterializedRuleIDs == ["magic.templayer.nwell_corner_bridge"])
        #expect(result.report.sourceTempLayerMaterializedRuleCount == 1)
        #expect(result.technology.derivedLayerRules.contains { rule in
            rule.id == "magic.templayer.nwell_corner_bridge.step1"
                && rule.targetLayer == LayoutLayerID(name: "nwell_corner_bridge.step1", purpose: "derived")
                && rule.sourceLayers == [LayoutLayerID(name: "NWELL", purpose: "drawing")]
                && rule.operation == .bridge
                && rule.operationDistance == 0.4
                && rule.operationWidth == 0.4
        })
        #expect(result.technology.derivedLayerRules.contains { rule in
            rule.id == "magic.templayer.nwell_corner_bridge"
                && rule.targetLayer == LayoutLayerID(name: "nwell_corner_bridge", purpose: "marker")
                && rule.operation == .difference
        })
        Self.expectZeroRuleSet(
            result.technology,
            for: LayoutLayerID(name: "nwell_corner_bridge.step1", purpose: "derived")
        )
        Self.expectZeroRuleSet(
            result.technology,
            for: LayoutLayerID(name: "nwell_corner_bridge", purpose: "marker")
        )
        #expect(!result.report.diagnostics.contains {
            $0.code == "magic_drc_cifmaxwidth_marker_materialization_deferred"
        })
    }

    @Test func nonHoleCIFMaxWidthCloseMarkerMaterializes() throws {
        let result = try Self.importSky130Fixture(
            text: """
            style gdsii
            layer MET1 allm1
              calma 68 20
            types
              metal1 metal1,m1,met1
            end
            style drc
              templayer m1_closed_holes m1
                close 140000
                and-not m1
            drc
              width m1 140 "Metal1 width"
              cifmaxwidth m1_closed_holes 0 bend_illegal "Metal1 close marker"
            end
            """,
            sourcePath: "/tmp/sky130A.tech",
            generatedAt: "2026-06-28T00:00:00Z"
        )

        #expect(result.report.status == .complete)
        #expect(result.report.skippedFamilyCounts["cifmaxwidth"] == nil)
        #expect(result.report.sourceTempLayerOperationCounts["close"] == 1)
        #expect(result.report.sourceTempLayerOperationCounts["and-not"] == 1)
        #expect(result.report.sourceTempLayerMaterializedRuleIDs == ["magic.templayer.m1_closed_holes"])
        #expect(result.report.sourceTempLayerMaterializedRuleCount == 1)
        #expect(result.technology.derivedLayerRules.contains { rule in
            rule.id == "magic.templayer.m1_closed_holes.step1"
                && rule.targetLayer == LayoutLayerID(name: "m1_closed_holes.step1", purpose: "derived")
                && rule.sourceLayers == [LayoutLayerID(name: "MET1", purpose: "drawing")]
                && rule.operation == .close
                && rule.operationDistance == 0.14
        })
        #expect(result.technology.derivedLayerRules.contains { rule in
            rule.id == "magic.templayer.m1_closed_holes"
                && rule.targetLayer == LayoutLayerID(name: "m1_closed_holes", purpose: "marker")
                && rule.operation == .difference
        })
        Self.expectZeroRuleSet(
            result.technology,
            for: LayoutLayerID(name: "m1_closed_holes.step1", purpose: "derived")
        )
        Self.expectZeroRuleSet(
            result.technology,
            for: LayoutLayerID(name: "m1_closed_holes", purpose: "marker")
        )
        #expect(!result.report.diagnostics.contains {
            $0.code == "magic_drc_cifmaxwidth_marker_materialization_deferred"
        })
    }

    @Test func nonHoleCIFMaxWidthBloatAllAndMaskHintsMarkerMaterializes() throws {
        let result = try Self.importSky130Fixture(
            text: """
            style gdsii
            layer DNWELL dnwell
              calma 64 18
            layer NWELL nwell
              calma 64 20
            layer CONT cont
              calma 66 44
            style drc
              templayer drawn_dnwell
                mask-hints dnwell
              templayer nwell_with_contact
                bloat-all cont nwell
              templayer covered_nwell drawn_dnwell
                or nwell_with_contact
              templayer nwell_missing_tap nwell
                and-not covered_nwell
            drc
              width nwell 840 "Nwell width"
              cifmaxwidth nwell_missing_tap 0 bend_illegal "Nwell tap marker"
            end
            """,
            sourcePath: "/tmp/sky130A.tech",
            generatedAt: "2026-06-25T00:00:00Z"
        )

        #expect(result.report.status == .complete)
        #expect(result.report.skippedFamilyCounts["cifmaxwidth"] == nil)
        #expect(result.report.sourceTempLayerOperationCounts["bloat-all"] == 1)
        #expect(result.report.sourceTempLayerOperationCounts["mask-hints"] == 1)
        #expect(result.report.sourceTempLayerMaterializedRuleIDs == ["magic.templayer.nwell_missing_tap"])
        #expect(result.report.sourceTempLayerMaterializedRuleCount == 1)
        #expect(result.technology.derivedLayerRules.contains { rule in
            rule.id == "magic.templayer.drawn_dnwell"
                && rule.targetLayer == LayoutLayerID(name: "drawn_dnwell", purpose: "derived")
                && rule.sourceLayers == [LayoutLayerID(name: "DNWELL", purpose: "drawing")]
                && rule.operation == .union
        })
        #expect(result.technology.derivedLayerRules.contains { rule in
            rule.id == "magic.templayer.nwell_with_contact"
                && rule.targetLayer == LayoutLayerID(name: "nwell_with_contact", purpose: "derived")
                && rule.sourceLayers == [
                    LayoutLayerID(name: "CONT", purpose: "cut"),
                    LayoutLayerID(name: "NWELL", purpose: "drawing"),
                ]
                && rule.operation == .bloatAll
                && rule.primarySourceLayerCount == 1
        })
        #expect(result.technology.derivedLayerRules.contains { rule in
            rule.id == "magic.templayer.nwell_missing_tap"
                && rule.targetLayer == LayoutLayerID(name: "nwell_missing_tap", purpose: "marker")
                && rule.operation == .difference
        })
        #expect(!result.report.diagnostics.contains {
            $0.code == "magic_drc_cifmaxwidth_marker_materialization_deferred"
        })
    }

    @Test func nonHoleCIFMaxWidthBoundaryMarkerMaterializesThroughCellBoundaryRule() throws {
        let result = try Self.importSky130Fixture(
            text: """
            style gdsii
            layer POLY poly
              calma 66 20
            style drc
              templayer abutment_box
                boundary
              templayer bbox_missing poly
                and-not abutment_box
            drc
              width poly 150 "Poly width"
              cifmaxwidth bbox_missing 0 bend_illegal "Device must be inside fixed bbox"
            end
            """,
            sourcePath: "/tmp/sky130A.tech",
            generatedAt: "2026-06-25T00:00:00Z"
        )

        #expect(result.report.status == .complete)
        #expect(result.report.skippedFamilyCounts["cifmaxwidth"] == nil)
        #expect(result.report.sourceTempLayerOperationCounts["boundary"] == 1)
        #expect(result.report.sourceTempLayerMaterializedRuleIDs == ["magic.templayer.bbox_missing"])
        #expect(result.report.sourceTempLayerMaterializedRuleCount == 1)
        #expect(result.technology.derivedLayerRules.contains { rule in
            rule.id == "magic.templayer.abutment_box"
                && rule.targetLayer == LayoutLayerID(name: "abutment_box", purpose: "derived")
                && rule.sourceLayers.isEmpty
                && rule.operation == .cellBoundary
        })
        #expect(result.technology.derivedLayerRules.contains { rule in
            rule.id == "magic.templayer.bbox_missing"
                && rule.targetLayer == LayoutLayerID(name: "bbox_missing", purpose: "marker")
                && rule.operation == .difference
        })
        #expect(!result.report.diagnostics.contains {
            $0.code == "magic_drc_cifmaxwidth_marker_materialization_deferred"
        })
    }

    @Test func importsSourceExactOverlapIntoLayoutTechRule() throws {
        let result = try Self.importSky130Fixture(
            text: """
            style gdsii
            layer MET1 allm1
              calma 68 20
            layer VIA1 via1
              calma 71 20
            types
              metal1 metal1,m1,met1
              metal1 via1,v1
            end
            drc
              width m1 140 "Metal1 width"
              width v1/m1 260 "Via1 wiring width"
              exact_overlap v1/m1
            end
            """,
            sourcePath: "/tmp/sky130A.tech",
            generatedAt: "2026-06-23T00:00:00Z"
        )

        #expect(result.report.status == .complete)
        #expect(result.report.importedRuleCount == 3)
        #expect(result.report.importedFamilyCounts["exact_overlap"] == 1)
        #expect(result.report.skippedFamilyCounts["exact_overlap"] == nil)
        #expect(result.report.sourceExactOverlapRuleIDs == ["exactOverlap.VIA1.MET1"])
        #expect(result.report.sourceExactOverlapRuleCount == 1)
        let rule = result.report.sourceExactOverlapRules.first
        #expect(rule?.id == "exactOverlap.VIA1.MET1")
        #expect(rule?.primaryLayerName == "VIA1")
        #expect(rule?.secondaryLayerName == "MET1")
        #expect(rule?.sourceLine == "exact_overlap v1/m1")
        let via1 = LayoutLayerID(name: "VIA1", purpose: "cut")
        let met1 = LayoutLayerID(name: "MET1", purpose: "drawing")
        let exactOverlapRule = result.technology.exactOverlapRule(for: "exactOverlap.VIA1.MET1")
        #expect(exactOverlapRule?.primaryLayer == via1)
        #expect(exactOverlapRule?.secondaryLayer == met1)
        #expect(!result.report.diagnostics.contains { $0.sourceLine == "exact_overlap v1/m1" })
    }

    @Test func importsParenthesizedAllContactExactOverlapAsOneOfActiveRule() throws {
        let result = try Self.importSky130Fixture(
            text: """
            style gdsii
            layer DIFF alldiff
              calma 65 20
            layer POLY allpoly
              calma 66 20
            layer CONT allcont
              calma 66 44
            types
              active ndiff,nsd
              active poly,pc
            end
            aliases
              allndiffcont ndc,nsc
              allpdiffcont pdc,psc
              alldiffcont allndiffcont,allpdiffcont
              allcont alldiffcont,pc
            end
            drc
              exact_overlap (allcont)/a
            end
            """,
            sourcePath: "/tmp/sky130A.tech",
            generatedAt: "2026-06-23T00:00:00Z"
        )

        let contact = LayoutLayerID(name: "CONT", purpose: "cut")
        let diff = LayoutLayerID(name: "DIFF", purpose: "drawing")
        let poly = LayoutLayerID(name: "POLY", purpose: "drawing")
        #expect(result.report.status == .complete)
        #expect(result.report.importedFamilyCounts["exact_overlap"] == 1)
        #expect(result.report.skippedFamilyCounts["exact_overlap"] == nil)
        #expect(result.report.sourceExactOverlapRuleIDs == ["exactOverlap.CONT.oneOf.DIFF.POLY"])
        #expect(result.report.sourceExactOverlapRules.first?.primaryLayerName == "CONT")
        #expect(result.report.sourceExactOverlapRules.first?.secondaryLayerName == "DIFF")
        #expect(result.report.sourceExactOverlapRules.first?.secondaryLayerNames == ["DIFF", "POLY"])
        let rule = result.technology.exactOverlapRule(for: "exactOverlap.CONT.oneOf.DIFF.POLY")
        #expect(rule?.primaryLayer == contact)
        #expect(rule?.secondaryLayers == [diff, poly])
    }

    @Test func importsAnglesAcrossMultipleResolvedCanonicalLayers() throws {
        let result = try Self.importSky130Fixture(
            text: """
            style gdsii
            layer MET1 allm1
              calma 68 20
            layer MET2 allm2
              calma 69 20
            types
              metal1 metal1,m1,met1
              metal2 metal2,m2,met2
            end
            drc
              angles met1,met2 45 "Only 45 and 90 degree angles permitted"
            end
            """,
            sourcePath: "/tmp/sky130A.tech",
            generatedAt: "2026-06-23T00:00:00Z"
        )

        #expect(result.report.status == .complete)
        #expect(result.report.importedFamilyCounts["angles"] == 2)
        #expect(result.report.skippedFamilyCounts["angles"] == nil)
        #expect(result.technology.ruleSet(for: LayoutLayerID(name: "MET1", purpose: "drawing"))?.allowedAngleStepDegrees == 45)
        #expect(result.technology.ruleSet(for: LayoutLayerID(name: "MET2", purpose: "drawing"))?.allowedAngleStepDegrees == 45)
    }

    @Test func importsAliasGraphAndCrossLayerSpacingRules() throws {
        let result = try Self.importSky130Fixture(
            text: """
            style gdsii
            layer DIFF diff
              calma 65 20
            layer POLY allpoly
              calma 66 20
            layer NWELL allnwell
              calma 64 20
            types
              active ndiff,nfet,psd
              active poly,p,polysilicon
              well nwell,obswell
            end
            aliases
              allnactive ndiff,nfet
              allactive allnactive,psd
              allnwell nwell,obswell
              allpoly poly,p
            end
            drc
              width allnactive 150 "Active width"
              spacing allnactive allnwell 340 touching_illegal "Active to nwell spacing"
              surround allnactive allnwell 180 absence_illegal "Well surround"
              overhang allpoly allnactive 130 "Gate overhang"
            end
            """,
            sourcePath: "/tmp/sky130A.tech",
            generatedAt: "2026-06-23T00:00:00Z"
        )

        let diff = LayoutLayerID(name: "DIFF", purpose: "drawing")
        let nwell = LayoutLayerID(name: "NWELL", purpose: "drawing")
        let poly = LayoutLayerID(name: "POLY", purpose: "drawing")

        #expect(result.report.status == .complete)
        #expect(result.report.importedFamilyCounts["width"] == 1)
        #expect(result.report.importedFamilyCounts["spacing"] == 1)
        #expect(result.report.importedFamilyCounts["surround"] == 1)
        #expect(result.report.importedFamilyCounts["overhang"] == 1)
        #expect(result.report.skippedRuleCount == 0)
        #expect(result.technology.ruleSet(for: diff)?.minWidth == 0.15)
        #expect(result.technology.ruleSet(for: diff)?.minSpacing == 0)
        #expect(result.technology.spacingRules.count == 1)
        let spacingRule = result.technology.spacingRules.first
        #expect(spacingRule?.primaryLayer == nwell)
        #expect(spacingRule?.secondaryLayer == diff)
        #expect(spacingRule?.minSpacing == 0.34)
        #expect(result.technology.enclosureRule(outer: nwell, inner: diff)?.minEnclosure == 0.18)
        #expect(result.technology.extensionRule(extending: poly, enclosed: diff, direction: .horizontal)?.minExtension == 0.13)
    }

    @Test func importsMIMAndPadLayerAliases() throws {
        let result = try Self.importSky130Fixture(
            text: """
            style gdsii
            layer MET3 m3
              calma 70 20
            layer VIA3 via3
              calma 70 44
            layer CAPM *mimcap
              calma 89 44
            layer MET4 m4
              calma 71 20
            layer VIA4 via4
              calma 71 44
            layer CAPM2 *mimcap2
              calma 97 44
            layer MET5 m5
              calma 72 20
            layer GLASS glass
              calma 76 20
            layer RDL metrdl
              calma 74 20
            types
              metal3 metal3,m3,met3
              metal3 via3,v3
              cap1 mimcap,mim,capm
              cap1 mimcapcontact,mimcapc,mimcc,capmc
              metal4 metal4,m4,met4
              metal4 via4,v4
              cap2 mimcap2,mim2,capm2
              cap2 mimcap2contact,mimcap2c,mim2cc,capm2c
              metal5 metal5,m5,met5
              metali metalrdl,mrdl,metrdl,rdl
             -block glass
            end
            drc
              width *mimcap 1000 "MiM cap width"
              spacing *mimcap *mimcap 840 touching_ok "MiM cap spacing"
              surround *mimcc *mimcap 80 absence_illegal "MiM cap contact enclosure"
              surround *mimcap *metal3/m3 140 absence_illegal "Metal3 MiM cap enclosure"
              rect_only *mimcap "MiM cap rectangular"
              width mimcc/c1 320 "MiM cap contact width"
              spacing mimcc mimcc 80 touching_ok "MiM cap contact spacing"
              surround mimcc/m4 *m4 5 directional "Metal4 MiM contact enclosure"
              exact_overlap mimcc/c1
              width *mimcap2 1000 "MiM2 cap width"
              spacing *mimcap2 *mimcap2 840 touching_ok "MiM2 cap spacing"
              surround *mim2cc *mimcap2 10 absence_illegal "MiM2 contact enclosure"
              rect_only *mimcap2 "MiM2 cap rectangular"
              width mim2cc/c2 1180 "MiM2 contact width"
              spacing mim2cc mim2cc 420 touching_ok "MiM2 contact spacing"
              surround mim2cc/m5 *m5 120 absence_illegal "Metal5 MiM2 contact enclosure"
              exact_overlap mim2cc/c2
              surround glass metrdl 10750 absence_ok "RDL pad enclosure"
              spacing glass metrdl 19660 surround_ok "RDL pad spacing"
            end
            """,
            sourcePath: "/tmp/sky130A.tech",
            generatedAt: "2026-06-23T00:00:00Z"
        )

        let capm = LayoutLayerID(name: "CAPM", purpose: "drawing")
        let mimcc = LayoutLayerID(name: "MIMCC", purpose: "cut")
        let met3 = LayoutLayerID(name: "MET3", purpose: "drawing")
        let met4 = LayoutLayerID(name: "MET4", purpose: "drawing")
        let capm2 = LayoutLayerID(name: "CAPM2", purpose: "drawing")
        let mim2cc = LayoutLayerID(name: "MIM2CC", purpose: "cut")
        let met5 = LayoutLayerID(name: "MET5", purpose: "drawing")
        let glass = LayoutLayerID(name: "GLASS", purpose: "drawing")
        let rdl = LayoutLayerID(name: "RDL", purpose: "drawing")

        #expect(result.report.status == .complete)
        #expect(result.report.importedFamilyCounts["width"] == 4)
        #expect(result.report.importedFamilyCounts["spacing"] == 5)
        #expect(result.report.importedFamilyCounts["surround"] == 6)
        #expect(result.report.importedFamilyCounts["rect_only"] == 2)
        #expect(result.report.importedFamilyCounts["exact_overlap"] == 2)
        #expect(result.report.skippedRuleCount == 0)
        #expect(result.technology.ruleSet(for: capm)?.minWidth == 1.0)
        #expect(result.technology.ruleSet(for: capm)?.minSpacing == 0.84)
        #expect(result.technology.ruleSet(for: capm)?.requiresRectangular == true)
        #expect(result.technology.ruleSet(for: mimcc)?.minWidth == 0.32)
        #expect(result.technology.ruleSet(for: mimcc)?.minSpacing == 0.08)
        #expect(result.technology.ruleSet(for: capm2)?.minWidth == 1.0)
        #expect(result.technology.ruleSet(for: mim2cc)?.minWidth == 1.18)
        #expect(result.technology.layerDefinition(for: mimcc) == nil)
        #expect(result.technology.layerDefinition(for: mim2cc) == nil)
        #expect(result.technology.derivedLayerRules.contains { rule in
            rule.id == "sky130.derived.MIMCC"
                && rule.targetLayer == mimcc
                && rule.sourceLayers == [LayoutLayerID(name: "VIA3", purpose: "cut"), capm]
        })
        #expect(result.technology.derivedLayerRules.contains { rule in
            rule.id == "sky130.derived.MIM2CC"
                && rule.targetLayer == mim2cc
                && rule.sourceLayers == [LayoutLayerID(name: "VIA4", purpose: "cut"), capm2]
        })
        #expect(result.technology.enclosureRule(outer: capm, inner: mimcc)?.minEnclosure == 0.08)
        #expect(result.technology.enclosureRule(outer: met3, inner: capm)?.minEnclosure == 0.14)
        #expect(result.technology.enclosureRule(outer: capm2, inner: mim2cc)?.minEnclosure == 0.01)
        #expect(result.technology.enclosureRule(outer: met5, inner: mim2cc)?.minEnclosure == 0.12)
        #expect(result.technology.enclosureRule(outer: rdl, inner: glass)?.minEnclosure == 10.75)
        #expect(result.technology.spacingRules.contains { rule in
            rule.primaryLayer == glass && rule.secondaryLayer == rdl && rule.minSpacing == 19.66
        })
        #expect(result.technology.exactOverlapRule(for: "exactOverlap.MIMCC.CAPM")?.primaryLayer == mimcc)
        #expect(result.technology.exactOverlapRule(for: "exactOverlap.MIM2CC.CAPM2")?.secondaryLayer == capm2)
        #expect(result.technology.contactDefinition(for: "MIMCC")?.bottomLayer == capm)
        #expect(result.technology.contactDefinition(for: "MIMCC")?.topLayer == met4)
        #expect(result.technology.contactDefinition(for: "MIM2CC")?.bottomLayer == capm2)
        #expect(result.technology.contactDefinition(for: "MIM2CC")?.topLayer == met5)
        #expect(result.report.derivedContactDefinitionIDs.contains("MIMCC"))
        #expect(result.report.derivedContactDefinitionIDs.contains("MIM2CC"))
        #expect(result.report.derivedMinimumCutRuleIDs.contains("mincut.MIMCC"))
        #expect(result.report.derivedMinimumCutRuleIDs.contains("mincut.MIM2CC"))
    }

    @Test func derivesViaDefinitionFromSourceWiringContactGeometry() throws {
        let result = try Self.importSky130Fixture(
            text: """
            style gdsii
            layer MET1 allm1
              calma 68 20
            layer VIA1 via1
              calma 71 20
            layer MET2 met2
              calma 69 20
            types
              metal1 metal1,m1,met1
              metal1 via1,v1
              metal2 metal2,m2,met2
            end
            drc
              width met1 140 "Metal1 width"
              width met2 140 "Metal2 width"
              width v1/m1 260 "Via1 wiring width"
              spacing v1 v1 60 touching_ok "Via1 spacing"
            end
            cut m2c via via1 VIA1 v1
            contact
              via1 metal1 metal2
            end
            wiring
              contact v1 260 m1 0 30 m2 0 40
            end
            """,
            sourcePath: "/tmp/sky130A.tech",
            generatedAt: "2026-06-23T00:00:00Z"
        )

        let via1 = LayoutLayerID(name: "VIA1", purpose: "cut")
        let met1 = LayoutLayerID(name: "MET1", purpose: "drawing")
        let met2 = LayoutLayerID(name: "MET2", purpose: "drawing")

        #expect(result.report.status == .complete)
        #expect(result.report.sourceContactStackIDs == ["VIA1"])
        #expect(result.report.sourceContactStackCount == 1)
        #expect(result.report.sourceContactStacks.first?.cutLayerName == "VIA1")
        #expect(result.report.sourceContactStacks.first?.bottomLayerName == "MET1")
        #expect(result.report.sourceContactStacks.first?.topLayerName == "MET2")
        #expect(result.report.sourceContactDefinitionIDs == ["VIA1"])
        #expect(result.report.sourceContactDefinitionCount == 1)
        #expect(result.report.derivedViaDefinitionIDs == ["VIA1"])
        #expect(result.report.derivedMinimumCutRuleIDs == ["mincut.VIA1"])
        let viaDefinition = result.technology.viaDefinition(for: "VIA1")
        #expect(viaDefinition?.cutLayer == via1)
        #expect(viaDefinition?.bottomLayer == met1)
        #expect(viaDefinition?.topLayer == met2)
        #expect(viaDefinition?.cutSize.width == 0.26)
        #expect(viaDefinition?.cutSize.height == 0.26)
        #expect(viaDefinition?.cutSpacing == 0.06)
        #expect(viaDefinition?.enclosure.bottom == 0.03)
        #expect(viaDefinition?.enclosure.top == 0.04)
    }

    @Test func derivesContactDefinitionsFromCutRulesAndConductorEnclosures() throws {
        let result = try Self.importSky130Fixture(
            text: """
            style gdsii
            layer CONT cont
              calma 67 44
            layer DIFF diff
              calma 65 20
            layer POLY poly
              calma 66 20
            layer LI li
              calma 67 20
            drc
              width cont 170 "Contact width"
              spacing cont cont 170 touching_illegal "Contact spacing"
              surround cont diff 60 absence_illegal "Diffusion contact enclosure"
              surround cont poly 70 absence_illegal "Poly contact enclosure"
              surround cont li 50 absence_illegal "LI contact enclosure"
            end
            """,
            sourcePath: "/tmp/sky130A.tech",
            generatedAt: "2026-06-23T00:00:00Z"
        )

        let cont = LayoutLayerID(name: "CONT", purpose: "cut")
        let diff = LayoutLayerID(name: "DIFF", purpose: "drawing")
        let poly = LayoutLayerID(name: "POLY", purpose: "drawing")
        let li = LayoutLayerID(name: "LI", purpose: "drawing")

        #expect(result.report.status == .complete)
        #expect(result.report.derivedViaDefinitionIDs.isEmpty)
        #expect(result.report.derivedContactDefinitionIDs == ["CONT_DIFF", "CONT_POLY"])
        #expect(result.report.derivedMinimumCutRuleIDs == ["mincut.CONT_DIFF", "mincut.CONT_POLY"])
        #expect(result.technology.ruleSet(for: cont)?.minWidth == 0.17)
        #expect(result.technology.ruleSet(for: cont)?.minSpacing == 0.17)

        let diffContact = result.technology.contactDefinition(for: "CONT_DIFF")
        #expect(diffContact?.cutLayer == cont)
        #expect(diffContact?.bottomLayer == diff)
        #expect(diffContact?.topLayer == li)
        #expect(diffContact?.cutSize.width == 0.17)
        #expect(diffContact?.cutSize.height == 0.17)
        #expect(diffContact?.cutSpacing == 0.17)
        #expect(diffContact?.enclosure.bottom == 0.06)
        #expect(diffContact?.enclosure.top == 0.05)
        let diffMinimumCutRule = result.technology.minimumCutRule(for: "mincut.CONT_DIFF")
        #expect(diffMinimumCutRule?.cutLayer == cont)
        #expect(diffMinimumCutRule?.bottomLayer == diff)
        #expect(diffMinimumCutRule?.topLayer == li)
        #expect(diffMinimumCutRule?.minimumCount == 1)

        let polyContact = result.technology.contactDefinition(for: "CONT_POLY")
        #expect(polyContact?.cutLayer == cont)
        #expect(polyContact?.bottomLayer == poly)
        #expect(polyContact?.topLayer == li)
        #expect(polyContact?.cutSize.width == 0.17)
        #expect(polyContact?.cutSize.height == 0.17)
        #expect(polyContact?.cutSpacing == 0.17)
        #expect(polyContact?.enclosure.bottom == 0.07)
        #expect(polyContact?.enclosure.top == 0.05)
        let polyMinimumCutRule = result.technology.minimumCutRule(for: "mincut.CONT_POLY")
        #expect(polyMinimumCutRule?.cutLayer == cont)
        #expect(polyMinimumCutRule?.bottomLayer == poly)
        #expect(polyMinimumCutRule?.topLayer == li)
        #expect(polyMinimumCutRule?.minimumCount == 1)
    }

    private static let fixtureMagicTech = """
    style gdsii
    layer MET1 allm1
      calma 68 20
    layer MET1FILL m1fill
      calma 36 28
    layer VIA1 via1
      calma 71 20
    layer MET2 met2
      calma 69 20
    layer DIFF diff,nfet
      calma 65 20
    layer POLY poly
      calma 66 20
    types
      metal1 metal1,m1,met1
      metal1 rmetal1,rm1,rmet1
     -metal1 obsm1
     -metal1 m1fill
      metal1 via1,v1
      metal2 metal2,m2,met2
    end
    templayer m1_small_hole allm1,obsm1,obsmcon
      close 140000
    templayer m1_hole_empty m1_small_hole
      and-not allm1,obsm1,obsmcon
    drc
      width *m1,rm1 140 "Metal1 width < %d (met1.1)"
      spacing allm1,m1fill allm1,*obsm1,m1fill 140 touching_ok "Metal1 spacing < %d (met1.2)"
      area allm1,*obsm1 83000 140 "Metal1 minimum area < %a (met1.6)"
      notch allm1 280 "Metal1 minimum notch"
      width v1/m1 150 "Via1 width"
      spacing v1 v1 170 touching_illegal "Via1 spacing"
      surround v1/m1 *met1 30 absence_illegal "Metal1 overlap"
      surround v1/m2 met2 40 absence_illegal "Metal2 overlap"
      widespacing allm1 3000 allm1 900 touching_ok "Metal1 wide spacing"
      overhang poly nfet 130 "Poly overhang"
      rect_only met1 "Metal1 rectangular only"
      angles met1 45 "Metal1 angle restriction"
      exact_overlap v1/m1
      cifmaxwidth m1_hole_empty 0 bend_illegal "Min area of metal1 holes > 0.14um^2 (met1.7)"
    end
    cut m2c via via1 VIA1 v1
    wiring
      contact v1 150 m1 0 30 m2 0 40
    end
    """
}
