import DRCCore
import LayoutCore

struct DRCCorpusGeneratedLayoutFactory: Sendable {
    func document(for fixture: DRCGeneratedLayoutFixture) throws -> LayoutDocument {
        switch fixture.kind {
        case "sampleProcessM1Clean":
            var cell = LayoutCell(name: "STD_DRC")
            cell.shapes = [
                LayoutShape(
                    layer: LayoutLayerID(name: "M1", purpose: "drawing"),
                    geometry: .rect(LayoutRect(
                        origin: LayoutPoint(x: 0, y: 0),
                        size: LayoutSize(width: 2.0, height: 0.3)
                    ))
                ),
            ]
            return LayoutDocument(name: "STD_DRC", cells: [cell], topCellID: cell.id)
        case "sampleProcessMinimumCutViolation":
            return generatedMinimumCutDocument(cutCount: 1)
        case "sampleProcessMinimumCutClean":
            return generatedMinimumCutDocument(cutCount: 2)
        case "sky130MagicMetal1WidthViolation":
            return generatedSky130MagicMetal1Document(cellName: "SKY130_MET1_WIDTH_VIOLATION", metalWidth: 0.08)
        case "sky130MagicMetal1WidthClean":
            return generatedSky130MagicMetal1Document(cellName: "SKY130_MET1_WIDTH_CLEAN", metalWidth: 0.20)
        case "sky130MagicMetal1SpacingViolation":
            return generatedSky130MagicMetal1SpacingDocument(
                cellName: "SKY130_MET1_SPACING_VIOLATION",
                metalSpacing: 0.08
            )
        case "sky130MagicMetal1SpacingClean":
            return generatedSky130MagicMetal1SpacingDocument(
                cellName: "SKY130_MET1_SPACING_CLEAN",
                metalSpacing: 0.20
            )
        case "sky130MagicMetal1AreaViolation":
            return generatedSky130MagicMetal1AreaDocument(
                cellName: "SKY130_MET1_AREA_VIOLATION",
                metalSize: LayoutSize(width: 0.20, height: 0.20)
            )
        case "sky130MagicMetal1AreaClean":
            return generatedSky130MagicMetal1AreaDocument(
                cellName: "SKY130_MET1_AREA_CLEAN",
                metalSize: LayoutSize(width: 0.40, height: 0.40)
            )
        case "sky130MagicMetal1AngleViolation":
            return generatedSky130MagicMetal1AngleDocument(
                cellName: "SKY130_MET1_ANGLE_VIOLATION",
                points: [
                    LayoutPoint(x: 0.00, y: 0.00),
                    LayoutPoint(x: 2.00, y: 0.00),
                    LayoutPoint(x: 2.00, y: 1.00),
                    LayoutPoint(x: 1.20, y: 1.40),
                    LayoutPoint(x: 0.00, y: 1.00),
                ]
            )
        case "sky130MagicMetal1AngleClean":
            return generatedSky130MagicMetal1AngleDocument(
                cellName: "SKY130_MET1_ANGLE_CLEAN",
                points: [
                    LayoutPoint(x: 0.00, y: 0.00),
                    LayoutPoint(x: 2.00, y: 0.00),
                    LayoutPoint(x: 2.00, y: 1.00),
                    LayoutPoint(x: 1.00, y: 2.00),
                    LayoutPoint(x: 0.00, y: 1.00),
                ]
            )
        case "sky130MagicMetal1WideSpacingViolation":
            return generatedSky130MagicMetal1WideSpacingDocument(
                cellName: "SKY130_MET1_WIDE_SPACING_VIOLATION",
                spacing: 0.20
            )
        case "sky130MagicMetal1WideSpacingClean":
            return generatedSky130MagicMetal1WideSpacingDocument(
                cellName: "SKY130_MET1_WIDE_SPACING_CLEAN",
                spacing: 0.32
            )
        case "sky130MagicMetal1LargeAttachedSpacingViolation":
            return generatedSky130MagicMetal1LargeAttachedSpacingDocument(
                cellName: "SKY130_MET1_LARGE_ATTACHED_SPACING_VIOLATION",
                fingerSpacing: 0.20
            )
        case "sky130MagicMetal1LargeAttachedSpacingClean":
            return generatedSky130MagicMetal1LargeAttachedSpacingDocument(
                cellName: "SKY130_MET1_LARGE_ATTACHED_SPACING_CLEAN",
                fingerSpacing: 0.32
            )
        case "sky130MagicMetal1MCONEnclosureViolation":
            return generatedSky130MagicMetal1MCONEnclosureDocument(
                cellName: "SKY130_MET1_MCON_ENCLOSURE_VIOLATION",
                metal1Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.30, y: 0.30),
                    size: LayoutSize(width: 0.55, height: 0.20)
                )
            )
        case "sky130MagicMetal1MCONEnclosureClean":
            return generatedSky130MagicMetal1MCONEnclosureDocument(
                cellName: "SKY130_MET1_MCON_ENCLOSURE_CLEAN",
                metal1Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.23, y: 0.23),
                    size: LayoutSize(width: 0.45, height: 0.45)
                )
            )
        case "sky130MagicMCONWidthViolation":
            return generatedSky130MagicMCONWidthDocument(
                cellName: "SKY130_MCON_WIDTH_VIOLATION",
                contactSize: LayoutSize(width: 0.10, height: 0.17)
            )
        case "sky130MagicMCONWidthClean":
            return generatedSky130MagicMCONWidthDocument(
                cellName: "SKY130_MCON_WIDTH_CLEAN",
                contactSize: LayoutSize(width: 0.17, height: 0.17)
            )
        case "sky130MagicMCONSpacingViolation":
            return generatedSky130MagicMCONSpacingDocument(
                cellName: "SKY130_MCON_SPACING_VIOLATION",
                contactSpacing: 0.10
            )
        case "sky130MagicMCONSpacingClean":
            return generatedSky130MagicMCONSpacingDocument(
                cellName: "SKY130_MCON_SPACING_CLEAN",
                contactSpacing: 0.25
            )
        case "sky130MagicVIA1WidthViolation":
            return generatedSky130MagicVIA1WidthDocument(
                cellName: "SKY130_VIA1_WIDTH_VIOLATION",
                cutSize: LayoutSize(width: 0.10, height: 0.26)
            )
        case "sky130MagicVIA1WidthClean":
            return generatedSky130MagicVIA1WidthDocument(
                cellName: "SKY130_VIA1_WIDTH_CLEAN",
                cutSize: LayoutSize(width: 0.26, height: 0.26)
            )
        case "sky130MagicVIA1SpacingViolation":
            return generatedSky130MagicVIA1SpacingDocument(
                cellName: "SKY130_VIA1_SPACING_VIOLATION",
                cutSpacing: 0.13
            )
        case "sky130MagicVIA1SpacingClean":
            return generatedSky130MagicVIA1SpacingDocument(
                cellName: "SKY130_VIA1_SPACING_CLEAN",
                cutSpacing: 0.20
            )
        case "sky130MagicVIA1Metal1EnclosureViolation":
            return generatedSky130MagicVIA1EnclosureDocument(
                cellName: "SKY130_VIA1_MET1_ENCLOSURE_VIOLATION",
                metal1Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.275, y: 0.20),
                    size: LayoutSize(width: 0.625, height: 0.70)
                ),
                metal2Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.20, y: 0.20),
                    size: LayoutSize(width: 0.70, height: 0.70)
                )
            )
        case "sky130MagicVIA1Metal1EnclosureClean":
            return generatedSky130MagicVIA1EnclosureDocument(
                cellName: "SKY130_VIA1_MET1_ENCLOSURE_CLEAN",
                metal1Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.20, y: 0.20),
                    size: LayoutSize(width: 0.70, height: 0.70)
                ),
                metal2Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.20, y: 0.20),
                    size: LayoutSize(width: 0.70, height: 0.70)
                )
            )
        case "sky130MagicVIA1Metal2EnclosureViolation":
            return generatedSky130MagicVIA1EnclosureDocument(
                cellName: "SKY130_VIA1_MET2_ENCLOSURE_VIOLATION",
                metal1Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.20, y: 0.20),
                    size: LayoutSize(width: 0.70, height: 0.70)
                ),
                metal2Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.275, y: 0.20),
                    size: LayoutSize(width: 0.625, height: 0.70)
                )
            )
        case "sky130MagicVIA1Metal2EnclosureClean":
            return generatedSky130MagicVIA1EnclosureDocument(
                cellName: "SKY130_VIA1_MET2_ENCLOSURE_CLEAN",
                metal1Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.20, y: 0.20),
                    size: LayoutSize(width: 0.70, height: 0.70)
                ),
                metal2Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.20, y: 0.20),
                    size: LayoutSize(width: 0.70, height: 0.70)
                )
            )
        case "sky130MagicMetal2WidthViolation":
            return generatedSky130MagicMetal2Document(
                cellName: "SKY130_MET2_WIDTH_VIOLATION",
                metalWidth: 0.08
            )
        case "sky130MagicMetal2WidthClean":
            return generatedSky130MagicMetal2Document(
                cellName: "SKY130_MET2_WIDTH_CLEAN",
                metalWidth: 0.20
            )
        case "sky130MagicMetal2SpacingViolation":
            return generatedSky130MagicMetal2SpacingDocument(
                cellName: "SKY130_MET2_SPACING_VIOLATION",
                metalSpacing: 0.08
            )
        case "sky130MagicMetal2SpacingClean":
            return generatedSky130MagicMetal2SpacingDocument(
                cellName: "SKY130_MET2_SPACING_CLEAN",
                metalSpacing: 0.20
            )
        case "sky130MagicMetal2AreaViolation":
            return generatedSky130MagicMetal2AreaDocument(
                cellName: "SKY130_MET2_AREA_VIOLATION",
                metalSize: LayoutSize(width: 0.20, height: 0.20)
            )
        case "sky130MagicMetal2AreaClean":
            return generatedSky130MagicMetal2AreaDocument(
                cellName: "SKY130_MET2_AREA_CLEAN",
                metalSize: LayoutSize(width: 0.40, height: 0.40)
            )
        case "sky130MagicMetal2AngleViolation":
            return generatedSky130MagicMetal2AngleDocument(
                cellName: "SKY130_MET2_ANGLE_VIOLATION",
                points: [
                    LayoutPoint(x: 0.00, y: 0.00),
                    LayoutPoint(x: 2.00, y: 0.00),
                    LayoutPoint(x: 2.00, y: 1.00),
                    LayoutPoint(x: 1.20, y: 1.40),
                    LayoutPoint(x: 0.00, y: 1.00),
                ]
            )
        case "sky130MagicMetal2AngleClean":
            return generatedSky130MagicMetal2AngleDocument(
                cellName: "SKY130_MET2_ANGLE_CLEAN",
                points: [
                    LayoutPoint(x: 0.00, y: 0.00),
                    LayoutPoint(x: 2.00, y: 0.00),
                    LayoutPoint(x: 2.00, y: 1.00),
                    LayoutPoint(x: 1.00, y: 2.00),
                    LayoutPoint(x: 0.00, y: 1.00),
                ]
            )
        case "sky130MagicMetal2WideSpacingViolation":
            return generatedSky130MagicMetal2WideSpacingDocument(
                cellName: "SKY130_MET2_WIDE_SPACING_VIOLATION",
                spacing: 0.20
            )
        case "sky130MagicMetal2WideSpacingClean":
            return generatedSky130MagicMetal2WideSpacingDocument(
                cellName: "SKY130_MET2_WIDE_SPACING_CLEAN",
                spacing: 0.32
            )
        case "sky130MagicMetal2LargeAttachedSpacingViolation":
            return generatedSky130MagicMetal2LargeAttachedSpacingDocument(
                cellName: "SKY130_MET2_LARGE_ATTACHED_SPACING_VIOLATION",
                fingerSpacing: 0.20
            )
        case "sky130MagicMetal2LargeAttachedSpacingClean":
            return generatedSky130MagicMetal2LargeAttachedSpacingDocument(
                cellName: "SKY130_MET2_LARGE_ATTACHED_SPACING_CLEAN",
                fingerSpacing: 0.32
            )
        case "sky130MagicVIA2WidthViolation":
            return generatedSky130MagicVIA2WidthDocument(
                cellName: "SKY130_VIA2_WIDTH_VIOLATION",
                cutSize: LayoutSize(width: 0.12, height: 0.28)
            )
        case "sky130MagicVIA2WidthClean":
            return generatedSky130MagicVIA2WidthDocument(
                cellName: "SKY130_VIA2_WIDTH_CLEAN",
                cutSize: LayoutSize(width: 0.28, height: 0.28)
            )
        case "sky130MagicVIA2SpacingClean":
            return generatedSky130MagicVIA2SpacingDocument(
                cellName: "SKY130_VIA2_SPACING_CLEAN",
                cutSpacing: 0.18
            )
        case "sky130MagicVIA2Metal2EnclosureViolation":
            return generatedSky130MagicVIA2EnclosureDocument(
                cellName: "SKY130_VIA2_MET2_ENCLOSURE_VIOLATION",
                metal2Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.270, y: 0.20),
                    size: LayoutSize(width: 0.730, height: 0.80)
                ),
                metal3Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.20, y: 0.20),
                    size: LayoutSize(width: 0.80, height: 0.80)
                )
            )
        case "sky130MagicVIA2Metal2EnclosureClean":
            return generatedSky130MagicVIA2EnclosureDocument(
                cellName: "SKY130_VIA2_MET2_ENCLOSURE_CLEAN",
                metal2Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.20, y: 0.20),
                    size: LayoutSize(width: 0.80, height: 0.80)
                ),
                metal3Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.20, y: 0.20),
                    size: LayoutSize(width: 0.80, height: 0.80)
                )
            )
        case "sky130MagicVIA2Metal3EnclosureViolation":
            return generatedSky130MagicVIA2EnclosureDocument(
                cellName: "SKY130_VIA2_MET3_ENCLOSURE_VIOLATION",
                metal2Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.20, y: 0.20),
                    size: LayoutSize(width: 0.80, height: 0.80)
                ),
                metal3Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.285, y: 0.20),
                    size: LayoutSize(width: 0.715, height: 0.80)
                )
            )
        case "sky130MagicVIA2Metal3EnclosureClean":
            return generatedSky130MagicVIA2EnclosureDocument(
                cellName: "SKY130_VIA2_MET3_ENCLOSURE_CLEAN",
                metal2Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.20, y: 0.20),
                    size: LayoutSize(width: 0.80, height: 0.80)
                ),
                metal3Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.20, y: 0.20),
                    size: LayoutSize(width: 0.80, height: 0.80)
                )
            )
        case "sky130MagicMetal3WidthViolation":
            return generatedSky130MagicMetal3Document(
                cellName: "SKY130_MET3_WIDTH_VIOLATION",
                metalWidth: 0.20
            )
        case "sky130MagicMetal3WidthClean":
            return generatedSky130MagicMetal3Document(
                cellName: "SKY130_MET3_WIDTH_CLEAN",
                metalWidth: 0.40
            )
        case "sky130MagicMetal3SpacingViolation":
            return generatedSky130MagicMetal3SpacingDocument(
                cellName: "SKY130_MET3_SPACING_VIOLATION",
                metalSpacing: 0.20
            )
        case "sky130MagicMetal3SpacingClean":
            return generatedSky130MagicMetal3SpacingDocument(
                cellName: "SKY130_MET3_SPACING_CLEAN",
                metalSpacing: 0.40
            )
        case "sky130MagicMetal3AreaViolation":
            return generatedSky130MagicMetal3AreaDocument(
                cellName: "SKY130_MET3_AREA_VIOLATION",
                metalSize: LayoutSize(width: 0.45, height: 0.45)
            )
        case "sky130MagicMetal3AreaClean":
            return generatedSky130MagicMetal3AreaDocument(
                cellName: "SKY130_MET3_AREA_CLEAN",
                metalSize: LayoutSize(width: 0.60, height: 0.60)
            )
        case "sky130MagicMetal3AngleViolation":
            return generatedSky130MagicMetal3AngleDocument(
                cellName: "SKY130_MET3_ANGLE_VIOLATION",
                points: [
                    LayoutPoint(x: 0.00, y: 0.00),
                    LayoutPoint(x: 2.00, y: 0.00),
                    LayoutPoint(x: 2.00, y: 1.00),
                    LayoutPoint(x: 1.20, y: 1.40),
                    LayoutPoint(x: 0.00, y: 1.00),
                ]
            )
        case "sky130MagicMetal3AngleClean":
            return generatedSky130MagicMetal3AngleDocument(
                cellName: "SKY130_MET3_ANGLE_CLEAN",
                points: [
                    LayoutPoint(x: 0.00, y: 0.00),
                    LayoutPoint(x: 2.00, y: 0.00),
                    LayoutPoint(x: 2.00, y: 1.00),
                    LayoutPoint(x: 1.00, y: 2.00),
                    LayoutPoint(x: 0.00, y: 1.00),
                ]
            )
        case "sky130MagicMetal3WideSpacingViolation":
            return generatedSky130MagicMetal3WideSpacingDocument(
                cellName: "SKY130_MET3_WIDE_SPACING_VIOLATION",
                spacing: 0.32
            )
        case "sky130MagicMetal3WideSpacingClean":
            return generatedSky130MagicMetal3WideSpacingDocument(
                cellName: "SKY130_MET3_WIDE_SPACING_CLEAN",
                spacing: 0.50
            )
        case "sky130MagicMetal3LargeAttachedSpacingViolation":
            return generatedSky130MagicMetal3LargeAttachedSpacingDocument(
                cellName: "SKY130_MET3_LARGE_ATTACHED_SPACING_VIOLATION",
                fingerSpacing: 0.32
            )
        case "sky130MagicMetal3LargeAttachedSpacingClean":
            return generatedSky130MagicMetal3LargeAttachedSpacingDocument(
                cellName: "SKY130_MET3_LARGE_ATTACHED_SPACING_CLEAN",
                fingerSpacing: 0.50
            )
        case "sky130MagicVIA3WidthViolation":
            return generatedSky130MagicVIA3WidthDocument(
                cellName: "SKY130_VIA3_WIDTH_VIOLATION",
                cutSize: LayoutSize(width: 0.12, height: 0.32)
            )
        case "sky130MagicVIA3WidthClean":
            return generatedSky130MagicVIA3WidthDocument(
                cellName: "SKY130_VIA3_WIDTH_CLEAN",
                cutSize: LayoutSize(width: 0.32, height: 0.32)
            )
        case "sky130MagicVIA3SpacingClean":
            return generatedSky130MagicVIA3SpacingDocument(
                cellName: "SKY130_VIA3_SPACING_CLEAN",
                cutSpacing: 0.24
            )
        case "sky130MagicVIA3Metal3EnclosureViolation":
            return generatedSky130MagicVIA3EnclosureDocument(
                cellName: "SKY130_VIA3_MET3_ENCLOSURE_VIOLATION",
                metal3Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.285, y: 0.20),
                    size: LayoutSize(width: 0.835, height: 0.90)
                ),
                metal4Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.20, y: 0.20),
                    size: LayoutSize(width: 0.90, height: 0.90)
                )
            )
        case "sky130MagicVIA3Metal3EnclosureClean":
            return generatedSky130MagicVIA3EnclosureDocument(
                cellName: "SKY130_VIA3_MET3_ENCLOSURE_CLEAN",
                metal3Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.20, y: 0.20),
                    size: LayoutSize(width: 0.90, height: 0.90)
                ),
                metal4Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.20, y: 0.20),
                    size: LayoutSize(width: 0.90, height: 0.90)
                )
            )
        case "sky130MagicVIA3Metal4EnclosureViolation":
            return generatedSky130MagicVIA3EnclosureDocument(
                cellName: "SKY130_VIA3_MET4_ENCLOSURE_VIOLATION",
                metal3Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.20, y: 0.20),
                    size: LayoutSize(width: 0.90, height: 0.90)
                ),
                metal4Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.30, y: 0.20),
                    size: LayoutSize(width: 0.90, height: 0.90)
                )
            )
        case "sky130MagicVIA3Metal4EnclosureClean":
            return generatedSky130MagicVIA3EnclosureDocument(
                cellName: "SKY130_VIA3_MET4_ENCLOSURE_CLEAN",
                metal3Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.20, y: 0.20),
                    size: LayoutSize(width: 0.90, height: 0.90)
                ),
                metal4Rect: LayoutRect(
                    origin: LayoutPoint(x: 0.20, y: 0.20),
                    size: LayoutSize(width: 0.90, height: 0.90)
                )
            )
        case "sky130MagicMetal4WidthViolation":
            return generatedSky130MagicMetal4Document(
                cellName: "SKY130_MET4_WIDTH_VIOLATION",
                metalWidth: 0.20
            )
        case "sky130MagicMetal4WidthClean":
            return generatedSky130MagicMetal4Document(
                cellName: "SKY130_MET4_WIDTH_CLEAN",
                metalWidth: 0.40
            )
        case "sky130MagicMetal4SpacingViolation":
            return generatedSky130MagicMetal4SpacingDocument(
                cellName: "SKY130_MET4_SPACING_VIOLATION",
                metalSpacing: 0.20
            )
        case "sky130MagicMetal4SpacingClean":
            return generatedSky130MagicMetal4SpacingDocument(
                cellName: "SKY130_MET4_SPACING_CLEAN",
                metalSpacing: 0.40
            )
        case "sky130MagicMetal4AreaViolation":
            return generatedSky130MagicMetal4AreaDocument(
                cellName: "SKY130_MET4_AREA_VIOLATION",
                metalSize: LayoutSize(width: 0.45, height: 0.45)
            )
        case "sky130MagicMetal4AreaClean":
            return generatedSky130MagicMetal4AreaDocument(
                cellName: "SKY130_MET4_AREA_CLEAN",
                metalSize: LayoutSize(width: 0.60, height: 0.60)
            )
        case "sky130MagicMetal4AngleViolation":
            return generatedSky130MagicMetal4AngleDocument(
                cellName: "SKY130_MET4_ANGLE_VIOLATION",
                points: [
                    LayoutPoint(x: 0.00, y: 0.00),
                    LayoutPoint(x: 2.00, y: 0.00),
                    LayoutPoint(x: 2.00, y: 1.00),
                    LayoutPoint(x: 1.20, y: 1.40),
                    LayoutPoint(x: 0.00, y: 1.00),
                ]
            )
        case "sky130MagicMetal4AngleClean":
            return generatedSky130MagicMetal4AngleDocument(
                cellName: "SKY130_MET4_ANGLE_CLEAN",
                points: [
                    LayoutPoint(x: 0.00, y: 0.00),
                    LayoutPoint(x: 2.00, y: 0.00),
                    LayoutPoint(x: 2.00, y: 1.00),
                    LayoutPoint(x: 1.00, y: 2.00),
                    LayoutPoint(x: 0.00, y: 1.00),
                ]
            )
        case "sky130MagicMetal4WideSpacingViolation":
            return generatedSky130MagicMetal4WideSpacingDocument(
                cellName: "SKY130_MET4_WIDE_SPACING_VIOLATION",
                spacing: 0.32
            )
        case "sky130MagicMetal4WideSpacingClean":
            return generatedSky130MagicMetal4WideSpacingDocument(
                cellName: "SKY130_MET4_WIDE_SPACING_CLEAN",
                spacing: 0.50
            )
        case "sky130MagicMetal4LargeAttachedSpacingViolation":
            return generatedSky130MagicMetal4LargeAttachedSpacingDocument(
                cellName: "SKY130_MET4_LARGE_ATTACHED_SPACING_VIOLATION",
                fingerSpacing: 0.32
            )
        case "sky130MagicMetal4LargeAttachedSpacingClean":
            return generatedSky130MagicMetal4LargeAttachedSpacingDocument(
                cellName: "SKY130_MET4_LARGE_ATTACHED_SPACING_CLEAN",
                fingerSpacing: 0.50
            )
        case "sky130MagicMetal5WidthViolation":
            return generatedSky130MagicMetal5Document(
                cellName: "SKY130_MET5_WIDTH_VIOLATION",
                metalWidth: 1.20
            )
        case "sky130MagicMetal5WidthClean":
            return generatedSky130MagicMetal5Document(
                cellName: "SKY130_MET5_WIDTH_CLEAN",
                metalWidth: 1.70
            )
        case "sky130MagicMetal5SpacingViolation":
            return generatedSky130MagicMetal5SpacingDocument(
                cellName: "SKY130_MET5_SPACING_VIOLATION",
                metalSpacing: 1.20
            )
        case "sky130MagicMetal5SpacingClean":
            return generatedSky130MagicMetal5SpacingDocument(
                cellName: "SKY130_MET5_SPACING_CLEAN",
                metalSpacing: 1.70
            )
        case "sky130MagicMetal5AreaViolation":
            return generatedSky130MagicMetal5AreaDocument(
                cellName: "SKY130_MET5_AREA_VIOLATION",
                metalSize: LayoutSize(width: 1.70, height: 2.00)
            )
        case "sky130MagicMetal5AreaClean":
            return generatedSky130MagicMetal5AreaDocument(
                cellName: "SKY130_MET5_AREA_CLEAN",
                metalSize: LayoutSize(width: 1.70, height: 2.50)
            )
        case "sky130MagicMetal5AngleViolation":
            return generatedSky130MagicMetal5AngleDocument(
                cellName: "SKY130_MET5_ANGLE_VIOLATION",
                points: [
                    LayoutPoint(x: 0.00, y: 0.00),
                    LayoutPoint(x: 3.00, y: 0.00),
                    LayoutPoint(x: 3.00, y: 2.00),
                    LayoutPoint(x: 1.90, y: 2.60),
                    LayoutPoint(x: 0.00, y: 2.00),
                ]
            )
        case "sky130MagicMetal5AngleClean":
            return generatedSky130MagicMetal5AngleDocument(
                cellName: "SKY130_MET5_ANGLE_CLEAN",
                points: [
                    LayoutPoint(x: 0.00, y: 0.00),
                    LayoutPoint(x: 3.00, y: 0.00),
                    LayoutPoint(x: 3.00, y: 2.00),
                    LayoutPoint(x: 1.50, y: 3.50),
                    LayoutPoint(x: 0.00, y: 2.00),
                ]
            )
        case "sky130MagicVIA4WidthViolation":
            return generatedSky130MagicVIA4WidthDocument(
                cellName: "SKY130_VIA4_WIDTH_VIOLATION",
                cutSize: LayoutSize(width: 0.20, height: 1.18)
            )
        case "sky130MagicVIA4WidthClean":
            return generatedSky130MagicVIA4WidthDocument(
                cellName: "SKY130_VIA4_WIDTH_CLEAN",
                cutSize: LayoutSize(width: 1.18, height: 1.18)
            )
        default:
            throw DRCError.invalidInput("Unsupported generated DRC layout fixture: \(fixture.kind)")
        }
    }

}
