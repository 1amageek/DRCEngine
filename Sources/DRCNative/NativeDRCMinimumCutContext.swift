import Foundation
import DRCCore

struct NativeDRCMinimumCutContext: Sendable {
    let rule: NativeDRCRule
    let requiredCutCount: Int
    let lowerLayer: String
    let upperLayer: String
    private let lowerRectangles: [NativeDRCRectangle]
    private let upperRectangles: [NativeDRCRectangle]
    private let cutRectangles: [NativeDRCRectangle]

    init(
        rule: NativeDRCRule,
        cutRectangles: [NativeDRCRectangle],
        rectanglesByLayer: [String: [NativeDRCRectangle]]
    ) throws {
        self.rule = rule
        self.requiredCutCount = try Self.requiredCutCount(for: rule)
        self.lowerLayer = try Self.requiredLayer(rule.lowerLayer, name: "lowerLayer", ruleID: rule.id)
        self.upperLayer = try Self.requiredLayer(rule.upperLayer, name: "upperLayer", ruleID: rule.id)
        guard lowerLayer != upperLayer else {
            throw DRCError.invalidInput("Rule \(rule.id) requires distinct lowerLayer and upperLayer")
        }
        self.lowerRectangles = rectanglesByLayer[lowerLayer, default: []]
        self.upperRectangles = rectanglesByLayer[upperLayer, default: []]
        self.cutRectangles = cutRectangles
    }

    func violations() -> [NativeDRCMinimumCutViolation] {
        guard !lowerRectangles.isEmpty, !upperRectangles.isEmpty else {
            return []
        }
        var violations: [NativeDRCMinimumCutViolation] = []
        for lower in lowerRectangles {
            for upper in upperRectangles where Self.conductorPairCanBeEvaluated(lower: lower, upper: upper) {
                let connectingCuts = connectingCuts(between: lower, and: upper)
                guard connectingCuts.count < requiredCutCount else {
                    continue
                }
                violations.append(NativeDRCMinimumCutViolation(
                    lower: lower,
                    upper: upper,
                    connectingCuts: connectingCuts
                ))
            }
        }
        return violations
    }

    private func connectingCuts(
        between lower: NativeDRCRectangle,
        and upper: NativeDRCRectangle
    ) -> [NativeDRCRectangle] {
        cutRectangles.filter { cut in
            Self.cutCanConnect(cut: cut, lower: lower, upper: upper)
        }
    }

    private static func conductorPairCanBeEvaluated(
        lower: NativeDRCRectangle,
        upper: NativeDRCRectangle
    ) -> Bool {
        lower.overlaps(upper) && compatibleConductorNets(lower.netID, upper.netID)
    }

    private static func cutCanConnect(
        cut: NativeDRCRectangle,
        lower: NativeDRCRectangle,
        upper: NativeDRCRectangle
    ) -> Bool {
        cut.overlaps(lower)
            && cut.overlaps(upper)
            && cutNetIsCompatible(cut.netID, lower.netID, upper.netID)
    }

    private static func compatibleConductorNets(_ lowerNetID: String?, _ upperNetID: String?) -> Bool {
        guard let lowerNetID, let upperNetID else {
            return true
        }
        return lowerNetID == upperNetID
    }

    private static func cutNetIsCompatible(
        _ cutNetID: String?,
        _ lowerNetID: String?,
        _ upperNetID: String?
    ) -> Bool {
        guard let cutNetID else {
            return true
        }
        if let lowerNetID, cutNetID != lowerNetID {
            return false
        }
        if let upperNetID, cutNetID != upperNetID {
            return false
        }
        return true
    }

    private static func requiredLayer(_ value: String?, name: String, ruleID: String) throws -> String {
        guard let value, !value.isEmpty else {
            throw DRCError.invalidInput("Rule \(ruleID) requires \(name) for minimumCut")
        }
        return value
    }

    private static func requiredCutCount(for rule: NativeDRCRule) throws -> Int {
        guard rule.value.isFinite,
              rule.value >= 1,
              rule.value.rounded(.towardZero) == rule.value else {
            throw DRCError.invalidInput("Rule \(rule.id) requires a positive integer minimum cut count")
        }
        return Int(rule.value)
    }
}

struct NativeDRCMinimumCutViolation: Sendable {
    let lower: NativeDRCRectangle
    let upper: NativeDRCRectangle
    let connectingCuts: [NativeDRCRectangle]

    var relatedShapeIDs: [String] {
        relatedRectangles.map(\.id)
    }

    var relatedViaIDs: [String] {
        connectingCuts.map(\.id)
    }

    var relatedNetIDs: [String] {
        Array(Set(relatedRectangles.compactMap(\.netID))).sorted()
    }

    var region: DRCRegion {
        relatedRectangles
            .map(\.region)
            .reduce(lower.region.enclosing(upper.region)) { partial, region in
                partial.enclosing(region)
            }
    }

    var netDescription: String {
        conductorNetID.map { "Net \($0)" } ?? "Geometry"
    }

    var fixSubject: String {
        conductorNetID.map { "net \($0)" } ?? "the unlabeled \(lower.layer)/\(upper.layer) overlap"
    }

    var rawNetValue: String {
        conductorNetID ?? "unlabeled"
    }

    private var relatedRectangles: [NativeDRCRectangle] {
        [lower, upper] + connectingCuts
    }

    private var conductorNetID: String? {
        if lower.netID == upper.netID {
            return lower.netID
        }
        return lower.netID ?? upper.netID
    }
}
