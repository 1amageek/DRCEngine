import Foundation
import DRCCore

extension NativeDRCBackend {
    func evaluateMaximumAntennaRatio(
        rule: NativeDRCRule,
        conductorRectangles: [NativeDRCRectangle],
        allRectangles: [NativeDRCRectangle],
        unit: String
    ) throws -> [DRCDiagnostic] {
        guard rule.value.isFinite, rule.value > 0 else {
            throw DRCError.invalidInput("Rule \(rule.id) requires a positive finite antenna ratio threshold")
        }
        let conductorLayers = try antennaConductorLayers(for: rule)
        let layerDescription = conductorLayers.joined(separator: ",")
        try validateAntennaGateAreas(in: allRectangles)
        try validateAntennaProcessSteps(in: allRectangles)
        let processStep = try antennaProcessStep(for: rule)
        let cutConnections = try antennaCutConnections(for: rule)
        let stepScopedConductors = antennaConductors(
            conductorRectangles,
            matching: processStep
        )
        let conductorsByNet = Dictionary(grouping: stepScopedConductors.compactMap { rectangle in
            rectangle.netID.map { netID in (netID: netID, rectangle: rectangle) }
        }, by: \.netID)

        return conductorsByNet.compactMap { netID, entries in
            let netConductors = entries.map(\.rectangle)
            let gateRectangles = allRectangles.filter { rectangle in
                rectangle.netID == netID
                    && (rectangle.antennaGateArea ?? 0) > 0
                    && (rule.gateLayer == nil || rectangle.layer == rule.gateLayer)
            }
            let gateArea = gateRectangles.reduce(0) { partial, rectangle in
                partial + (rectangle.antennaGateArea ?? 0)
            }
            guard gateArea > 0 else {
                return nil
            }

            let connected = antennaConnectedConductors(
                netConductors,
                gateRectangles: gateRectangles,
                allRectangles: allRectangles,
                netID: netID,
                cutConnections: cutConnections
            )
            let conductors = connected.conductors
            guard !conductors.isEmpty else {
                return nil
            }

            let conductorArea = antennaConductorArea(of: conductors)
            let ratio = conductorArea / gateArea
            guard ratio > rule.value else {
                return nil
            }
            let region = conductors.map(\.region).dropFirst().reduce(conductors[0].region) { partial, region in
                partial.enclosing(region)
            }
            let relatedShapeIDs = conductors.map(\.id) + connected.cutRectangles.map(\.id) + gateRectangles.map(\.id)
            let stepMessage = processStep.map { " at process step \($0)" } ?? ""
            let stepRawLine = processStep.map { " step=\($0)" } ?? ""
            let cutLayerDescription = connectedCutLayerDescription(connected.cutRectangles)
            let cutMessage = cutLayerDescription.isEmpty ? "" : " through \(cutLayerDescription)"
            let cutRawLine = cutLayerDescription.isEmpty ? "" : " cuts=\(cutLayerDescription)"
            return DRCDiagnostic(
                severity: .error,
                message: "Net \(netID)\(stepMessage) across \(layerDescription)\(cutMessage) exceeds maximum antenna ratio \(rule.value)",
                ruleID: rule.id,
                count: 1,
                kind: "maximumAntennaRatio",
                layer: rule.layer,
                measured: ratio,
                required: rule.value,
                unit: "ratio",
                region: region,
                relatedShapeIDs: relatedShapeIDs,
                relatedViaIDs: connected.cutRectangles.map(\.id),
                relatedNetIDs: [netID],
                suggestedFix: "Reduce conductor area on net \(netID)\(stepMessage) across \(layerDescription)\(cutMessage), increase gate area, add antenna protection, or review the cut stack.",
                rawLine: "MAX_ANTENNA_RATIO\(stepRawLine) layers=\(layerDescription)\(cutRawLine) net=\(netID)"
            )
        }
    }

    private func antennaProcessStep(for rule: NativeDRCRule) throws -> String? {
        guard let processStep = rule.processStep else {
            return nil
        }
        guard !processStep.isEmpty else {
            throw DRCError.invalidInput("Rule \(rule.id) includes an empty processStep")
        }
        return processStep
    }

    private func antennaConductors(
        _ rectangles: [NativeDRCRectangle],
        matching processStep: String?
    ) -> [NativeDRCRectangle] {
        guard let processStep else {
            return rectangles
        }
        return rectangles.filter { $0.antennaProcessStep == processStep }
    }

    private func antennaConnectedConductors(
        _ conductors: [NativeDRCRectangle],
        gateRectangles: [NativeDRCRectangle],
        allRectangles: [NativeDRCRectangle],
        netID: String,
        cutConnections: [NativeDRCAntennaCutConnection]
    ) -> (conductors: [NativeDRCRectangle], cutRectangles: [NativeDRCRectangle]) {
        guard !cutConnections.isEmpty else {
            return (conductors, [])
        }
        var adjacency: [Int: Set<Int>] = [:]
        let nonCutRectangles = gateRectangles + conductors
        let cutLayerSet = Set(cutConnections.map(\.layer))
        let cutRectangles = allRectangles.filter { rectangle in
            rectangle.netID == netID && cutLayerSet.contains(rectangle.layer)
        }
        let cutNodeOffset = nonCutRectangles.count
        let rectanglesByLayer = Dictionary(
            grouping: allRectangles.filter { $0.netID == netID },
            by: \.layer
        )

        for firstIndex in nonCutRectangles.indices {
            for secondIndex in nonCutRectangles.indices where secondIndex > firstIndex {
                let first = nonCutRectangles[firstIndex]
                let second = nonCutRectangles[secondIndex]
                guard first.layer == second.layer, first.touches(second) else {
                    continue
                }
                adjacency[firstIndex, default: []].insert(secondIndex)
                adjacency[secondIndex, default: []].insert(firstIndex)
            }
        }

        for connection in cutConnections {
            let matchingCuts = rectanglesByLayer[connection.layer, default: []]
            for cut in matchingCuts {
                guard let cutIndex = cutRectangles.firstIndex(of: cut) else {
                    continue
                }
                let cutNodeIndex = cutNodeOffset + cutIndex
                let lowerIndices = nonCutRectangles.indices.filter { index in
                    nonCutRectangles[index].layer == connection.lowerLayer
                        && nonCutRectangles[index].overlaps(cut)
                }
                let upperIndices = nonCutRectangles.indices.filter { index in
                    nonCutRectangles[index].layer == connection.upperLayer
                        && nonCutRectangles[index].overlaps(cut)
                }
                guard !lowerIndices.isEmpty, !upperIndices.isEmpty else {
                    continue
                }
                for index in lowerIndices + upperIndices {
                    adjacency[index, default: []].insert(cutNodeIndex)
                    adjacency[cutNodeIndex, default: []].insert(index)
                }
            }
        }

        let gateNodeIndices = Set(gateRectangles.indices)
        let reachableNodeIndices = reachableAntennaNodes(from: gateNodeIndices, adjacency: adjacency)
        let connectedConductors = conductors.enumerated().compactMap { offset, conductor in
            let nodeIndex = gateRectangles.count + offset
            return reachableNodeIndices.contains(nodeIndex) ? conductor : nil
        }
        guard !connectedConductors.isEmpty else {
            return ([], [])
        }
        let connectedCutRectangles = cutRectangles.enumerated().compactMap { offset, cut in
            reachableNodeIndices.contains(cutNodeOffset + offset) ? cut : nil
        }
        return (connectedConductors, connectedCutRectangles)
    }

    private func reachableAntennaNodes(
        from sourceNodes: Set<Int>,
        adjacency: [Int: Set<Int>]
    ) -> Set<Int> {
        var visited = sourceNodes
        var frontier = Array(sourceNodes)
        while let node = frontier.popLast() {
            for nextNode in adjacency[node, default: []] where !visited.contains(nextNode) {
                visited.insert(nextNode)
                frontier.append(nextNode)
            }
        }
        return visited
    }

    private func antennaConductorArea(of conductors: [NativeDRCRectangle]) -> Double {
        let conductorsByLayer = Dictionary(grouping: conductors, by: \.layer)
        return conductorsByLayer.values.reduce(0) { partial, layerConductors in
            partial + unionArea(of: layerConductors.map(\.densityRectangle))
        }
    }

    private func connectedCutLayerDescription(_ cutRectangles: [NativeDRCRectangle]) -> String {
        var seenLayers = Set<String>()
        let layers = cutRectangles.compactMap { cut -> String? in
            guard seenLayers.insert(cut.layer).inserted else {
                return nil
            }
            return cut.layer
        }
        return layers.joined(separator: ",")
    }

    func antennaConductorLayers(for rule: NativeDRCRule) throws -> [String] {
        guard let configuredLayers = rule.conductorLayers else {
            return [rule.layer]
        }
        guard !configuredLayers.isEmpty else {
            throw DRCError.invalidInput("Rule \(rule.id) requires at least one conductor layer")
        }
        var layers: [String] = []
        var seenLayers = Set<String>()
        for layer in configuredLayers {
            guard !layer.isEmpty else {
                throw DRCError.invalidInput("Rule \(rule.id) includes an empty conductor layer")
            }
            if seenLayers.insert(layer).inserted {
                layers.append(layer)
            }
        }
        return layers
    }

    private func antennaCutConnections(for rule: NativeDRCRule) throws -> [NativeDRCAntennaCutConnection] {
        guard let configuredConnections = rule.antennaCutConnections else {
            return []
        }
        guard !configuredConnections.isEmpty else {
            throw DRCError.invalidInput("Rule \(rule.id) includes empty antennaCutConnections")
        }
        for connection in configuredConnections {
            guard !connection.layer.isEmpty else {
                throw DRCError.invalidInput("Rule \(rule.id) includes an empty antenna cut layer")
            }
            guard !connection.lowerLayer.isEmpty else {
                throw DRCError.invalidInput("Rule \(rule.id) includes an empty antenna cut lowerLayer")
            }
            guard !connection.upperLayer.isEmpty else {
                throw DRCError.invalidInput("Rule \(rule.id) includes an empty antenna cut upperLayer")
            }
            guard connection.lowerLayer != connection.upperLayer else {
                throw DRCError.invalidInput("Rule \(rule.id) includes an antenna cut connection with identical lowerLayer and upperLayer")
            }
        }
        return configuredConnections
    }

    private func validateAntennaGateAreas(in rectangles: [NativeDRCRectangle]) throws {
        for rectangle in rectangles {
            guard let gateArea = rectangle.antennaGateArea else {
                continue
            }
            guard gateArea.isFinite, gateArea >= 0 else {
                throw DRCError.invalidInput("Rectangle \(rectangle.id) has invalid antennaGateArea")
            }
            guard rectangle.netID != nil else {
                throw DRCError.invalidInput("Rectangle \(rectangle.id) with antennaGateArea requires netID")
            }
        }
    }

    private func validateAntennaProcessSteps(in rectangles: [NativeDRCRectangle]) throws {
        for rectangle in rectangles {
            guard let processStep = rectangle.antennaProcessStep else {
                continue
            }
            guard !processStep.isEmpty else {
                throw DRCError.invalidInput("Rectangle \(rectangle.id) includes an empty antennaProcessStep")
            }
        }
    }

}
