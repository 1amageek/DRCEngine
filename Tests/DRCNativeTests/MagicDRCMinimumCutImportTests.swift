import Foundation
import LayoutCore
import LayoutTech
import Testing
@testable import DRCNative

@Suite("Magic DRC minimum cut import tests")
struct MagicDRCMinimumCutImportTests {
    @Test func deckParsedMinimumCutPolicyOverridesProfileDefault() throws {
        let profile = MagicDRCLayoutTechImportProfile(
            profileID: "test.magic.deck-minimum-cut",
            layerOrder: ["METX", "CUTX", "METY"],
            cutLayerNames: ["CUTX"],
            layerPurposes: ["CUTX": "cut"],
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
              minimumcut cutx metx mety 3 "Cut X needs three cuts"
            end
            """,
            sourcePath: "/tmp/generic-deck-minimum-cut.magic.tech",
            profile: profile,
            generatedAt: "2026-06-25T00:00:00Z"
        )

        #expect(result.report.status == .complete)
        #expect(result.report.profileMinimumCutPolicyCount == 0)
        #expect(result.report.sourceMinimumCutPolicyIDs == ["sourceMinimumCut.CUTX"])
        #expect(result.report.sourceMinimumCutPolicyCount == 1)
        #expect(result.report.sourceMinimumCutPolicies.first?.minimumCount == 3)
        #expect(result.report.sourceMinimumCutPolicies.first?.sourceLineNumber == 15)
        #expect(result.report.importedFamilyCounts["minimum_cut"] == 1)
        #expect(result.report.derivedMinimumCutRuleIDs == ["mincut.CUTX"])
        #expect(result.technology.minimumCutRule(for: "mincut.CUTX")?.minimumCount == 3)
    }

    @Test func alternateMinimumCutSyntaxInfersUniqueProfileStack() throws {
        let profile = MagicDRCLayoutTechImportProfile(
            profileID: "test.magic.deck-minimum-cut-alternate",
            layerOrder: ["METX", "CUTX", "METY"],
            cutLayerNames: ["CUTX"],
            layerPurposes: ["CUTX": "cut"],
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
              cutcount cutx 4 "Cut X needs four cuts"
            end
            """,
            sourcePath: "/tmp/generic-deck-minimum-cut-alternate.magic.tech",
            profile: profile,
            generatedAt: "2026-06-29T00:00:00Z"
        )

        #expect(result.report.status == .complete)
        #expect(result.report.sourceMinimumCutPolicyIDs == ["sourceMinimumCut.CUTX"])
        #expect(result.report.sourceMinimumCutPolicies.first?.bottomLayerName == "METX")
        #expect(result.report.sourceMinimumCutPolicies.first?.topLayerName == "METY")
        #expect(result.report.sourceMinimumCutPolicies.first?.minimumCount == 4)
        #expect(result.report.importedFamilyCounts["minimum_cut"] == 1)
        #expect(result.report.skippedFamilyCounts["minimum_cut"] == nil)
        #expect(result.technology.minimumCutRule(for: "mincut.CUTX")?.minimumCount == 4)
    }

    @Test func alternateMinimumCutSyntaxKeepsAmbiguousStacksAsDiagnostics() throws {
        let profile = MagicDRCLayoutTechImportProfile(
            profileID: "test.magic.deck-minimum-cut-ambiguous",
            layerOrder: ["METX", "CUTX", "METY", "METZ"],
            cutLayerNames: ["CUTX"],
            layerPurposes: ["CUTX": "cut"],
            baseLayerNames: ["METX", "CUTX", "METY", "METZ"],
            cutStackConnections: [
                MagicDRCLayoutTechCutStackConnection(
                    id: "CUTX_A",
                    cutLayerName: "CUTX",
                    bottomLayerName: "METX",
                    topLayerName: "METY",
                    kind: "via"
                ),
                MagicDRCLayoutTechCutStackConnection(
                    id: "CUTX_B",
                    cutLayerName: "CUTX",
                    bottomLayerName: "METY",
                    topLayerName: "METZ",
                    kind: "via"
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
            layer METZ metz
              calma 13 0
            cut cutx via CUTX
            drc
              width metx 100 "Metal X width"
              width cutx 50 "Cut X width"
              width mety 100 "Metal Y width"
              width metz 100 "Metal Z width"
              spacing cutx cutx 60 touching_illegal "Cut X spacing"
              surround cutx metx 20 absence_illegal "Bottom overlap"
              surround cutx mety 30 absence_illegal "Middle overlap"
              surround cutx metz 40 absence_illegal "Top overlap"
              cutcount cutx 4 "Ambiguous Cut X stack"
            end
            """,
            sourcePath: "/tmp/generic-deck-minimum-cut-ambiguous.magic.tech",
            profile: profile,
            generatedAt: "2026-06-29T00:00:00Z"
        )

        #expect(result.report.status == .partial)
        #expect(result.report.sourceMinimumCutPolicyCount == 0)
        #expect(result.report.importedFamilyCounts["minimum_cut"] == nil)
        #expect(result.report.skippedFamilyCounts["minimum_cut"] == 1)
        #expect(result.report.diagnostics.contains {
            $0.code == "magic_drc_minimum_cut_stack_ambiguous"
                && $0.sourceLine?.contains("cutcount cutx 4") == true
        })
    }

    @Test func multiStackMinimumCutSyntaxImportsMultipleSourcePolicies() throws {
        let profile = MagicDRCLayoutTechImportProfile(
            profileID: "test.magic.deck-minimum-cut-multi-stack",
            layerOrder: ["METX", "CUTX", "METY", "METZ"],
            cutLayerNames: ["CUTX"],
            layerPurposes: ["CUTX": "cut"],
            baseLayerNames: ["METX", "CUTX", "METY", "METZ"],
            cutStackConnections: [
                MagicDRCLayoutTechCutStackConnection(
                    id: "CUTX_METXY",
                    cutLayerName: "CUTX",
                    bottomLayerName: "METX",
                    topLayerName: "METY",
                    kind: "via"
                ),
                MagicDRCLayoutTechCutStackConnection(
                    id: "CUTX_METYZ",
                    cutLayerName: "CUTX",
                    bottomLayerName: "METY",
                    topLayerName: "METZ",
                    kind: "via"
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
            layer METZ metz
              calma 13 0
            cut cutx via CUTX
            drc
              width metx 100 "Metal X width"
              width cutx 50 "Cut X width"
              width mety 100 "Metal Y width"
              width metz 100 "Metal Z width"
              spacing cutx cutx 60 touching_illegal "Cut X spacing"
              surround cutx metx 20 absence_illegal "Bottom overlap"
              surround cutx mety 30 absence_illegal "Middle overlap"
              surround cutx metz 40 absence_illegal "Top overlap"
              cutcount cutx metx mety 2 mety metz 3 "Cut X stack counts"
            end
            """,
            sourcePath: "/tmp/generic-deck-minimum-cut-multi-stack.magic.tech",
            profile: profile,
            generatedAt: "2026-06-29T00:00:00Z"
        )

        #expect(result.report.status == .complete)
        #expect(result.report.sourceMinimumCutPolicyIDs == [
            "sourceMinimumCut.CUTX_METXY",
            "sourceMinimumCut.CUTX_METYZ",
        ])
        #expect(result.report.sourceMinimumCutPolicyCount == 2)
        #expect(result.report.importedFamilyCounts["minimum_cut"] == 2)
        #expect(result.report.skippedFamilyCounts["minimum_cut"] == nil)
        #expect(result.report.derivedMinimumCutRuleIDs == [
            "mincut.CUTX_METXY",
            "mincut.CUTX_METYZ",
        ])
        #expect(result.technology.minimumCutRule(for: "mincut.CUTX_METXY")?.minimumCount == 2)
        #expect(result.technology.minimumCutRule(for: "mincut.CUTX_METYZ")?.minimumCount == 3)
    }

    @Test func minimumCutCountCanPrecedeExplicitConductorStack() throws {
        let profile = MagicDRCLayoutTechImportProfile(
            profileID: "test.magic.deck-minimum-cut-prefix-count",
            layerOrder: ["METX", "CUTX", "METY"],
            cutLayerNames: ["CUTX"],
            layerPurposes: ["CUTX": "cut"],
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
              minimumcut cutx 2 metx mety "Cut X needs two cuts"
            end
            """,
            sourcePath: "/tmp/generic-deck-minimum-cut-prefix-count.magic.tech",
            profile: profile,
            generatedAt: "2026-06-29T00:00:00Z"
        )

        #expect(result.report.status == .complete)
        #expect(result.report.sourceMinimumCutPolicyIDs == ["sourceMinimumCut.CUTX"])
        #expect(result.report.importedFamilyCounts["minimum_cut"] == 1)
        #expect(result.technology.minimumCutRule(for: "mincut.CUTX")?.minimumCount == 2)
    }

    @Test func minimumCutExtraCountsRemainDiagnostics() throws {
        let profile = MagicDRCLayoutTechImportProfile(
            profileID: "test.magic.deck-minimum-cut-extra-counts",
            layerOrder: ["METX", "CUTX", "METY"],
            cutLayerNames: ["CUTX"],
            layerPurposes: ["CUTX": "cut"],
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
              cutcount cutx metx mety 2 4 "Ambiguous extra count"
            end
            """,
            sourcePath: "/tmp/generic-deck-minimum-cut-extra-counts.magic.tech",
            profile: profile,
            generatedAt: "2026-06-29T00:00:00Z"
        )

        #expect(result.report.status == .partial)
        #expect(result.report.sourceMinimumCutPolicyCount == 0)
        #expect(result.report.importedFamilyCounts["minimum_cut"] == nil)
        #expect(result.report.skippedFamilyCounts["minimum_cut"] == 1)
        #expect(result.report.diagnostics.contains {
            $0.code == "magic_drc_minimum_cut_count_ambiguous"
                && $0.sourceLine?.contains("cutcount cutx metx mety 2 4") == true
        })
    }

    @Test func sourceContactSectionSuppliesCutStackWithoutProfileConnection() {
        let profile = MagicDRCLayoutTechImportProfile(
            profileID: "test.magic.contact-stack",
            layerOrder: ["METX", "CUTX", "METY"],
            cutLayerNames: ["CUTX"],
            layerPurposes: ["CUTX": "cut"],
            baseLayerNames: ["METX", "CUTX", "METY"]
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
            contact
              CUTX METX METY
            end
            drc
              width metx 100 "Metal X width"
              width cutx 50 "Cut X width"
              spacing cutx cutx 60 touching_illegal "Cut X spacing"
              surround cutx metx 20 absence_illegal "Bottom overlap"
              surround cutx mety 30 absence_illegal "Top overlap"
            end
            wiring
              contact CUTX 50 METX 20 METY 30
            end
            """,
            sourcePath: "/tmp/generic-contact-stack.magic.tech",
            profile: profile,
            generatedAt: "2026-06-24T00:00:00Z"
        )

        let metX = LayoutLayerID(name: "METX", purpose: "drawing")
        let cutX = LayoutLayerID(name: "CUTX", purpose: "cut")
        let metY = LayoutLayerID(name: "METY", purpose: "drawing")
        #expect(result.report.status == .complete)
        #expect(result.report.sourceContactStackIDs == ["CUTX"])
        #expect(result.report.sourceContactStackCount == 1)
        #expect(result.report.sourceContactStacks.first?.cutLayerName == "CUTX")
        #expect(result.report.sourceContactStacks.first?.bottomLayerName == "METX")
        #expect(result.report.sourceContactStacks.first?.topLayerName == "METY")
        #expect(result.report.sourceContactDefinitionIDs == ["CUTX"])
        #expect(result.report.derivedViaDefinitionIDs == ["CUTX"])
        #expect(result.report.derivedMinimumCutRuleIDs == ["mincut.CUTX"])

        let via = result.technology.viaDefinition(for: "CUTX")
        #expect(via?.cutLayer == cutX)
        #expect(via?.bottomLayer == metX)
        #expect(via?.topLayer == metY)
        #expect(via?.cutSize.width == 0.05)
        #expect(via?.cutSpacing == 0.06)
        #expect(via?.enclosure.bottom == 0.02)
        #expect(via?.enclosure.top == 0.03)
    }

    @Test func sourceContactStackIDRequiresExactTopLayerWhenProfileHasDecoyConnection() {
        let profile = MagicDRCLayoutTechImportProfile(
            profileID: "test.magic.contact-stack-decoy",
            layerOrder: ["METX", "CUTX", "METY", "METZ"],
            cutLayerNames: ["CUTX"],
            layerPurposes: ["CUTX": "cut"],
            baseLayerNames: ["METX", "CUTX", "METY", "METZ"],
            cutStackConnections: [
                MagicDRCLayoutTechCutStackConnection(
                    id: "CUTX_DECOY",
                    cutLayerName: "CUTX",
                    bottomLayerName: "METX",
                    topLayerName: "METZ",
                    kind: "via"
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
            contact
              CUTX METX METY
            end
            drc
              width metx 100 "Metal X width"
              width cutx 50 "Cut X width"
              spacing cutx cutx 60 touching_illegal "Cut X spacing"
              surround cutx metx 20 absence_illegal "Bottom overlap"
              surround cutx mety 30 absence_illegal "Top overlap"
            end
            wiring
              contact CUTX 50 METX 20 METY 30
            end
            """,
            sourcePath: "/tmp/generic-contact-stack-decoy.magic.tech",
            profile: profile,
            generatedAt: "2026-06-24T00:00:00Z"
        )

        let metY = LayoutLayerID(name: "METY", purpose: "drawing")
        #expect(result.report.sourceContactStackIDs == ["CUTX"])
        #expect(result.report.sourceContactDefinitionIDs == ["CUTX"])
        #expect(result.report.derivedViaDefinitionIDs == ["CUTX"])
        #expect(result.technology.viaDefinition(for: "CUTX")?.topLayer == metY)
        #expect(result.technology.viaDefinition(for: "CUTX_DECOY") == nil)
    }
}
