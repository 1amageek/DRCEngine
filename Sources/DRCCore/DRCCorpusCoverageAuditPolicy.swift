public struct DRCCorpusCoverageAuditPolicy: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 2

    public let schemaVersion: Int
    public let policyID: String
    public let requirePassingAssessment: Bool
    public let requireOracleAgreement: Bool
    public let requireIndependentOracle: Bool
    public let requireOracleReadiness: Bool
    public let requireDurationBudget: Bool
    public let minimumCaseCount: Int
    public let maxReportAgeSeconds: Double?
    public let requirements: [Requirement]

    public enum ValidationError: Error, Sendable, Hashable {
        case emptyPolicyID
        case invalidMinimumCaseCount(Int)
        case invalidMaxReportAgeSeconds(Double)
        case emptyRequirements
        case duplicateRequirementID(String)
        case invalidRequirement(index: Int, error: Requirement.ValidationError)

        public var message: String {
            switch self {
            case .emptyPolicyID:
                return "policyID must not be empty."
            case .invalidMinimumCaseCount(let value):
                return "minimumCaseCount must be one or greater; received \(value)."
            case .invalidMaxReportAgeSeconds(let value):
                return "maxReportAgeSeconds must be finite and zero or greater; received \(value)."
            case .emptyRequirements:
                return "At least one coverage requirement is required."
            case .duplicateRequirementID(let requirementID):
                return "Coverage requirement identifier \(requirementID) is duplicated."
            case .invalidRequirement(let index, let error):
                return "Coverage requirement at index \(index) is invalid: \(error.message)"
            }
        }
    }

    public init(
        policyID: String,
        requirePassingAssessment: Bool = true,
        requireOracleAgreement: Bool = true,
        requireIndependentOracle: Bool = false,
        requireOracleReadiness: Bool = true,
        requireDurationBudget: Bool = true,
        minimumCaseCount: Int = 1,
        maxReportAgeSeconds: Double? = nil,
        requirements: [Requirement]
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.policyID = policyID
        self.requirePassingAssessment = requirePassingAssessment
        self.requireOracleAgreement = requireOracleAgreement
        self.requireIndependentOracle = requireIndependentOracle
        self.requireOracleReadiness = requireOracleReadiness
        self.requireDurationBudget = requireDurationBudget
        self.minimumCaseCount = minimumCaseCount
        self.maxReportAgeSeconds = maxReportAgeSeconds
        self.requirements = requirements.sorted { $0.requirementID < $1.requirementID }
    }

    public var validationErrors: [ValidationError] {
        var errors: [ValidationError] = []
        if policyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyPolicyID)
        }
        if minimumCaseCount < 1 {
            errors.append(.invalidMinimumCaseCount(minimumCaseCount))
        }
        if let maxReportAgeSeconds,
           !maxReportAgeSeconds.isFinite || maxReportAgeSeconds < 0 {
            errors.append(.invalidMaxReportAgeSeconds(maxReportAgeSeconds))
        }
        if requirements.isEmpty {
            errors.append(.emptyRequirements)
        }
        let groupedRequirementIDs = Dictionary(grouping: requirements, by: \.requirementID)
        for requirementID in groupedRequirementIDs.keys.sorted()
        where groupedRequirementIDs[requirementID, default: []].count > 1 {
            errors.append(.duplicateRequirementID(requirementID))
        }
        for (index, requirement) in requirements.enumerated() {
            errors.append(contentsOf: requirement.validationErrors.map {
                .invalidRequirement(index: index, error: $0)
            })
        }
        return errors
    }

    public static var magicFoundryExpansion: DRCCorpusCoverageAuditPolicy {
        DRCCorpusCoverageAuditPolicy(
            policyID: "drc.magic-foundry-expansion.v2",
            requireIndependentOracle: true,
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
                    requirementID: "magic-via2-spacing-oracle",
                    title: "Magic VIA2 spacing oracle coverage",
                    requiredCoverageTags: [
                        "drc.contact",
                        "drc.contact.spacing",
                        "drc.contact.spacing.via2",
                        "drc.contact.spacing.via2.external-oracle",
                        "drc.contact.via2",
                        "external.magic",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_via2_spacing_cases"]
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
                    requirementID: "magic-via3-spacing-oracle",
                    title: "Magic VIA3 spacing oracle coverage",
                    requiredCoverageTags: [
                        "drc.contact",
                        "drc.contact.spacing",
                        "drc.contact.spacing.via3",
                        "drc.contact.spacing.via3.external-oracle",
                        "drc.contact.via3",
                        "external.magic",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_via3_spacing_cases"]
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
                    requirementID: "magic-via4-spacing-oracle",
                    title: "Magic VIA4 spacing oracle coverage",
                    requiredCoverageTags: [
                        "drc.contact",
                        "drc.contact.spacing",
                        "drc.contact.spacing.external-oracle",
                        "drc.contact.spacing.via4",
                        "drc.contact.spacing.via4.external-oracle",
                        "drc.contact.via4",
                        "external.magic",
                        "layout.magic",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_via4_spacing_cases"]
                ),
                Requirement(
                    requirementID: "magic-via4-metal5-enclosure-oracle",
                    title: "Magic VIA4 Metal5 enclosure oracle coverage",
                    requiredCoverageTags: [
                        "drc.enclosure",
                        "drc.enclosure.external-oracle",
                        "drc.enclosure.via4",
                        "drc.enclosure.via4.met5",
                        "drc.enclosure.via4.met5.external-oracle",
                        "external.magic",
                        "layout.magic",
                        "sky130",
                    ],
                    minimumCaseCount: 2,
                    suggestedActions: ["add_magic_readable_via4_metal5_enclosure_cases"]
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
        case requirePassingAssessment
        case requireOracleAgreement
        case requireIndependentOracle
        case requireOracleReadiness
        case requireDurationBudget
        case minimumCaseCount
        case maxReportAgeSeconds
        case requirements
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported DRC corpus coverage audit policy schema version: \(schemaVersion)."
            )
        }
        policyID = try container.decode(String.self, forKey: .policyID)
        requirePassingAssessment = try container.decode(Bool.self, forKey: .requirePassingAssessment)
        requireOracleAgreement = try container.decode(Bool.self, forKey: .requireOracleAgreement)
        requireIndependentOracle = try container.decode(Bool.self, forKey: .requireIndependentOracle)
        requireOracleReadiness = try container.decode(Bool.self, forKey: .requireOracleReadiness)
        requireDurationBudget = try container.decode(Bool.self, forKey: .requireDurationBudget)
        minimumCaseCount = try container.decode(Int.self, forKey: .minimumCaseCount)
        guard minimumCaseCount >= 1 else {
            throw DecodingError.dataCorruptedError(
                forKey: .minimumCaseCount,
                in: container,
                debugDescription: "minimumCaseCount must be one or greater."
            )
        }
        guard container.contains(.maxReportAgeSeconds) else {
            throw DecodingError.keyNotFound(
                CodingKeys.maxReportAgeSeconds,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "maxReportAgeSeconds must be explicitly declared."
                )
            )
        }
        let decodedMaxReportAgeSeconds = try container.decodeIfPresent(
            Double.self,
            forKey: .maxReportAgeSeconds
        )
        if let decodedMaxReportAgeSeconds {
            guard decodedMaxReportAgeSeconds.isFinite, decodedMaxReportAgeSeconds >= 0 else {
                throw DecodingError.dataCorruptedError(
                    forKey: .maxReportAgeSeconds,
                    in: container,
                    debugDescription: "maxReportAgeSeconds must be finite and zero or greater."
                )
            }
            maxReportAgeSeconds = decodedMaxReportAgeSeconds
        } else {
            maxReportAgeSeconds = nil
        }
        requirements = try container.decode([Requirement].self, forKey: .requirements)
        guard !policyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .policyID,
                in: container,
                debugDescription: "policyID must not be empty."
            )
        }
        guard !requirements.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .requirements,
                in: container,
                debugDescription: "At least one coverage requirement is required."
            )
        }
        let requirementIDs = requirements.map(\.requirementID)
        guard Set(requirementIDs).count == requirementIDs.count else {
            throw DecodingError.dataCorruptedError(
                forKey: .requirements,
                in: container,
                debugDescription: "Coverage requirement identifiers must be unique."
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        let errors = validationErrors
        guard errors.isEmpty else {
            throw EncodingError.invalidValue(
                self,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: errors.map(\.message).joined(separator: " ")
                )
            )
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(policyID, forKey: .policyID)
        try container.encode(requirePassingAssessment, forKey: .requirePassingAssessment)
        try container.encode(requireOracleAgreement, forKey: .requireOracleAgreement)
        try container.encode(requireIndependentOracle, forKey: .requireIndependentOracle)
        try container.encode(requireOracleReadiness, forKey: .requireOracleReadiness)
        try container.encode(requireDurationBudget, forKey: .requireDurationBudget)
        try container.encode(minimumCaseCount, forKey: .minimumCaseCount)
        try container.encode(maxReportAgeSeconds, forKey: .maxReportAgeSeconds)
        try container.encode(requirements, forKey: .requirements)
    }

    public struct Requirement: Sendable, Hashable, Codable {
        public let requirementID: String
        public let title: String
        public let requiredCoverageTags: [String]
        public let minimumCaseCount: Int
        public let suggestedActions: [String]

        public enum ValidationError: Error, Sendable, Hashable {
            case emptyRequirementID
            case emptyTitle
            case emptyRequiredCoverageTags
            case invalidMinimumCaseCount(Int)

            public var message: String {
                switch self {
                case .emptyRequirementID:
                    return "requirementID must not be empty."
                case .emptyTitle:
                    return "title must not be empty."
                case .emptyRequiredCoverageTags:
                    return "requiredCoverageTags must not be empty."
                case .invalidMinimumCaseCount(let value):
                    return "minimumCaseCount must be one or greater; received \(value)."
                }
            }
        }

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
            self.minimumCaseCount = minimumCaseCount
            self.suggestedActions = Self.normalized(suggestedActions)
        }

        public var validationErrors: [ValidationError] {
            var errors: [ValidationError] = []
            if requirementID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyRequirementID)
            }
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyTitle)
            }
            if requiredCoverageTags.isEmpty {
                errors.append(.emptyRequiredCoverageTags)
            }
            if minimumCaseCount < 1 {
                errors.append(.invalidMinimumCaseCount(minimumCaseCount))
            }
            return errors
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
            requiredCoverageTags = Self.normalized(try container.decode(
                [String].self,
                forKey: .requiredCoverageTags
            ))
            minimumCaseCount = try container.decode(Int.self, forKey: .minimumCaseCount)
            guard minimumCaseCount >= 1 else {
                throw DecodingError.dataCorruptedError(
                    forKey: .minimumCaseCount,
                    in: container,
                    debugDescription: "Requirement minimumCaseCount must be one or greater."
                )
            }
            suggestedActions = Self.normalized(try container.decode(
                [String].self,
                forKey: .suggestedActions
            ))
            guard !requirementID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .requirementID,
                    in: container,
                    debugDescription: "requirementID must not be empty."
                )
            }
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .title,
                    in: container,
                    debugDescription: "Coverage requirement title must not be empty."
                )
            }
            guard !requiredCoverageTags.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .requiredCoverageTags,
                    in: container,
                    debugDescription: "At least one required coverage tag is required."
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            let errors = validationErrors
            guard errors.isEmpty else {
                throw EncodingError.invalidValue(
                    self,
                    EncodingError.Context(
                        codingPath: encoder.codingPath,
                        debugDescription: errors.map(\.message).joined(separator: " ")
                    )
                )
            }
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(requirementID, forKey: .requirementID)
            try container.encode(title, forKey: .title)
            try container.encode(requiredCoverageTags, forKey: .requiredCoverageTags)
            try container.encode(minimumCaseCount, forKey: .minimumCaseCount)
            try container.encode(suggestedActions, forKey: .suggestedActions)
        }

        private static func normalized(_ values: [String]) -> [String] {
            Array(Set(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }))
                .sorted()
        }
    }
}
