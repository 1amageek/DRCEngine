public struct DRCCorpusCoverageAuditPolicy: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let policyID: String
    public let requireQualifiedCorpus: Bool
    public let requireOracleAgreement: Bool
    public let requireOracleReadiness: Bool
    public let requireDurationBudget: Bool
    public let minimumCaseCount: Int
    public let requirements: [Requirement]

    public init(
        schemaVersion: Int = DRCCorpusCoverageAuditPolicy.currentSchemaVersion,
        policyID: String,
        requireQualifiedCorpus: Bool = true,
        requireOracleAgreement: Bool = true,
        requireOracleReadiness: Bool = true,
        requireDurationBudget: Bool = true,
        minimumCaseCount: Int = 1,
        requirements: [Requirement]
    ) {
        self.schemaVersion = schemaVersion
        self.policyID = policyID
        self.requireQualifiedCorpus = requireQualifiedCorpus
        self.requireOracleAgreement = requireOracleAgreement
        self.requireOracleReadiness = requireOracleReadiness
        self.requireDurationBudget = requireDurationBudget
        self.minimumCaseCount = max(0, minimumCaseCount)
        self.requirements = requirements.sorted { $0.requirementID < $1.requirementID }
    }

    public static var magicFoundryExpansion: DRCCorpusCoverageAuditPolicy {
        DRCCorpusCoverageAuditPolicy(
            policyID: "drc.magic-foundry-expansion.v1",
            minimumCaseCount: 4,
            requirements: [
                Requirement(
                    requirementID: "magic-oracle-baseline",
                    title: "Magic oracle baseline",
                    requiredCoverageTags: ["external.magic", "layout.gds"],
                    suggestedActions: ["retain_magic_external_oracle_lane"]
                ),
                Requirement(
                    requirementID: "magic-cut-count-oracle",
                    title: "Magic cut-count oracle coverage",
                    requiredCoverageTags: [
                        "drc.cut",
                        "drc.cut.minimum",
                        "drc.cut.minimum.external-oracle",
                        "external.magic",
                        "layout.gds",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_cut_count_cases"]
                ),
                Requirement(
                    requirementID: "magic-width-oracle",
                    title: "Magic width oracle coverage",
                    requiredCoverageTags: [
                        "drc.width",
                        "drc.width.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_width_cases"]
                ),
                Requirement(
                    requirementID: "magic-spacing-oracle",
                    title: "Magic spacing oracle coverage",
                    requiredCoverageTags: [
                        "drc.spacing",
                        "drc.spacing.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_spacing_cases"]
                ),
                Requirement(
                    requirementID: "magic-area-oracle",
                    title: "Magic area oracle coverage",
                    requiredCoverageTags: [
                        "drc.area",
                        "drc.area.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_area_cases"]
                ),
                Requirement(
                    requirementID: "magic-angle-oracle",
                    title: "Magic angle oracle coverage",
                    requiredCoverageTags: [
                        "drc.angle",
                        "drc.angle.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_angle_cases"]
                ),
                Requirement(
                    requirementID: "magic-wide-spacing-oracle",
                    title: "Magic wide-spacing oracle coverage",
                    requiredCoverageTags: [
                        "drc.spacing",
                        "drc.spacing.wide",
                        "drc.spacing.wide.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_wide_spacing_cases"]
                ),
                Requirement(
                    requirementID: "magic-large-attached-spacing-oracle",
                    title: "Magic large-attached spacing oracle coverage",
                    requiredCoverageTags: [
                        "drc.spacing",
                        "drc.spacing.large-attached",
                        "drc.spacing.large-attached.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_large_attached_spacing_cases"]
                ),
                Requirement(
                    requirementID: "magic-enclosure-oracle",
                    title: "Magic enclosure oracle coverage",
                    requiredCoverageTags: [
                        "drc.enclosure",
                        "drc.enclosure.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_enclosure_cases"]
                ),
                Requirement(
                    requirementID: "magic-contact-width-oracle",
                    title: "Magic contact width oracle coverage",
                    requiredCoverageTags: [
                        "drc.contact",
                        "drc.contact.mcon",
                        "drc.contact.width",
                        "drc.contact.width.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_contact_width_cases"]
                ),
                Requirement(
                    requirementID: "magic-contact-spacing-oracle",
                    title: "Magic contact spacing oracle coverage",
                    requiredCoverageTags: [
                        "drc.contact",
                        "drc.contact.mcon",
                        "drc.contact.spacing",
                        "drc.contact.spacing.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_contact_spacing_cases"]
                ),
                Requirement(
                    requirementID: "magic-via1-width-oracle",
                    title: "Magic VIA1 width oracle coverage",
                    requiredCoverageTags: [
                        "drc.contact",
                        "drc.contact.via1",
                        "drc.contact.width",
                        "drc.contact.width.via1",
                        "drc.contact.width.via1.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_via1_width_cases"]
                ),
                Requirement(
                    requirementID: "magic-via1-spacing-oracle",
                    title: "Magic VIA1 spacing oracle coverage",
                    requiredCoverageTags: [
                        "drc.contact",
                        "drc.contact.via1",
                        "drc.contact.spacing",
                        "drc.contact.spacing.via1",
                        "drc.contact.spacing.via1.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_via1_spacing_cases"]
                ),
                Requirement(
                    requirementID: "magic-via1-metal1-enclosure-oracle",
                    title: "Magic VIA1 Metal1 enclosure oracle coverage",
                    requiredCoverageTags: [
                        "drc.enclosure",
                        "drc.enclosure.external-oracle",
                        "drc.enclosure.via1",
                        "drc.enclosure.via1.met1",
                        "drc.enclosure.via1.met1.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_via1_metal1_enclosure_cases"]
                ),
                Requirement(
                    requirementID: "magic-via1-metal2-enclosure-oracle",
                    title: "Magic VIA1 Metal2 enclosure oracle coverage",
                    requiredCoverageTags: [
                        "drc.enclosure",
                        "drc.enclosure.external-oracle",
                        "drc.enclosure.via1",
                        "drc.enclosure.via1.met2",
                        "drc.enclosure.via1.met2.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_via1_metal2_enclosure_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal2-width-oracle",
                    title: "Magic Metal2 width oracle coverage",
                    requiredCoverageTags: [
                        "drc.width",
                        "drc.width.met2",
                        "drc.width.met2.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal2_width_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal2-spacing-oracle",
                    title: "Magic Metal2 spacing oracle coverage",
                    requiredCoverageTags: [
                        "drc.spacing",
                        "drc.spacing.met2",
                        "drc.spacing.met2.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal2_spacing_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal2-wide-spacing-oracle",
                    title: "Magic Metal2 wide-spacing oracle coverage",
                    requiredCoverageTags: [
                        "drc.spacing",
                        "drc.spacing.wide",
                        "drc.spacing.wide.met2",
                        "drc.spacing.wide.met2.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal2_wide_spacing_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal2-large-attached-spacing-oracle",
                    title: "Magic Metal2 large-attached spacing oracle coverage",
                    requiredCoverageTags: [
                        "drc.spacing",
                        "drc.spacing.large-attached",
                        "drc.spacing.large-attached.met2",
                        "drc.spacing.large-attached.met2.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal2_large_attached_spacing_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal2-area-oracle",
                    title: "Magic Metal2 area oracle coverage",
                    requiredCoverageTags: [
                        "drc.area",
                        "drc.area.met2",
                        "drc.area.met2.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal2_area_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal2-angle-oracle",
                    title: "Magic Metal2 angle oracle coverage",
                    requiredCoverageTags: [
                        "drc.angle",
                        "drc.angle.met2",
                        "drc.angle.met2.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal2_angle_cases"]
                ),
                Requirement(
                    requirementID: "magic-via2-width-oracle",
                    title: "Magic VIA2 width oracle coverage",
                    requiredCoverageTags: [
                        "drc.contact",
                        "drc.contact.via2",
                        "drc.contact.width",
                        "drc.contact.width.via2",
                        "drc.contact.width.via2.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_via2_width_cases"]
                ),
                Requirement(
                    requirementID: "magic-via2-metal2-enclosure-oracle",
                    title: "Magic VIA2 Metal2 enclosure oracle coverage",
                    requiredCoverageTags: [
                        "drc.enclosure",
                        "drc.enclosure.external-oracle",
                        "drc.enclosure.via2",
                        "drc.enclosure.via2.met2",
                        "drc.enclosure.via2.met2.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_via2_metal2_enclosure_cases"]
                ),
                Requirement(
                    requirementID: "magic-via2-metal3-enclosure-oracle",
                    title: "Magic VIA2 Metal3 enclosure oracle coverage",
                    requiredCoverageTags: [
                        "drc.enclosure",
                        "drc.enclosure.external-oracle",
                        "drc.enclosure.via2",
                        "drc.enclosure.via2.met3",
                        "drc.enclosure.via2.met3.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_via2_metal3_enclosure_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal3-width-oracle",
                    title: "Magic Metal3 width oracle coverage",
                    requiredCoverageTags: [
                        "drc.width",
                        "drc.width.met3",
                        "drc.width.met3.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal3_width_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal3-spacing-oracle",
                    title: "Magic Metal3 spacing oracle coverage",
                    requiredCoverageTags: [
                        "drc.spacing",
                        "drc.spacing.met3",
                        "drc.spacing.met3.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal3_spacing_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal3-wide-spacing-oracle",
                    title: "Magic Metal3 wide-spacing oracle coverage",
                    requiredCoverageTags: [
                        "drc.spacing",
                        "drc.spacing.wide",
                        "drc.spacing.wide.met3",
                        "drc.spacing.wide.met3.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal3_wide_spacing_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal3-large-attached-spacing-oracle",
                    title: "Magic Metal3 large-attached spacing oracle coverage",
                    requiredCoverageTags: [
                        "drc.spacing",
                        "drc.spacing.large-attached",
                        "drc.spacing.large-attached.met3",
                        "drc.spacing.large-attached.met3.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal3_large_attached_spacing_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal3-area-oracle",
                    title: "Magic Metal3 area oracle coverage",
                    requiredCoverageTags: [
                        "drc.area",
                        "drc.area.met3",
                        "drc.area.met3.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal3_area_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal3-angle-oracle",
                    title: "Magic Metal3 angle oracle coverage",
                    requiredCoverageTags: [
                        "drc.angle",
                        "drc.angle.met3",
                        "drc.angle.met3.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal3_angle_cases"]
                ),
                Requirement(
                    requirementID: "magic-via3-width-oracle",
                    title: "Magic VIA3 width oracle coverage",
                    requiredCoverageTags: [
                        "drc.contact",
                        "drc.contact.via3",
                        "drc.contact.width",
                        "drc.contact.width.via3",
                        "drc.contact.width.via3.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_via3_width_cases"]
                ),
                Requirement(
                    requirementID: "magic-via3-metal3-enclosure-oracle",
                    title: "Magic VIA3 Metal3 enclosure oracle coverage",
                    requiredCoverageTags: [
                        "drc.enclosure",
                        "drc.enclosure.external-oracle",
                        "drc.enclosure.via3",
                        "drc.enclosure.via3.met3",
                        "drc.enclosure.via3.met3.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_via3_metal3_enclosure_cases"]
                ),
                Requirement(
                    requirementID: "magic-via3-metal4-enclosure-oracle",
                    title: "Magic VIA3 Metal4 enclosure oracle coverage",
                    requiredCoverageTags: [
                        "drc.enclosure",
                        "drc.enclosure.external-oracle",
                        "drc.enclosure.via3",
                        "drc.enclosure.via3.met4",
                        "drc.enclosure.via3.met4.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_via3_metal4_enclosure_cases"]
                ),
                Requirement(
                    requirementID: "magic-via4-width-oracle",
                    title: "Magic VIA4 width oracle coverage",
                    requiredCoverageTags: [
                        "drc.contact",
                        "drc.contact.via4",
                        "drc.contact.width",
                        "drc.contact.width.via4",
                        "drc.contact.width.via4.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_via4_width_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal4-width-oracle",
                    title: "Magic Metal4 width oracle coverage",
                    requiredCoverageTags: [
                        "drc.width",
                        "drc.width.met4",
                        "drc.width.met4.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal4_width_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal4-spacing-oracle",
                    title: "Magic Metal4 spacing oracle coverage",
                    requiredCoverageTags: [
                        "drc.spacing",
                        "drc.spacing.met4",
                        "drc.spacing.met4.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal4_spacing_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal4-wide-spacing-oracle",
                    title: "Magic Metal4 wide-spacing oracle coverage",
                    requiredCoverageTags: [
                        "drc.spacing",
                        "drc.spacing.wide",
                        "drc.spacing.wide.met4",
                        "drc.spacing.wide.met4.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal4_wide_spacing_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal4-large-attached-spacing-oracle",
                    title: "Magic Metal4 large-attached spacing oracle coverage",
                    requiredCoverageTags: [
                        "drc.spacing",
                        "drc.spacing.large-attached",
                        "drc.spacing.large-attached.met4",
                        "drc.spacing.large-attached.met4.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal4_large_attached_spacing_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal4-area-oracle",
                    title: "Magic Metal4 area oracle coverage",
                    requiredCoverageTags: [
                        "drc.area",
                        "drc.area.met4",
                        "drc.area.met4.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal4_area_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal4-angle-oracle",
                    title: "Magic Metal4 angle oracle coverage",
                    requiredCoverageTags: [
                        "drc.angle",
                        "drc.angle.met4",
                        "drc.angle.met4.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal4_angle_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal5-width-oracle",
                    title: "Magic Metal5 width oracle coverage",
                    requiredCoverageTags: [
                        "drc.width",
                        "drc.width.met5",
                        "drc.width.met5.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal5_width_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal5-spacing-oracle",
                    title: "Magic Metal5 spacing oracle coverage",
                    requiredCoverageTags: [
                        "drc.spacing",
                        "drc.spacing.met5",
                        "drc.spacing.met5.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal5_spacing_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal5-area-oracle",
                    title: "Magic Metal5 area oracle coverage",
                    requiredCoverageTags: [
                        "drc.area",
                        "drc.area.met5",
                        "drc.area.met5.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal5_area_cases"]
                ),
                Requirement(
                    requirementID: "magic-metal5-angle-oracle",
                    title: "Magic Metal5 angle oracle coverage",
                    requiredCoverageTags: [
                        "drc.angle",
                        "drc.angle.met5",
                        "drc.angle.met5.external-oracle",
                        "external.magic",
                        "layout.gds",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_metal5_angle_cases"]
                ),
                Requirement(
                    requirementID: "sky130-standard-layout-oracle",
                    title: "Sky130 standard layout oracle coverage",
                    requiredCoverageTags: ["external.magic", "layout.gds", "sky130"],
                    suggestedActions: ["retain_sky130_magic_gds_cases"]
                ),
                Requirement(
                    requirementID: "native-gds-standard-input",
                    title: "Native GDS standard-input coverage",
                    requiredCoverageTags: ["drc.input.gds", "drc.tech.layer-map"],
                    suggestedActions: ["retain_native_gds_standard_input_cases"]
                ),
            ]
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case policyID
        case requireQualifiedCorpus
        case requireOracleAgreement
        case requireOracleReadiness
        case requireDurationBudget
        case minimumCaseCount
        case requirements
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? DRCCorpusCoverageAuditPolicy.currentSchemaVersion
        policyID = try container.decode(String.self, forKey: .policyID)
        requireQualifiedCorpus = try container.decodeIfPresent(Bool.self, forKey: .requireQualifiedCorpus) ?? true
        requireOracleAgreement = try container.decodeIfPresent(Bool.self, forKey: .requireOracleAgreement) ?? true
        requireOracleReadiness = try container.decodeIfPresent(Bool.self, forKey: .requireOracleReadiness) ?? true
        requireDurationBudget = try container.decodeIfPresent(Bool.self, forKey: .requireDurationBudget) ?? true
        minimumCaseCount = max(0, try container.decodeIfPresent(Int.self, forKey: .minimumCaseCount) ?? 1)
        requirements = try container.decodeIfPresent([Requirement].self, forKey: .requirements) ?? []
    }

    public struct Requirement: Sendable, Hashable, Codable {
        public let requirementID: String
        public let title: String
        public let requiredCoverageTags: [String]
        public let minimumCaseCount: Int
        public let suggestedActions: [String]

        public init(
            requirementID: String,
            title: String,
            requiredCoverageTags: [String],
            minimumCaseCount: Int = 1,
            suggestedActions: [String] = []
        ) {
            self.requirementID = requirementID
            self.title = title
            self.requiredCoverageTags = Self.normalized(requiredCoverageTags)
            self.minimumCaseCount = max(1, minimumCaseCount)
            self.suggestedActions = Self.normalized(suggestedActions)
        }

        private enum CodingKeys: String, CodingKey {
            case requirementID
            case title
            case requiredCoverageTags
            case minimumCaseCount
            case suggestedActions
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            requirementID = try container.decode(String.self, forKey: .requirementID)
            title = try container.decode(String.self, forKey: .title)
            requiredCoverageTags = Self.normalized(try container.decodeIfPresent(
                [String].self,
                forKey: .requiredCoverageTags
            ) ?? [])
            minimumCaseCount = max(1, try container.decodeIfPresent(Int.self, forKey: .minimumCaseCount) ?? 1)
            suggestedActions = Self.normalized(try container.decodeIfPresent(
                [String].self,
                forKey: .suggestedActions
            ) ?? [])
        }

        private static func normalized(_ values: [String]) -> [String] {
            Array(Set(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }))
                .sorted()
        }
    }
}
