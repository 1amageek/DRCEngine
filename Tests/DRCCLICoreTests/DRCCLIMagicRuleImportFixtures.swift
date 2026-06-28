import Foundation
import Testing
import DRCCore
import DRCCLICore
import DRCNative
import LayoutCore
import LayoutTech


extension DRCCLIOptionsTests {
    func writeMagicRuleImportCatalog(
        root: URL,
        catalogPath: String = "tech/magic-rule-import-catalog.json",
        includeProfileResource: Bool = true
    ) throws -> URL {
        let catalogURL = root.appending(path: catalogPath)
        try FileManager.default.createDirectory(
            at: catalogURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let metadata = includeProfileResource
            ? ["magicLayoutTechProfileResource": "sky130-magic-layouttech-profile"]
            : nil
        let catalog = DRCMagicRuleImportCatalog(
            entries: [
                DRCMagicRuleImportCatalog.Entry(
                    technologyCatalogID: "sky130-open-pdk",
                    pdkID: "sky130A",
                    profileIDs: ["sky130.magic.layouttech"],
                    requiredFiles: [
                        DRCMagicRuleImportCatalog.RequiredFile(
                            purpose: "magic-drc-tech",
                            path: "sky130A/libs.tech/magic/sky130A.tech"
                        ),
                    ],
                    metadata: metadata
                ),
            ]
        )
        try writeJSON(catalog, to: catalogURL)
        return catalogURL
    }

    func writeMagicDRCDeck(root: URL) throws {
        try writeText(
            """
            scalegrid 1 2
            tech load $PDK_ROOT/sky130A/libs.tech/magic/sky130A.tech
            snap lambda
            """,
            to: root.appending(path: "sky130A/libs.tech/magic/sky130A.magicrc")
        )
        try writeText(
            """
            templayer m1_small_hole met1
              close 140000
            templayer m1_hole_empty m1_small_hole
              and-not met1
            drc
              width met1 140 "Metal1 width"
              spacing met1 met1 140 touching_ok "Metal1 spacing"
              surround via1 met1 30 directional "Metal1 surround"
              overhang poly nfet 130 "Gate overhang"
              area met1 83000 140 "Metal1 area"
              notch met1 280 "Metal1 notch"
              widespacing met1 3000 met1 900 touching_ok "Metal1 wide spacing"
              rect_only met1 "Metal1 rectangular only"
              exact_overlap v1/m1
              cifmaxwidth m1_hole_empty 0 83000 "Metal1 enclosed hole"
            end
            cut m2c via via1 VIA1 v1
            wiring
              contact v1 150 m1 0 30 m2 0 40
            end
            """,
            to: root.appending(path: "sky130A/libs.tech/magic/sky130A.tech")
        )
    }

    func writeImportableMagicDRCDeck(
        root: URL,
        includeUnsupportedRule: Bool = false
    ) throws {
        let unsupportedLayerDefinitions = includeUnsupportedRule
            ? """
            layer DNWELL dnwell
              calma 64 18
            layer NWELL nwell
              calma 64 20

            """
            : ""
        let unsupportedTempLayerDefinition = includeUnsupportedRule
            ? """
            templayer nwell_missing nwell
              bridge 400
              and-not dnwell

            """
            : ""
        let unsupportedRule = includeUnsupportedRule
            ? "  cifmaxwidth nwell_missing 0 bend_illegal \"Unresolved non-hole marker\"\n"
            : ""
        try writeText(
            """
            scalegrid 1 2
            tech load $PDK_ROOT/sky130A/libs.tech/magic/sky130A.tech
            snap lambda
            """,
            to: root.appending(path: "sky130A/libs.tech/magic/sky130A.magicrc")
        )
        try writeText(
            """
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
            \(unsupportedLayerDefinitions)\
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
            \(unsupportedTempLayerDefinition)\
            drc
              width *m1,rm1 140 "Metal1 width < %d (met1.1)"
              spacing allm1,m1fill allm1,*obsm1,m1fill 140 touching_ok "Metal1 spacing < %d (met1.2)"
              area allm1,*obsm1 83000 140 "Metal1 minimum area < %a (met1.6)"
              notch allm1 280 "Metal1 minimum notch"
              width v1/m1 150 "Via1 width"
              spacing v1 v1 170 touching_illegal "Via1 spacing"
              spacing poly nfet 90 touching_illegal "Poly to diffusion spacing"
              surround v1/m1 *met1 30 absence_illegal "Metal1 overlap"
              surround v1/m2 met2 40 absence_illegal "Metal2 overlap"
              widespacing allm1 3000 allm1 900 touching_ok "Metal1 wide spacing"
              overhang poly nfet 130 "Poly overhang"
              rect_only met1 "Metal1 rectangular only"
              angles met1 45 "Metal1 angle restriction"
              exact_overlap v1/m1
              cifmaxwidth m1_hole_empty 0 bend_illegal "Min area of metal1 holes > 0.14um^2 (met1.7)"
              minimumcut v1 met1 met2 2 "Via1 requires two cuts"
            \(unsupportedRule)\
            end
            cut m2c via via1 VIA1 v1
            wiring
              contact v1 150 met1 0 30 met2 0 40
            end
            """,
            to: root.appending(path: "sky130A/libs.tech/magic/sky130A.tech")
        )
    }
}
