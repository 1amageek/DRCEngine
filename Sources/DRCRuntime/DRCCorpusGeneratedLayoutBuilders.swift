import LayoutCore

extension DRCCorpusGeneratedLayoutFactory {
    func generatedMinimumCutDocument(cutCount: Int) -> LayoutDocument {
        let m1 = LayoutLayerID(name: "M1", purpose: "drawing")
        let m2 = LayoutLayerID(name: "M2", purpose: "drawing")
        let via1 = LayoutLayerID(name: "VIA1", purpose: "cut")
        var cell = LayoutCell(name: "STD_DRC")
        cell.shapes = [
            LayoutShape(
                layer: m1,
                geometry: .rect(LayoutRect(
                    origin: LayoutPoint(x: 0, y: 0),
                    size: LayoutSize(width: 2.0, height: 2.0)
                ))
            ),
            LayoutShape(
                layer: m2,
                geometry: .rect(LayoutRect(
                    origin: LayoutPoint(x: 0, y: 0),
                    size: LayoutSize(width: 2.0, height: 2.0)
                ))
            ),
        ]
        let cutOrigins = [
            LayoutPoint(x: 0.5, y: 0.5),
            LayoutPoint(x: 1.1, y: 0.5),
        ]
        cell.shapes.append(contentsOf: cutOrigins.prefix(max(0, min(cutCount, cutOrigins.count))).map { origin in
            LayoutShape(
                layer: via1,
                geometry: .rect(LayoutRect(
                    origin: origin,
                    size: LayoutSize(width: 0.22, height: 0.22)
                ))
            )
        })
        return LayoutDocument(name: "STD_DRC", cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetal1Document(cellName: String, metalWidth: Double) -> LayoutDocument {
        let metal1 = LayoutLayerID(name: "MET1", purpose: "drawing")
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(
                layer: metal1,
                geometry: .rect(LayoutRect(
                    origin: LayoutPoint(x: 0, y: 0),
                    size: LayoutSize(width: 2.0, height: metalWidth)
                ))
            ),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetal1SpacingDocument(
        cellName: String,
        metalSpacing: Double
    ) -> LayoutDocument {
        let metal1 = LayoutLayerID(name: "MET1", purpose: "drawing")
        let metalHeight = 0.20
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(
                layer: metal1,
                geometry: .rect(LayoutRect(
                    origin: LayoutPoint(x: 0, y: 0),
                    size: LayoutSize(width: 2.0, height: metalHeight)
                ))
            ),
            LayoutShape(
                layer: metal1,
                geometry: .rect(LayoutRect(
                    origin: LayoutPoint(x: 0, y: metalHeight + metalSpacing),
                    size: LayoutSize(width: 2.0, height: metalHeight)
                ))
            ),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetal1AreaDocument(
        cellName: String,
        metalSize: LayoutSize
    ) -> LayoutDocument {
        let metal1 = LayoutLayerID(name: "MET1", purpose: "drawing")
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(
                layer: metal1,
                geometry: .rect(LayoutRect(
                    origin: LayoutPoint(x: 0, y: 0),
                    size: metalSize
                ))
            ),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetal1AngleDocument(
        cellName: String,
        points: [LayoutPoint]
    ) -> LayoutDocument {
        let metal1 = LayoutLayerID(name: "MET1", purpose: "drawing")
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(
                layer: metal1,
                geometry: .polygon(LayoutPolygon(points: points))
            ),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetal1WideSpacingDocument(
        cellName: String,
        spacing: Double
    ) -> LayoutDocument {
        let metal1 = LayoutLayerID(name: "MET1", purpose: "drawing")
        let wideMetal = LayoutRect(
            origin: LayoutPoint(x: 0, y: 0),
            size: LayoutSize(width: 3.20, height: 3.20)
        )
        let neighborMetal = LayoutRect(
            origin: LayoutPoint(x: 0, y: wideMetal.maxY + spacing),
            size: LayoutSize(width: 0.40, height: 0.40)
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(layer: metal1, geometry: .rect(wideMetal)),
            LayoutShape(layer: metal1, geometry: .rect(neighborMetal)),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetal1LargeAttachedSpacingDocument(
        cellName: String,
        fingerSpacing: Double
    ) -> LayoutDocument {
        let metal1 = LayoutLayerID(name: "MET1", purpose: "drawing")
        let base = LayoutRect(
            origin: LayoutPoint(x: 0, y: 0),
            size: LayoutSize(width: 4.0, height: 4.0)
        )
        let firstFinger = LayoutRect(
            origin: LayoutPoint(x: 0, y: base.maxY),
            size: LayoutSize(width: 1.0, height: 1.0)
        )
        let secondFinger = LayoutRect(
            origin: LayoutPoint(x: firstFinger.maxX + fingerSpacing, y: base.maxY),
            size: LayoutSize(width: 1.0, height: 1.0)
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [base, firstFinger, secondFinger].map { rect in
            LayoutShape(layer: metal1, geometry: .rect(rect))
        }
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetal1MCONEnclosureDocument(
        cellName: String,
        metal1Rect: LayoutRect
    ) -> LayoutDocument {
        let localInterconnect = LayoutLayerID(name: "LI", purpose: "drawing")
        let mcon = LayoutLayerID(name: "MCON", purpose: "cut")
        let metal1 = LayoutLayerID(name: "MET1", purpose: "drawing")
        let localInterconnectRect = LayoutRect(
            origin: LayoutPoint(x: 0.23, y: 0.23),
            size: LayoutSize(width: 0.45, height: 0.45)
        )
        let mconRect = LayoutRect(
            origin: LayoutPoint(x: 0.30, y: 0.30),
            size: LayoutSize(width: 0.17, height: 0.17)
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(
                layer: localInterconnect,
                geometry: .rect(localInterconnectRect)
            ),
            LayoutShape(
                layer: mcon,
                geometry: .rect(mconRect)
            ),
            LayoutShape(
                layer: metal1,
                geometry: .rect(metal1Rect)
            ),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMCONWidthDocument(
        cellName: String,
        contactSize: LayoutSize
    ) -> LayoutDocument {
        let localInterconnect = LayoutLayerID(name: "LI", purpose: "drawing")
        let mcon = LayoutLayerID(name: "MCON", purpose: "cut")
        let metal1 = LayoutLayerID(name: "MET1", purpose: "drawing")
        let coverRect = LayoutRect(
            origin: LayoutPoint(x: 0.20, y: 0.20),
            size: LayoutSize(width: 0.50, height: 0.50)
        )
        let mconRect = LayoutRect(
            origin: LayoutPoint(x: 0.30, y: 0.30),
            size: contactSize
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(layer: localInterconnect, geometry: .rect(coverRect)),
            LayoutShape(layer: mcon, geometry: .rect(mconRect)),
            LayoutShape(layer: metal1, geometry: .rect(coverRect)),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMCONSpacingDocument(
        cellName: String,
        contactSpacing: Double
    ) -> LayoutDocument {
        let localInterconnect = LayoutLayerID(name: "LI", purpose: "drawing")
        let mcon = LayoutLayerID(name: "MCON", purpose: "cut")
        let metal1 = LayoutLayerID(name: "MET1", purpose: "drawing")
        let contactSize = LayoutSize(width: 0.17, height: 0.17)
        let firstContact = LayoutRect(
            origin: LayoutPoint(x: 0.30, y: 0.30),
            size: contactSize
        )
        let secondContact = LayoutRect(
            origin: LayoutPoint(x: firstContact.maxX + contactSpacing, y: 0.30),
            size: contactSize
        )
        let coverRect = LayoutRect(
            origin: LayoutPoint(x: 0.20, y: 0.20),
            size: LayoutSize(width: 0.54 + contactSpacing, height: 0.37)
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(layer: localInterconnect, geometry: .rect(coverRect)),
            LayoutShape(layer: mcon, geometry: .rect(firstContact)),
            LayoutShape(layer: mcon, geometry: .rect(secondContact)),
            LayoutShape(layer: metal1, geometry: .rect(coverRect)),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicVIA1WidthDocument(
        cellName: String,
        cutSize: LayoutSize
    ) -> LayoutDocument {
        let metal1 = LayoutLayerID(name: "MET1", purpose: "drawing")
        let via1 = LayoutLayerID(name: "VIA1", purpose: "cut")
        let metal2 = LayoutLayerID(name: "MET2", purpose: "drawing")
        let coverRect = LayoutRect(
            origin: LayoutPoint(x: 0.20, y: 0.20),
            size: LayoutSize(width: 0.70, height: 0.70)
        )
        let cutRect = LayoutRect(
            origin: LayoutPoint(x: 0.30, y: 0.30),
            size: cutSize
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(layer: metal1, geometry: .rect(coverRect)),
            LayoutShape(layer: via1, geometry: .rect(cutRect)),
            LayoutShape(layer: metal2, geometry: .rect(coverRect)),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicVIA1SpacingDocument(
        cellName: String,
        cutSpacing: Double
    ) -> LayoutDocument {
        let metal1 = LayoutLayerID(name: "MET1", purpose: "drawing")
        let via1 = LayoutLayerID(name: "VIA1", purpose: "cut")
        let metal2 = LayoutLayerID(name: "MET2", purpose: "drawing")
        let cutSize = LayoutSize(width: 0.15, height: 0.15)
        let firstCut = LayoutRect(
            origin: LayoutPoint(x: 0.30, y: 0.30),
            size: cutSize
        )
        let secondCut = LayoutRect(
            origin: LayoutPoint(x: firstCut.maxX + cutSpacing, y: 0.30),
            size: cutSize
        )
        let coverRect = LayoutRect(
            origin: LayoutPoint(x: 0.20, y: 0.20),
            size: LayoutSize(width: 0.50 + cutSpacing, height: 0.35)
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(layer: metal1, geometry: .rect(coverRect)),
            LayoutShape(layer: via1, geometry: .rect(firstCut)),
            LayoutShape(layer: via1, geometry: .rect(secondCut)),
            LayoutShape(layer: metal2, geometry: .rect(coverRect)),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicVIA1EnclosureDocument(
        cellName: String,
        metal1Rect: LayoutRect,
        metal2Rect: LayoutRect
    ) -> LayoutDocument {
        let metal1 = LayoutLayerID(name: "MET1", purpose: "drawing")
        let via1 = LayoutLayerID(name: "VIA1", purpose: "cut")
        let metal2 = LayoutLayerID(name: "MET2", purpose: "drawing")
        let cutRect = LayoutRect(
            origin: LayoutPoint(x: 0.30, y: 0.30),
            size: LayoutSize(width: 0.26, height: 0.26)
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(layer: metal1, geometry: .rect(metal1Rect)),
            LayoutShape(layer: via1, geometry: .rect(cutRect)),
            LayoutShape(layer: metal2, geometry: .rect(metal2Rect)),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetal2Document(
        cellName: String,
        metalWidth: Double
    ) -> LayoutDocument {
        let metal2 = LayoutLayerID(name: "MET2", purpose: "drawing")
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(
                layer: metal2,
                geometry: .rect(LayoutRect(
                    origin: LayoutPoint(x: 0, y: 0),
                    size: LayoutSize(width: 2.0, height: metalWidth)
                ))
            ),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetal2SpacingDocument(
        cellName: String,
        metalSpacing: Double
    ) -> LayoutDocument {
        let metal2 = LayoutLayerID(name: "MET2", purpose: "drawing")
        let firstMetal = LayoutRect(
            origin: LayoutPoint(x: 0, y: 0),
            size: LayoutSize(width: 2.0, height: 0.20)
        )
        let secondMetal = LayoutRect(
            origin: LayoutPoint(x: 0, y: firstMetal.maxY + metalSpacing),
            size: LayoutSize(width: 2.0, height: 0.20)
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [firstMetal, secondMetal].map { rect in
            LayoutShape(layer: metal2, geometry: .rect(rect))
        }
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetal2AreaDocument(
        cellName: String,
        metalSize: LayoutSize
    ) -> LayoutDocument {
        let metal2 = LayoutLayerID(name: "MET2", purpose: "drawing")
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(
                layer: metal2,
                geometry: .rect(LayoutRect(
                    origin: LayoutPoint(x: 0, y: 0),
                    size: metalSize
                ))
            ),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetal2AngleDocument(
        cellName: String,
        points: [LayoutPoint]
    ) -> LayoutDocument {
        let metal2 = LayoutLayerID(name: "MET2", purpose: "drawing")
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(
                layer: metal2,
                geometry: .polygon(LayoutPolygon(points: points))
            ),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetal2WideSpacingDocument(
        cellName: String,
        spacing: Double
    ) -> LayoutDocument {
        let metal2 = LayoutLayerID(name: "MET2", purpose: "drawing")
        let wideMetal = LayoutRect(
            origin: LayoutPoint(x: 0, y: 0),
            size: LayoutSize(width: 3.20, height: 3.20)
        )
        let neighborMetal = LayoutRect(
            origin: LayoutPoint(x: 0, y: wideMetal.maxY + spacing),
            size: LayoutSize(width: 0.40, height: 0.40)
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(layer: metal2, geometry: .rect(wideMetal)),
            LayoutShape(layer: metal2, geometry: .rect(neighborMetal)),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetal2LargeAttachedSpacingDocument(
        cellName: String,
        fingerSpacing: Double
    ) -> LayoutDocument {
        let metal2 = LayoutLayerID(name: "MET2", purpose: "drawing")
        let base = LayoutRect(
            origin: LayoutPoint(x: 0, y: 0),
            size: LayoutSize(width: 4.0, height: 4.0)
        )
        let firstFinger = LayoutRect(
            origin: LayoutPoint(x: 0, y: base.maxY),
            size: LayoutSize(width: 1.0, height: 1.0)
        )
        let secondFinger = LayoutRect(
            origin: LayoutPoint(x: firstFinger.maxX + fingerSpacing, y: base.maxY),
            size: LayoutSize(width: 1.0, height: 1.0)
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [base, firstFinger, secondFinger].map { rect in
            LayoutShape(layer: metal2, geometry: .rect(rect))
        }
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicVIA2WidthDocument(
        cellName: String,
        cutSize: LayoutSize
    ) -> LayoutDocument {
        let metal2 = LayoutLayerID(name: "MET2", purpose: "drawing")
        let via2 = LayoutLayerID(name: "VIA2", purpose: "cut")
        let metal3 = LayoutLayerID(name: "MET3", purpose: "drawing")
        let coverRect = LayoutRect(
            origin: LayoutPoint(x: 0.20, y: 0.20),
            size: LayoutSize(width: 0.80, height: 0.80)
        )
        let cutRect = LayoutRect(
            origin: LayoutPoint(x: 0.30, y: 0.30),
            size: cutSize
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(layer: metal2, geometry: .rect(coverRect)),
            LayoutShape(layer: via2, geometry: .rect(cutRect)),
            LayoutShape(layer: metal3, geometry: .rect(coverRect)),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicVIA2SpacingDocument(
        cellName: String,
        cutSpacing: Double
    ) -> LayoutDocument {
        let metal2 = LayoutLayerID(name: "MET2", purpose: "drawing")
        let via2 = LayoutLayerID(name: "VIA2", purpose: "cut")
        let metal3 = LayoutLayerID(name: "MET3", purpose: "drawing")
        let cutSize = LayoutSize(width: 0.28, height: 0.28)
        let firstCut = LayoutRect(
            origin: LayoutPoint(x: 0.30, y: 0.30),
            size: cutSize
        )
        let secondCut = LayoutRect(
            origin: LayoutPoint(x: firstCut.maxX + cutSpacing, y: 0.30),
            size: cutSize
        )
        let coverRect = LayoutRect(
            origin: LayoutPoint(x: 0.20, y: 0.20),
            size: LayoutSize(width: 0.90 + cutSpacing, height: 0.80)
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(layer: metal2, geometry: .rect(coverRect)),
            LayoutShape(layer: via2, geometry: .rect(firstCut)),
            LayoutShape(layer: via2, geometry: .rect(secondCut)),
            LayoutShape(layer: metal3, geometry: .rect(coverRect)),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicVIA2EnclosureDocument(
        cellName: String,
        metal2Rect: LayoutRect,
        metal3Rect: LayoutRect
    ) -> LayoutDocument {
        let metal2 = LayoutLayerID(name: "MET2", purpose: "drawing")
        let via2 = LayoutLayerID(name: "VIA2", purpose: "cut")
        let metal3 = LayoutLayerID(name: "MET3", purpose: "drawing")
        let cutRect = LayoutRect(
            origin: LayoutPoint(x: 0.30, y: 0.30),
            size: LayoutSize(width: 0.28, height: 0.28)
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(layer: metal2, geometry: .rect(metal2Rect)),
            LayoutShape(layer: via2, geometry: .rect(cutRect)),
            LayoutShape(layer: metal3, geometry: .rect(metal3Rect)),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetal3Document(
        cellName: String,
        metalWidth: Double
    ) -> LayoutDocument {
        generatedSky130MagicMetalDocument(
            cellName: cellName,
            layer: LayoutLayerID(name: "MET3", purpose: "drawing"),
            metalWidth: metalWidth
        )
    }

    func generatedSky130MagicMetal3SpacingDocument(
        cellName: String,
        metalSpacing: Double
    ) -> LayoutDocument {
        generatedSky130MagicMetalSpacingDocument(
            cellName: cellName,
            layer: LayoutLayerID(name: "MET3", purpose: "drawing"),
            metalSpacing: metalSpacing,
            metalWidth: 0.40
        )
    }

    func generatedSky130MagicMetal3AreaDocument(
        cellName: String,
        metalSize: LayoutSize
    ) -> LayoutDocument {
        generatedSky130MagicMetalAreaDocument(
            cellName: cellName,
            layer: LayoutLayerID(name: "MET3", purpose: "drawing"),
            metalSize: metalSize
        )
    }

    func generatedSky130MagicMetal3AngleDocument(
        cellName: String,
        points: [LayoutPoint]
    ) -> LayoutDocument {
        generatedSky130MagicMetalAngleDocument(
            cellName: cellName,
            layer: LayoutLayerID(name: "MET3", purpose: "drawing"),
            points: points
        )
    }

    func generatedSky130MagicMetal3WideSpacingDocument(
        cellName: String,
        spacing: Double
    ) -> LayoutDocument {
        generatedSky130MagicMetalWideSpacingDocument(
            cellName: cellName,
            layer: LayoutLayerID(name: "MET3", purpose: "drawing"),
            spacing: spacing
        )
    }

    func generatedSky130MagicMetal3LargeAttachedSpacingDocument(
        cellName: String,
        fingerSpacing: Double
    ) -> LayoutDocument {
        generatedSky130MagicMetalLargeAttachedSpacingDocument(
            cellName: cellName,
            layer: LayoutLayerID(name: "MET3", purpose: "drawing"),
            fingerSpacing: fingerSpacing
        )
    }

    func generatedSky130MagicVIA3WidthDocument(
        cellName: String,
        cutSize: LayoutSize
    ) -> LayoutDocument {
        let metal3 = LayoutLayerID(name: "MET3", purpose: "drawing")
        let via3 = LayoutLayerID(name: "VIA3", purpose: "cut")
        let metal4 = LayoutLayerID(name: "MET4", purpose: "drawing")
        let coverRect = LayoutRect(
            origin: LayoutPoint(x: 0.20, y: 0.20),
            size: LayoutSize(width: 0.90, height: 0.90)
        )
        let cutRect = LayoutRect(
            origin: LayoutPoint(x: 0.30, y: 0.30),
            size: cutSize
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(layer: metal3, geometry: .rect(coverRect)),
            LayoutShape(layer: via3, geometry: .rect(cutRect)),
            LayoutShape(layer: metal4, geometry: .rect(coverRect)),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicVIA3SpacingDocument(
        cellName: String,
        cutSpacing: Double
    ) -> LayoutDocument {
        let metal3 = LayoutLayerID(name: "MET3", purpose: "drawing")
        let via3 = LayoutLayerID(name: "VIA3", purpose: "cut")
        let metal4 = LayoutLayerID(name: "MET4", purpose: "drawing")
        let cutSize = LayoutSize(width: 0.32, height: 0.32)
        let firstCut = LayoutRect(
            origin: LayoutPoint(x: 0.30, y: 0.30),
            size: cutSize
        )
        let secondCut = LayoutRect(
            origin: LayoutPoint(x: firstCut.maxX + cutSpacing, y: 0.30),
            size: cutSize
        )
        let coverRect = LayoutRect(
            origin: LayoutPoint(x: 0.20, y: 0.20),
            size: LayoutSize(width: 1.04 + cutSpacing, height: 0.90)
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(layer: metal3, geometry: .rect(coverRect)),
            LayoutShape(layer: via3, geometry: .rect(firstCut)),
            LayoutShape(layer: via3, geometry: .rect(secondCut)),
            LayoutShape(layer: metal4, geometry: .rect(coverRect)),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicVIA3EnclosureDocument(
        cellName: String,
        metal3Rect: LayoutRect,
        metal4Rect: LayoutRect
    ) -> LayoutDocument {
        let metal3 = LayoutLayerID(name: "MET3", purpose: "drawing")
        let via3 = LayoutLayerID(name: "VIA3", purpose: "cut")
        let metal4 = LayoutLayerID(name: "MET4", purpose: "drawing")
        let cutRect = LayoutRect(
            origin: LayoutPoint(x: 0.30, y: 0.30),
            size: LayoutSize(width: 0.32, height: 0.32)
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(layer: metal3, geometry: .rect(metal3Rect)),
            LayoutShape(layer: via3, geometry: .rect(cutRect)),
            LayoutShape(layer: metal4, geometry: .rect(metal4Rect)),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetal4Document(
        cellName: String,
        metalWidth: Double
    ) -> LayoutDocument {
        generatedSky130MagicMetalDocument(
            cellName: cellName,
            layer: LayoutLayerID(name: "MET4", purpose: "drawing"),
            metalWidth: metalWidth
        )
    }

    func generatedSky130MagicMetal4SpacingDocument(
        cellName: String,
        metalSpacing: Double
    ) -> LayoutDocument {
        generatedSky130MagicMetalSpacingDocument(
            cellName: cellName,
            layer: LayoutLayerID(name: "MET4", purpose: "drawing"),
            metalSpacing: metalSpacing,
            metalWidth: 0.40
        )
    }

    func generatedSky130MagicMetal4AreaDocument(
        cellName: String,
        metalSize: LayoutSize
    ) -> LayoutDocument {
        generatedSky130MagicMetalAreaDocument(
            cellName: cellName,
            layer: LayoutLayerID(name: "MET4", purpose: "drawing"),
            metalSize: metalSize
        )
    }

    func generatedSky130MagicMetal4AngleDocument(
        cellName: String,
        points: [LayoutPoint]
    ) -> LayoutDocument {
        generatedSky130MagicMetalAngleDocument(
            cellName: cellName,
            layer: LayoutLayerID(name: "MET4", purpose: "drawing"),
            points: points
        )
    }

    func generatedSky130MagicMetal4WideSpacingDocument(
        cellName: String,
        spacing: Double
    ) -> LayoutDocument {
        generatedSky130MagicMetalWideSpacingDocument(
            cellName: cellName,
            layer: LayoutLayerID(name: "MET4", purpose: "drawing"),
            spacing: spacing
        )
    }

    func generatedSky130MagicMetal4LargeAttachedSpacingDocument(
        cellName: String,
        fingerSpacing: Double
    ) -> LayoutDocument {
        generatedSky130MagicMetalLargeAttachedSpacingDocument(
            cellName: cellName,
            layer: LayoutLayerID(name: "MET4", purpose: "drawing"),
            fingerSpacing: fingerSpacing
        )
    }

    func generatedSky130MagicMetal5Document(
        cellName: String,
        metalWidth: Double
    ) -> LayoutDocument {
        let metal5 = LayoutLayerID(name: "MET5", purpose: "drawing")
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(
                layer: metal5,
                geometry: .rect(LayoutRect(
                    origin: LayoutPoint(x: 0, y: 0),
                    size: LayoutSize(width: 4.00, height: metalWidth)
                ))
            ),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetal5SpacingDocument(
        cellName: String,
        metalSpacing: Double
    ) -> LayoutDocument {
        let metal5 = LayoutLayerID(name: "MET5", purpose: "drawing")
        let firstMetal = LayoutRect(
            origin: LayoutPoint(x: 0, y: 0),
            size: LayoutSize(width: 3.00, height: 1.70)
        )
        let secondMetal = LayoutRect(
            origin: LayoutPoint(x: 0, y: firstMetal.maxY + metalSpacing),
            size: LayoutSize(width: 3.00, height: 1.70)
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [firstMetal, secondMetal].map { rect in
            LayoutShape(layer: metal5, geometry: .rect(rect))
        }
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetal5AreaDocument(
        cellName: String,
        metalSize: LayoutSize
    ) -> LayoutDocument {
        generatedSky130MagicMetalAreaDocument(
            cellName: cellName,
            layer: LayoutLayerID(name: "MET5", purpose: "drawing"),
            metalSize: metalSize
        )
    }

    func generatedSky130MagicMetal5AngleDocument(
        cellName: String,
        points: [LayoutPoint]
    ) -> LayoutDocument {
        generatedSky130MagicMetalAngleDocument(
            cellName: cellName,
            layer: LayoutLayerID(name: "MET5", purpose: "drawing"),
            points: points
        )
    }

    func generatedSky130MagicVIA4WidthDocument(
        cellName: String,
        cutSize: LayoutSize
    ) -> LayoutDocument {
        let metal4 = LayoutLayerID(name: "MET4", purpose: "drawing")
        let via4 = LayoutLayerID(name: "VIA4", purpose: "cut")
        let metal5 = LayoutLayerID(name: "MET5", purpose: "drawing")
        let lowerCoverRect = LayoutRect(
            origin: LayoutPoint(x: 0.00, y: 0.00),
            size: LayoutSize(width: 2.80, height: 2.80)
        )
        let upperCoverRect = LayoutRect(
            origin: LayoutPoint(x: 0.00, y: 0.00),
            size: LayoutSize(width: 2.80, height: 2.80)
        )
        let cutRect = LayoutRect(
            origin: LayoutPoint(x: 0.60, y: 0.60),
            size: cutSize
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(layer: metal4, geometry: .rect(lowerCoverRect)),
            LayoutShape(layer: via4, geometry: .rect(cutRect)),
            LayoutShape(layer: metal5, geometry: .rect(upperCoverRect)),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetalDocument(
        cellName: String,
        layer: LayoutLayerID,
        metalWidth: Double
    ) -> LayoutDocument {
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(
                layer: layer,
                geometry: .rect(LayoutRect(
                    origin: LayoutPoint(x: 0, y: 0),
                    size: LayoutSize(width: 2.0, height: metalWidth)
                ))
            ),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetalSpacingDocument(
        cellName: String,
        layer: LayoutLayerID,
        metalSpacing: Double,
        metalWidth: Double
    ) -> LayoutDocument {
        let firstMetal = LayoutRect(
            origin: LayoutPoint(x: 0, y: 0),
            size: LayoutSize(width: 2.0, height: metalWidth)
        )
        let secondMetal = LayoutRect(
            origin: LayoutPoint(x: 0, y: firstMetal.maxY + metalSpacing),
            size: LayoutSize(width: 2.0, height: metalWidth)
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [firstMetal, secondMetal].map { rect in
            LayoutShape(layer: layer, geometry: .rect(rect))
        }
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetalAreaDocument(
        cellName: String,
        layer: LayoutLayerID,
        metalSize: LayoutSize
    ) -> LayoutDocument {
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(
                layer: layer,
                geometry: .rect(LayoutRect(
                    origin: LayoutPoint(x: 0, y: 0),
                    size: metalSize
                ))
            ),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetalAngleDocument(
        cellName: String,
        layer: LayoutLayerID,
        points: [LayoutPoint]
    ) -> LayoutDocument {
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(
                layer: layer,
                geometry: .polygon(LayoutPolygon(points: points))
            ),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetalWideSpacingDocument(
        cellName: String,
        layer: LayoutLayerID,
        spacing: Double
    ) -> LayoutDocument {
        let wideMetal = LayoutRect(
            origin: LayoutPoint(x: 0, y: 0),
            size: LayoutSize(width: 3.20, height: 3.20)
        )
        let neighborMetal = LayoutRect(
            origin: LayoutPoint(x: 0, y: wideMetal.maxY + spacing),
            size: LayoutSize(width: 0.60, height: 0.60)
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [
            LayoutShape(layer: layer, geometry: .rect(wideMetal)),
            LayoutShape(layer: layer, geometry: .rect(neighborMetal)),
        ]
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

    func generatedSky130MagicMetalLargeAttachedSpacingDocument(
        cellName: String,
        layer: LayoutLayerID,
        fingerSpacing: Double
    ) -> LayoutDocument {
        let base = LayoutRect(
            origin: LayoutPoint(x: 0, y: 0),
            size: LayoutSize(width: 4.0, height: 4.0)
        )
        let firstFinger = LayoutRect(
            origin: LayoutPoint(x: 0, y: base.maxY),
            size: LayoutSize(width: 1.0, height: 1.0)
        )
        let secondFinger = LayoutRect(
            origin: LayoutPoint(x: firstFinger.maxX + fingerSpacing, y: base.maxY),
            size: LayoutSize(width: 1.0, height: 1.0)
        )
        var cell = LayoutCell(name: cellName)
        cell.shapes = [base, firstFinger, secondFinger].map { rect in
            LayoutShape(layer: layer, geometry: .rect(rect))
        }
        return LayoutDocument(name: cellName, cells: [cell], topCellID: cell.id)
    }

}
