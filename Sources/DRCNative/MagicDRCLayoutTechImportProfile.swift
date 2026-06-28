import Foundation

public struct MagicDRCLayoutTechImportProfile: Codable, Sendable, Hashable {
    public let schemaVersion: Int
    public let profileID: String
    public let displayName: String?
    public let layerOrder: [String]
    public let cutLayerNames: [String]
    public let layerPurposes: [String: String]
    public let layerDisplayNames: [String: String]
    public let layerColors: [String: MagicDRCLayoutTechLayerColor]
    public let layerFillPatterns: [String: String]
    public let layerPreferredDirections: [String: String]
    public let baseLayerNames: [String]
    public let planeBaseLayerNames: [String: String]
    public let typeAliasBaseLayerNames: [String: [String: String]]
    public let canonicalLayerAliases: [String: [String]]
    public let layerSetAliases: [String: [String]]
    public let derivedLayerSeeds: [MagicDRCLayoutTechDerivedLayerSeed]
    public let cutStackConnections: [MagicDRCLayoutTechCutStackConnection]

    public init(
        schemaVersion: Int = 1,
        profileID: String,
        displayName: String? = nil,
        layerOrder: [String] = [],
        cutLayerNames: [String] = [],
        layerPurposes: [String: String] = [:],
        layerDisplayNames: [String: String] = [:],
        layerColors: [String: MagicDRCLayoutTechLayerColor] = [:],
        layerFillPatterns: [String: String] = [:],
        layerPreferredDirections: [String: String] = [:],
        baseLayerNames: [String] = [],
        planeBaseLayerNames: [String: String] = [:],
        typeAliasBaseLayerNames: [String: [String: String]] = [:],
        canonicalLayerAliases: [String: [String]] = [:],
        layerSetAliases: [String: [String]] = [:],
        derivedLayerSeeds: [MagicDRCLayoutTechDerivedLayerSeed] = [],
        cutStackConnections: [MagicDRCLayoutTechCutStackConnection] = []
    ) {
        self.schemaVersion = schemaVersion
        self.profileID = profileID
        self.displayName = displayName
        self.layerOrder = layerOrder
        self.cutLayerNames = cutLayerNames
        self.layerPurposes = layerPurposes
        self.layerDisplayNames = layerDisplayNames
        self.layerColors = layerColors
        self.layerFillPatterns = layerFillPatterns
        self.layerPreferredDirections = layerPreferredDirections
        self.baseLayerNames = baseLayerNames
        self.planeBaseLayerNames = planeBaseLayerNames
        self.typeAliasBaseLayerNames = typeAliasBaseLayerNames
        self.canonicalLayerAliases = canonicalLayerAliases
        self.layerSetAliases = layerSetAliases
        self.derivedLayerSeeds = derivedLayerSeeds
        self.cutStackConnections = cutStackConnections
    }

    public static func load(from url: URL) throws -> MagicDRCLayoutTechImportProfile {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(MagicDRCLayoutTechImportProfile.self, from: data)
    }

    public static func bundledMagicLayoutTechProfile(
        resourceName: String
    ) throws -> MagicDRCLayoutTechImportProfile {
        let url = try bundledMagicLayoutTechProfileURL(resourceName: resourceName)
        return try load(from: url)
    }

    public static func bundledMagicLayoutTechProfileURL(
        resourceName: String
    ) throws -> URL {
        guard let url = Bundle.module.url(
            forResource: resourceName,
            withExtension: "json",
            subdirectory: "Resources"
        ) else {
            throw MagicDRCLayoutTechImportProfileError.missingBundledProfile(
                "\(resourceName).json"
            )
        }
        return url
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case profileID
        case displayName
        case layerOrder
        case cutLayerNames
        case layerPurposes
        case layerDisplayNames
        case layerColors
        case layerFillPatterns
        case layerPreferredDirections
        case baseLayerNames
        case planeBaseLayerNames
        case typeAliasBaseLayerNames
        case canonicalLayerAliases
        case layerSetAliases
        case derivedLayerSeeds
        case cutStackConnections
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1,
            profileID: try container.decode(String.self, forKey: .profileID),
            displayName: try container.decodeIfPresent(String.self, forKey: .displayName),
            layerOrder: try container.decodeIfPresent([String].self, forKey: .layerOrder) ?? [],
            cutLayerNames: try container.decodeIfPresent([String].self, forKey: .cutLayerNames) ?? [],
            layerPurposes: try container.decodeIfPresent([String: String].self, forKey: .layerPurposes) ?? [:],
            layerDisplayNames: try container.decodeIfPresent([String: String].self, forKey: .layerDisplayNames) ?? [:],
            layerColors: try container.decodeIfPresent(
                [String: MagicDRCLayoutTechLayerColor].self,
                forKey: .layerColors
            ) ?? [:],
            layerFillPatterns: try container.decodeIfPresent([String: String].self, forKey: .layerFillPatterns) ?? [:],
            layerPreferredDirections: try container.decodeIfPresent(
                [String: String].self,
                forKey: .layerPreferredDirections
            ) ?? [:],
            baseLayerNames: try container.decodeIfPresent([String].self, forKey: .baseLayerNames) ?? [],
            planeBaseLayerNames: try container.decodeIfPresent(
                [String: String].self,
                forKey: .planeBaseLayerNames
            ) ?? [:],
            typeAliasBaseLayerNames: try container.decodeIfPresent(
                [String: [String: String]].self,
                forKey: .typeAliasBaseLayerNames
            ) ?? [:],
            canonicalLayerAliases: try container.decodeIfPresent(
                [String: [String]].self,
                forKey: .canonicalLayerAliases
            ) ?? [:],
            layerSetAliases: try container.decodeIfPresent([String: [String]].self, forKey: .layerSetAliases) ?? [:],
            derivedLayerSeeds: try container.decodeIfPresent(
                [MagicDRCLayoutTechDerivedLayerSeed].self,
                forKey: .derivedLayerSeeds
            ) ?? [],
            cutStackConnections: try container.decodeIfPresent(
                [MagicDRCLayoutTechCutStackConnection].self,
                forKey: .cutStackConnections
            ) ?? []
        )
    }
}

public enum MagicDRCLayoutTechImportProfileError: Error, LocalizedError, Sendable, Hashable {
    case missingBundledProfile(String)

    public var errorDescription: String? {
        switch self {
        case .missingBundledProfile(let name):
            return "Missing bundled Magic DRC LayoutTech import profile: \(name)"
        }
    }
}

public struct MagicDRCLayoutTechLayerColor: Codable, Sendable, Hashable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

public struct MagicDRCLayoutTechDerivedLayerSeed: Codable, Sendable, Hashable {
    public let id: String
    public let targetLayerName: String
    public let sourceLayerNames: [String]
    public let operation: String

    public init(
        id: String,
        targetLayerName: String,
        sourceLayerNames: [String],
        operation: String = "intersection"
    ) {
        self.id = id
        self.targetLayerName = targetLayerName
        self.sourceLayerNames = sourceLayerNames
        self.operation = operation
    }
}

public struct MagicDRCLayoutTechCutStackConnection: Codable, Sendable, Hashable {
    public let id: String
    public let cutLayerName: String
    public let bottomLayerName: String
    public let topLayerName: String
    public let kind: String
    public let minimumCutCount: Int?

    public init(
        id: String,
        cutLayerName: String,
        bottomLayerName: String,
        topLayerName: String,
        kind: String,
        minimumCutCount: Int? = nil
    ) {
        self.id = id
        self.cutLayerName = cutLayerName
        self.bottomLayerName = bottomLayerName
        self.topLayerName = topLayerName
        self.kind = kind
        self.minimumCutCount = minimumCutCount
    }
}
