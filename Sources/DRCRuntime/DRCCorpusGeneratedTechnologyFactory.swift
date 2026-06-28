import Foundation
import DRCCore
import LayoutCore
import LayoutTech

struct DRCCorpusGeneratedTechnologyFactory: Sendable {
    private func resolve(_ path: String, relativeTo base: URL) -> URL {
        if path.hasPrefix("/") {
            return URL(filePath: path)
        }
        return base.appending(path: path)
    }

    func technology(
        for fixture: DRCGeneratedLayoutFixture,
        specDirectory: URL
    ) throws -> LayoutTechDatabase {
        if let technologyPath = fixture.technologyPath {
            let technologyURL = resolve(technologyPath, relativeTo: specDirectory)
            do {
                let data = try Data(contentsOf: technologyURL)
                return try JSONDecoder().decode(LayoutTechDatabase.self, from: data)
            } catch {
                throw DRCError.invalidInput(
                    "Could not decode generated DRC technology profile at \(technologyURL.path(percentEncoded: false)): \(error.localizedDescription)"
                )
            }
        }
        return try generatedTechnology(named: fixture.technology)
    }

    private func generatedTechnology(named name: String) throws -> LayoutTechDatabase {
        switch name {
        case "sampleProcess":
            return LayoutTechDatabase.sampleProcess()
        case "sampleProcessMinimumCut":
            return sampleProcessMinimumCutTechnology()
        case "sky130MagicMetal1":
            return sky130MagicMetal1Technology()
        default:
            throw DRCError.invalidInput("Unsupported generated DRC technology fixture: \(name)")
        }
    }

    private func sampleProcessMinimumCutTechnology() -> LayoutTechDatabase {
        let m1 = LayoutLayerID(name: "M1", purpose: "drawing")
        let m2 = LayoutLayerID(name: "M2", purpose: "drawing")
        let via1 = LayoutLayerID(name: "VIA1", purpose: "cut")
        var technology = LayoutTechDatabase.sampleProcess()
        technology.minimumCutRules = [
            LayoutMinimumCutRule(
                id: "via1.minimumCut",
                cutLayer: via1,
                bottomLayer: m1,
                topLayer: m2,
                minimumCount: 2
            ),
        ]
        return technology
    }

    private func sky130MagicMetal1Technology() -> LayoutTechDatabase {
        let localInterconnect = LayoutLayerID(name: "LI", purpose: "drawing")
        let mcon = LayoutLayerID(name: "MCON", purpose: "cut")
        let metal1 = LayoutLayerID(name: "MET1", purpose: "drawing")
        let via1 = LayoutLayerID(name: "VIA1", purpose: "cut")
        let metal2 = LayoutLayerID(name: "MET2", purpose: "drawing")
        let via2 = LayoutLayerID(name: "VIA2", purpose: "cut")
        let metal3 = LayoutLayerID(name: "MET3", purpose: "drawing")
        return LayoutTechDatabase(
            units: .defaultUnits,
            grid: 0.005,
            layers: [
                LayoutLayerDefinition(
                    id: localInterconnect,
                    displayName: "Sky130 Local Interconnect",
                    gdsLayer: 67,
                    gdsDatatype: 20,
                    color: LayoutColor(red: 0.7, green: 0.45, blue: 0.25),
                    fillPattern: .solid,
                    preferredDirection: .horizontal
                ),
                LayoutLayerDefinition(
                    id: mcon,
                    displayName: "Sky130 Local Interconnect Contact",
                    gdsLayer: 67,
                    gdsDatatype: 44,
                    color: LayoutColor(red: 0.85, green: 0.85, blue: 0.2),
                    fillPattern: .crosshatch,
                    preferredDirection: .vertical
                ),
                LayoutLayerDefinition(
                    id: metal1,
                    displayName: "Sky130 Metal1",
                    gdsLayer: 68,
                    gdsDatatype: 20,
                    color: LayoutColor(red: 0.3, green: 0.5, blue: 0.9),
                    fillPattern: .forwardDiagonal,
                    preferredDirection: .horizontal
                ),
                LayoutLayerDefinition(
                    id: via1,
                    displayName: "Sky130 Via1",
                    gdsLayer: 68,
                    gdsDatatype: 44,
                    color: LayoutColor(red: 0.75, green: 0.75, blue: 0.2),
                    fillPattern: .crosshatch,
                    preferredDirection: .vertical
                ),
                LayoutLayerDefinition(
                    id: metal2,
                    displayName: "Sky130 Metal2",
                    gdsLayer: 69,
                    gdsDatatype: 20,
                    color: LayoutColor(red: 0.2, green: 0.65, blue: 0.75),
                    fillPattern: .backwardDiagonal,
                    preferredDirection: .vertical
                ),
                LayoutLayerDefinition(
                    id: via2,
                    displayName: "Sky130 Via2",
                    gdsLayer: 69,
                    gdsDatatype: 44,
                    color: LayoutColor(red: 0.80, green: 0.70, blue: 0.20),
                    fillPattern: .crosshatch,
                    preferredDirection: .vertical
                ),
                LayoutLayerDefinition(
                    id: metal3,
                    displayName: "Sky130 Metal3",
                    gdsLayer: 70,
                    gdsDatatype: 20,
                    color: LayoutColor(red: 0.55, green: 0.35, blue: 0.80),
                    fillPattern: .forwardDiagonal,
                    preferredDirection: .horizontal
                ),
            ],
            vias: [],
            layerRules: [
                LayoutLayerRuleSet(
                    layerID: localInterconnect,
                    minWidth: 0.17,
                    minSpacing: 0.17,
                    minArea: 0.0561,
                    minDensity: 0.0,
                    maxDensity: 1.0
                ),
                LayoutLayerRuleSet(
                    layerID: metal1,
                    minWidth: 0.14,
                    minSpacing: 0.14,
                    minArea: 0.0,
                    minDensity: 0.0,
                    maxDensity: 1.0,
                    wideWidthThreshold: 3.005,
                    wideSpacing: 0.28,
                    minEnclosedArea: 0.14,
                    allowedAngleStepDegrees: 45
                ),
                LayoutLayerRuleSet(
                    layerID: metal2,
                    minWidth: 0.14,
                    minSpacing: 0.14,
                    minArea: 0.0,
                    minDensity: 0.0,
                    maxDensity: 1.0,
                    wideWidthThreshold: 3.005,
                    wideSpacing: 0.28,
                    minEnclosedArea: 0.14,
                    allowedAngleStepDegrees: 45
                ),
                LayoutLayerRuleSet(
                    layerID: metal3,
                    minWidth: 0.30,
                    minSpacing: 0.30,
                    minArea: 0.24,
                    minDensity: 0.0,
                    maxDensity: 1.0,
                    wideWidthThreshold: 3.005,
                    wideSpacing: 0.40,
                    minEnclosedArea: 0.14,
                    allowedAngleStepDegrees: 45
                ),
            ]
        )
    }

}
