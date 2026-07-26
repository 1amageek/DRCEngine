import Foundation
import LayoutCore
import LayoutTech
import Testing
@testable import DRCNative

@Suite("Magic DRC variant and CIF import tests")
struct MagicDRCVariantAndCIFImportTests {
    @Test func selectedVariantMaterializesCIFRulesAndOptionalExtension() throws {
        let profile = MagicDRCLayoutTechImportProfile(
            profileID: "test.magic.variant-cif",
            selectedDRCVariant: "full",
            layerOrder: ["ACTIVE", "POLY"],
            baseLayerNames: ["ACTIVE", "POLY"]
        )
        let result = MagicDRCLayoutTechImporter.importTechnology(
            text: """
            style gdsii
            layer ACTIVE active
              calma 10 0
            layer POLY poly
              calma 11 0
            templayer active_wide active
              grow 10
            templayer poly_halo poly
              grow 20
            drc
              style drc variants (fast),(full),(routing)
              scalefactor 10
              cifstyle drc
              variants (routing)
              width active 900 "Routing-only width"
              variants (full)
              cifwidth active_wide 200 "Derived active width"
              cifspacing active_wide poly_halo 300 touching_illegal "Derived spacing"
              extend poly active 100 "Poly extension when present"
              overhang poly active 80 "Required poly overhang"
              variants *
              width poly 50 "Shared poly width"
            end
            """,
            sourcePath: "/tmp/generic-variant-cif.magic.tech",
            profile: profile,
            generatedAt: "2026-07-26T00:00:00Z"
        )

        let active = LayoutLayerID(name: "ACTIVE", purpose: "drawing")
        let poly = LayoutLayerID(name: "POLY", purpose: "drawing")
        let activeWide = LayoutLayerID(name: "active_wide", purpose: "drawing")
        let polyHalo = LayoutLayerID(name: "poly_halo", purpose: "drawing")

        #expect(result.report.status == .complete)
        #expect(result.report.skippedRuleCount == 0)
        #expect(result.report.diagnostics.isEmpty)
        #expect(result.report.importedFamilyCounts["width"] == 1)
        #expect(result.report.importedFamilyCounts["cifwidth"] == 1)
        #expect(result.report.importedFamilyCounts["cifspacing"] == 1)
        #expect(result.report.importedFamilyCounts["extend"] == 1)
        #expect(result.report.importedFamilyCounts["overhang"] == 1)
        #expect(result.technology.ruleSet(for: active)?.minWidth == 0)
        #expect(result.technology.ruleSet(for: poly)?.minWidth == 0.05)
        #expect(result.technology.ruleSet(for: activeWide)?.minWidth == 0.2)
        #expect(result.technology.ruleSet(for: polyHalo) != nil)
        #expect(result.technology.spacingRules.contains {
            $0.primaryLayer == activeWide
                && $0.secondaryLayer == polyHalo
                && $0.minSpacing == 0.3
        })
        #expect(result.technology.derivedLayerRules.contains {
            $0.targetLayer == activeWide
                && $0.sourceLayers == [active]
                && $0.operation == .grow
                && $0.operationDistance == 0.01
        })
        #expect(result.technology.derivedLayerRules.contains {
            $0.targetLayer == polyHalo
                && $0.sourceLayers == [poly]
                && $0.operation == .grow
                && $0.operationDistance == 0.02
        })
        #expect(result.technology.extensionRules.map {
            "\($0.direction.rawValue):\($0.coveragePolicy.rawValue):\($0.minExtension)"
        } == [
            "horizontal:required:0.08",
            "horizontal:when-present:0.1",
            "vertical:required:0.08",
            "vertical:when-present:0.1",
        ])
        #expect(result.report.sourceTempLayerMaterializedRuleIDs == [
            "magic.templayer.active_wide",
            "magic.templayer.poly_halo",
        ])
    }
}
