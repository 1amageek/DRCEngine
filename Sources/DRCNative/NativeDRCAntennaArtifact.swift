import Foundation
import DRCFoundryImport

/// Provenance-bound native antenna rules produced from a Magic source deck.
///
/// The executable rules alone are not a qualification artifact: without the
/// source/profile digests and process connectivity context, a consumer cannot
/// tell which foundry deck produced them. This envelope keeps those inputs and
/// the lowering verdict together while still exposing `nativeRules` for a
/// NativeDRC layout.
public struct NativeDRCAntennaArtifact: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public enum ValidationError: Error, LocalizedError, Sendable, Hashable {
        case unsupportedSchemaVersion(Int)
        case missingSourcePath
        case missingSourceDigest
        case invalidSourceDigest
        case missingProfileID
        case missingProfileDigest
        case invalidProfileDigest
        case emptyProcessLayerOrder
        case duplicateProcessLayer(String)
        case emptySourceRules
        case emptyNativeRules
        case duplicateSourceRuleID(String)
        case duplicateNativeRuleID(String)
        case sourceRuleUnmaterialized(String)
        case nativeRuleDigestMismatch
        case qualificationDigestMismatch
        case qualificationCountMismatch
        case qualificationInconsistent
        case sourceContactStackUnmaterialized(String)
        case invalidThickness(String)
        case cumulativeLayerOutOfOrder(String)

        public var errorDescription: String? {
            switch self {
            case .unsupportedSchemaVersion(let version):
                return "Unsupported native antenna artifact schema version: \(version)."
            case .missingSourcePath:
                return "Native antenna artifact sourcePath must not be empty."
            case .missingSourceDigest:
                return "Native antenna artifact sourceDigest is missing."
            case .invalidSourceDigest:
                return "Native antenna artifact sourceDigest is not a SHA-256 digest."
            case .missingProfileID:
                return "Native antenna artifact profileID must not be empty."
            case .missingProfileDigest:
                return "Native antenna artifact profileDigest is missing."
            case .invalidProfileDigest:
                return "Native antenna artifact profileDigest is not a SHA-256 digest."
            case .emptyProcessLayerOrder:
                return "Native antenna artifact process layer order must not be empty."
            case .duplicateProcessLayer(let layer):
                return "Native antenna artifact process layer order repeats \(layer)."
            case .emptySourceRules:
                return "Native antenna artifact contains no source antenna rules."
            case .emptyNativeRules:
                return "Native antenna artifact contains no native antenna rules."
            case .duplicateSourceRuleID(let id):
                return "Native antenna artifact repeats source antenna rule \(id)."
            case .duplicateNativeRuleID(let id):
                return "Native antenna artifact repeats native antenna rule \(id)."
            case .sourceRuleUnmaterialized(let id):
                return "Native antenna artifact did not materialize source antenna rule \(id)."
            case .nativeRuleDigestMismatch:
                return "Native antenna artifact native rule digest does not match its rules."
            case .qualificationDigestMismatch:
                return "Native antenna artifact qualification digest does not match its provenance."
            case .qualificationCountMismatch:
                return "Native antenna artifact qualification counts do not match its contents."
            case .qualificationInconsistent:
                return "Native antenna artifact qualification status, failure codes, and oracle evidence disagree."
            case .sourceContactStackUnmaterialized(let id):
                return "Native antenna artifact did not materialize source contact stack \(id)."
            case .invalidThickness(let layer):
                return "Native antenna artifact has invalid thickness for \(layer)."
            case .cumulativeLayerOutOfOrder(let layer):
                return "Native antenna artifact cumulative antenna layer \(layer) is out of process order."
            }
        }
    }

    public let schemaVersion: Int
    public let sourcePath: String
    public let sourceDigest: String?
    public let profileID: String?
    public let profileDigest: String?
    public let processLayerOrder: [String]
    public let sourceContactStacks: [MagicDRCSourceContactStack]
    public let sourceAntennaRules: [MagicDRCSourceAntennaRule]
    public let sourceAntennaThicknesses: [String: Double]
    public let nativeRules: [NativeDRCRule]
    public let qualification: NativeDRCAntennaQualification

    public init(
        sourceReport: MagicDRCLayoutTechImportReport,
        nativeRules: [NativeDRCRule],
        oracleEvidence: NativeDRCAntennaOracleEvidence? = nil
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.sourcePath = sourceReport.sourcePath
        self.sourceDigest = sourceReport.sourceDigest
        self.profileID = sourceReport.profileID
        self.profileDigest = sourceReport.profileDigest
        self.processLayerOrder = sourceReport.profileLayerOrder
        self.sourceContactStacks = sourceReport.sourceContactStacks
        self.sourceAntennaRules = sourceReport.sourceAntennaRules
        self.sourceAntennaThicknesses = sourceReport.sourceAntennaThicknesses
        self.nativeRules = nativeRules
        self.qualification = NativeDRCAntennaQualification(
            sourceReport: sourceReport,
            nativeRules: nativeRules,
            oracleEvidence: oracleEvidence
        )
    }

    /// Returns a new artifact with the Oracle comparison evidence attached.
    /// The original artifact remains immutable and can be retained as the
    /// pre-qualification record.
    public func applying(
        oracleEvidence: NativeDRCAntennaOracleEvidence
    ) -> NativeDRCAntennaArtifact {
        NativeDRCAntennaArtifact(
            schemaVersion: schemaVersion,
            sourcePath: sourcePath,
            sourceDigest: sourceDigest,
            profileID: profileID,
            profileDigest: profileDigest,
            processLayerOrder: processLayerOrder,
            sourceContactStacks: sourceContactStacks,
            sourceAntennaRules: sourceAntennaRules,
            sourceAntennaThicknesses: sourceAntennaThicknesses,
            nativeRules: nativeRules,
            qualification: qualification.applying(oracleEvidence: oracleEvidence)
        )
    }

    private init(
        schemaVersion: Int,
        sourcePath: String,
        sourceDigest: String?,
        profileID: String?,
        profileDigest: String?,
        processLayerOrder: [String],
        sourceContactStacks: [MagicDRCSourceContactStack],
        sourceAntennaRules: [MagicDRCSourceAntennaRule],
        sourceAntennaThicknesses: [String: Double],
        nativeRules: [NativeDRCRule],
        qualification: NativeDRCAntennaQualification
    ) {
        self.schemaVersion = schemaVersion
        self.sourcePath = sourcePath
        self.sourceDigest = sourceDigest
        self.profileID = profileID
        self.profileDigest = profileDigest
        self.processLayerOrder = processLayerOrder
        self.sourceContactStacks = sourceContactStacks
        self.sourceAntennaRules = sourceAntennaRules
        self.sourceAntennaThicknesses = sourceAntennaThicknesses
        self.nativeRules = nativeRules
        self.qualification = qualification
    }

    /// Validates that the envelope still describes the exact rule lowering it
    /// claims to describe. This is intentionally independent of oracle status:
    /// a structurally sound artifact may remain blocked until an oracle agrees.
    public func validate() throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw ValidationError.unsupportedSchemaVersion(schemaVersion)
        }
        guard !sourcePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingSourcePath
        }
        guard let sourceDigest, !sourceDigest.isEmpty else {
            throw ValidationError.missingSourceDigest
        }
        guard Self.isSHA256Digest(sourceDigest) else {
            throw ValidationError.invalidSourceDigest
        }
        guard let profileID,
              !profileID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingProfileID
        }
        guard let profileDigest, !profileDigest.isEmpty else {
            throw ValidationError.missingProfileDigest
        }
        guard Self.isSHA256Digest(profileDigest) else {
            throw ValidationError.invalidProfileDigest
        }
        guard !processLayerOrder.isEmpty else {
            throw ValidationError.emptyProcessLayerOrder
        }
        guard !sourceAntennaRules.isEmpty else {
            throw ValidationError.emptySourceRules
        }
        guard !nativeRules.isEmpty else {
            throw ValidationError.emptyNativeRules
        }

        var sourceIDs = Set<String>()
        for sourceRule in sourceAntennaRules {
            guard sourceIDs.insert(sourceRule.id).inserted else {
                throw ValidationError.duplicateSourceRuleID(sourceRule.id)
            }
        }
        var nativeIDs = Set<String>()
        for nativeRule in nativeRules {
            guard nativeIDs.insert(nativeRule.id).inserted else {
                throw ValidationError.duplicateNativeRuleID(nativeRule.id)
            }
            try Self.validate(nativeAntennaRule: nativeRule)
        }
        for sourceRule in sourceAntennaRules where !nativeRules.contains(where: {
            $0.id.hasPrefix("antenna.\(sourceRule.id).")
        }) {
            throw ValidationError.sourceRuleUnmaterialized(sourceRule.id)
        }

        guard qualification.sourceDigest == sourceDigest,
              qualification.profileDigest == profileDigest else {
            throw ValidationError.qualificationDigestMismatch
        }
        guard qualification.sourceRuleCount == sourceAntennaRules.count,
              qualification.nativeRuleCount == nativeRules.count else {
            throw ValidationError.qualificationCountMismatch
        }
        guard qualification.nativeRuleDigest == NativeDRCAntennaQualification.nativeRuleDigest(nativeRules) else {
            throw ValidationError.nativeRuleDigestMismatch
        }
        guard (qualification.qualified && qualification.failureCodes.isEmpty)
                || (!qualification.qualified && !qualification.failureCodes.isEmpty) else {
            throw ValidationError.qualificationInconsistent
        }
        if let oracleEvidence = qualification.oracleEvidence {
            guard oracleEvidence.sourceDigest == sourceDigest,
                  oracleEvidence.profileDigest == profileDigest,
                  oracleEvidence.nativeRuleDigest == qualification.nativeRuleDigest else {
                throw ValidationError.qualificationDigestMismatch
            }
            try oracleEvidence.validate()
        }

        var processIndexes: [String: Int] = [:]
        for (index, layer) in processLayerOrder.enumerated() {
            let normalizedLayer = layer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedLayer.isEmpty else {
                throw ValidationError.emptyProcessLayerOrder
            }
            guard processIndexes[normalizedLayer] == nil else {
                throw ValidationError.duplicateProcessLayer(normalizedLayer)
            }
            processIndexes[normalizedLayer] = index
        }
        for (layer, thickness) in sourceAntennaThicknesses {
            guard thickness.isFinite, thickness > 0 else {
                throw ValidationError.invalidThickness(layer)
            }
        }

        for nativeRule in nativeRules where nativeRule.antennaModel == .cumulative {
            guard let antennaLayers = nativeRule.antennaLayers else { continue }
            var previousIndex = -1
            for antennaLayer in antennaLayers {
                guard let index = processIndexes[antennaLayer.layer], index > previousIndex else {
                    throw ValidationError.cumulativeLayerOutOfOrder(antennaLayer.layer)
                }
                previousIndex = index
            }
        }

        let expectedConnections = Set(sourceContactStacks.map {
            NativeDRCAntennaCutConnection(
                layer: $0.cutLayerName,
                lowerLayer: $0.bottomLayerName,
                upperLayer: $0.topLayerName
            )
        })
        let materializedConnections = Set(nativeRules.flatMap { $0.antennaCutConnections ?? [] })
        for stack in expectedConnections where !materializedConnections.contains(stack) {
            throw ValidationError.sourceContactStackUnmaterialized(stack.layer)
        }
    }

    private static func isSHA256Digest(_ value: String) -> Bool {
        value.count == 64
            && value.unicodeScalars.allSatisfy {
                CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains($0)
            }
    }

    private static func validate(nativeAntennaRule rule: NativeDRCRule) throws {
        guard rule.kind == .maximumAntennaRatio else {
            return
        }
        guard rule.value.isFinite, rule.value > 0 else {
            throw ValidationError.qualificationInconsistent
        }
        if let processStep = rule.processStep,
           processStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.qualificationInconsistent
        }
        guard let antennaLayers = rule.antennaLayers, !antennaLayers.isEmpty else {
            // Legacy maximum-ratio rules are valid without detailed layer
            // semantics; the native backend validates their scalar value.
            guard rule.antennaModel == nil else {
                throw ValidationError.qualificationInconsistent
            }
            return
        }
        guard let stage = antennaLayers.first(where: { $0.layer == rule.layer }) else {
            throw ValidationError.qualificationInconsistent
        }
        guard antennaLayers.allSatisfy({ layer in
            !layer.layer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && layer.ratioGate.isFinite
                && layer.ratioGate > 0
                && (layer.measurement != .sidewall
                    || (layer.thickness?.isFinite == true && (layer.thickness ?? 0) > 0))
                && (layer.diffusionRatioConstant?.isFinite ?? true)
                && (layer.diffusionRatioPerArea?.isFinite ?? true)
        }) else {
            throw ValidationError.qualificationInconsistent
        }
        guard stage.measurement == .surface || stage.thickness != nil else {
            throw ValidationError.qualificationInconsistent
        }
    }
}
