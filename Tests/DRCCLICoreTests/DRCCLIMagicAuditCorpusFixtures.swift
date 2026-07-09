import Foundation
import Testing
import DRCCore
import DRCCLICore
import DRCNative
import LayoutCore
import LayoutTech


extension DRCCLIOptionsTests {
    func magicFoundryAuditCorpusReport() -> DRCCorpusReport {
        let summary = DRCDiagnosticSummary(infoCount: 0, warningCount: 0, errorCount: 0)
        let baseline = passingAuditCaseResult(
            caseID: "sky130-magic-baseline",
            coverageTags: ["external.magic", "layout.gds", "sky130"],
            oracleBackendID: "magic",
            summary: summary
        )
        let cutViolation = passingAuditCaseResult(
            caseID: "sky130-magic-cut-count-violation",
            coverageTags: [
                "drc.cut",
                "drc.cut.minimum",
                "drc.cut.minimum.external-oracle",
                "drc.cut.minimum.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let cutClean = passingAuditCaseResult(
            caseID: "sky130-magic-cut-count-clean",
            coverageTags: [
                "drc.cut",
                "drc.cut.minimum",
                "drc.cut.minimum.external-oracle",
                "drc.cut.minimum.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let widthViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met1-width-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.width",
                "drc.width.external-oracle",
                "drc.width.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let widthClean = passingAuditCaseResult(
            caseID: "sky130-magic-met1-width-clean",
            coverageTags: [
                "drc.width",
                "drc.width.external-oracle",
                "drc.width.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let spacingViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met1-spacing-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.spacing",
                "drc.spacing.external-oracle",
                "drc.spacing.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let spacingClean = passingAuditCaseResult(
            caseID: "sky130-magic-met1-spacing-clean",
            coverageTags: [
                "drc.spacing",
                "drc.spacing.external-oracle",
                "drc.spacing.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let areaViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met1-area-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.area",
                "drc.area.external-oracle",
                "drc.area.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let areaClean = passingAuditCaseResult(
            caseID: "sky130-magic-met1-area-clean",
            coverageTags: [
                "drc.area",
                "drc.area.external-oracle",
                "drc.area.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let angleViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met1-angle-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.angle",
                "drc.angle.external-oracle",
                "drc.angle.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let angleClean = passingAuditCaseResult(
            caseID: "sky130-magic-met1-angle-clean",
            coverageTags: [
                "drc.angle",
                "drc.angle.external-oracle",
                "drc.angle.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let wideSpacingViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met1-wide-spacing-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.spacing",
                "drc.spacing.wide",
                "drc.spacing.wide.external-oracle",
                "drc.spacing.wide.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let wideSpacingClean = passingAuditCaseResult(
            caseID: "sky130-magic-met1-wide-spacing-clean",
            coverageTags: [
                "drc.spacing",
                "drc.spacing.wide",
                "drc.spacing.wide.external-oracle",
                "drc.spacing.wide.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let largeAttachedSpacingViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met1-large-attached-spacing-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.spacing",
                "drc.spacing.large-attached",
                "drc.spacing.large-attached.external-oracle",
                "drc.spacing.large-attached.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let largeAttachedSpacingClean = passingAuditCaseResult(
            caseID: "sky130-magic-met1-large-attached-spacing-clean",
            coverageTags: [
                "drc.spacing",
                "drc.spacing.large-attached",
                "drc.spacing.large-attached.external-oracle",
                "drc.spacing.large-attached.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let enclosureViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met1-mcon-enclosure-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.enclosure",
                "drc.enclosure.external-oracle",
                "drc.enclosure.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let enclosureClean = passingAuditCaseResult(
            caseID: "sky130-magic-met1-mcon-enclosure-clean",
            coverageTags: [
                "drc.enclosure",
                "drc.enclosure.external-oracle",
                "drc.enclosure.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let contactWidthViolation = passingAuditCaseResult(
            caseID: "sky130-magic-mcon-width-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.contact",
                "drc.contact.mcon",
                "drc.contact.width",
                "drc.contact.width.external-oracle",
                "drc.contact.width.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let contactWidthClean = passingAuditCaseResult(
            caseID: "sky130-magic-mcon-width-clean",
            coverageTags: [
                "drc.contact",
                "drc.contact.mcon",
                "drc.contact.width",
                "drc.contact.width.external-oracle",
                "drc.contact.width.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let contactSpacingViolation = passingAuditCaseResult(
            caseID: "sky130-magic-mcon-spacing-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.contact",
                "drc.contact.mcon",
                "drc.contact.spacing",
                "drc.contact.spacing.external-oracle",
                "drc.contact.spacing.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let contactSpacingClean = passingAuditCaseResult(
            caseID: "sky130-magic-mcon-spacing-clean",
            coverageTags: [
                "drc.contact",
                "drc.contact.mcon",
                "drc.contact.spacing",
                "drc.contact.spacing.external-oracle",
                "drc.contact.spacing.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via1WidthViolation = passingAuditCaseResult(
            caseID: "sky130-magic-via1-width-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.contact",
                "drc.contact.via1",
                "drc.contact.width",
                "drc.contact.width.via1",
                "drc.contact.width.via1.external-oracle",
                "drc.contact.width.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via1WidthClean = passingAuditCaseResult(
            caseID: "sky130-magic-via1-width-clean",
            coverageTags: [
                "drc.contact",
                "drc.contact.via1",
                "drc.contact.width",
                "drc.contact.width.via1",
                "drc.contact.width.via1.external-oracle",
                "drc.contact.width.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via1SpacingViolation = passingAuditCaseResult(
            caseID: "sky130-magic-via1-spacing-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.contact",
                "drc.contact.via1",
                "drc.contact.spacing",
                "drc.contact.spacing.via1",
                "drc.contact.spacing.via1.external-oracle",
                "drc.contact.spacing.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via1SpacingClean = passingAuditCaseResult(
            caseID: "sky130-magic-via1-spacing-clean",
            coverageTags: [
                "drc.contact",
                "drc.contact.via1",
                "drc.contact.spacing",
                "drc.contact.spacing.via1",
                "drc.contact.spacing.via1.external-oracle",
                "drc.contact.spacing.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via1Metal1EnclosureViolation = passingAuditCaseResult(
            caseID: "sky130-magic-via1-met1-enclosure-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.enclosure",
                "drc.enclosure.external-oracle",
                "drc.enclosure.via1",
                "drc.enclosure.via1.met1",
                "drc.enclosure.via1.met1.external-oracle",
                "drc.enclosure.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via1Metal1EnclosureClean = passingAuditCaseResult(
            caseID: "sky130-magic-via1-met1-enclosure-clean",
            coverageTags: [
                "drc.enclosure",
                "drc.enclosure.external-oracle",
                "drc.enclosure.via1",
                "drc.enclosure.via1.met1",
                "drc.enclosure.via1.met1.external-oracle",
                "drc.enclosure.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via1Metal2EnclosureViolation = passingAuditCaseResult(
            caseID: "sky130-magic-via1-met2-enclosure-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.enclosure",
                "drc.enclosure.external-oracle",
                "drc.enclosure.via1",
                "drc.enclosure.via1.met2",
                "drc.enclosure.via1.met2.external-oracle",
                "drc.enclosure.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via1Metal2EnclosureClean = passingAuditCaseResult(
            caseID: "sky130-magic-via1-met2-enclosure-clean",
            coverageTags: [
                "drc.enclosure",
                "drc.enclosure.external-oracle",
                "drc.enclosure.via1",
                "drc.enclosure.via1.met2",
                "drc.enclosure.via1.met2.external-oracle",
                "drc.enclosure.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal2WidthViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met2-width-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.width",
                "drc.width.met2",
                "drc.width.met2.external-oracle",
                "drc.width.met2.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal2WidthClean = passingAuditCaseResult(
            caseID: "sky130-magic-met2-width-clean",
            coverageTags: [
                "drc.width",
                "drc.width.met2",
                "drc.width.met2.external-oracle",
                "drc.width.met2.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal2SpacingViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met2-spacing-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.spacing",
                "drc.spacing.met2",
                "drc.spacing.met2.external-oracle",
                "drc.spacing.met2.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal2SpacingClean = passingAuditCaseResult(
            caseID: "sky130-magic-met2-spacing-clean",
            coverageTags: [
                "drc.spacing",
                "drc.spacing.met2",
                "drc.spacing.met2.external-oracle",
                "drc.spacing.met2.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal2AreaViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met2-area-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.area",
                "drc.area.met2",
                "drc.area.met2.external-oracle",
                "drc.area.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal2AreaClean = passingAuditCaseResult(
            caseID: "sky130-magic-met2-area-clean",
            coverageTags: [
                "drc.area",
                "drc.area.met2",
                "drc.area.met2.external-oracle",
                "drc.area.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal2AngleViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met2-angle-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.angle",
                "drc.angle.met2",
                "drc.angle.met2.external-oracle",
                "drc.angle.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal2AngleClean = passingAuditCaseResult(
            caseID: "sky130-magic-met2-angle-clean",
            coverageTags: [
                "drc.angle",
                "drc.angle.met2",
                "drc.angle.met2.external-oracle",
                "drc.angle.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal2WideSpacingViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met2-wide-spacing-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.spacing",
                "drc.spacing.wide",
                "drc.spacing.wide.met2",
                "drc.spacing.wide.met2.external-oracle",
                "drc.spacing.wide.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal2WideSpacingClean = passingAuditCaseResult(
            caseID: "sky130-magic-met2-wide-spacing-clean",
            coverageTags: [
                "drc.spacing",
                "drc.spacing.wide",
                "drc.spacing.wide.met2",
                "drc.spacing.wide.met2.external-oracle",
                "drc.spacing.wide.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal2LargeAttachedSpacingViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met2-large-attached-spacing-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.spacing",
                "drc.spacing.large-attached",
                "drc.spacing.large-attached.met2",
                "drc.spacing.large-attached.met2.external-oracle",
                "drc.spacing.large-attached.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal2LargeAttachedSpacingClean = passingAuditCaseResult(
            caseID: "sky130-magic-met2-large-attached-spacing-clean",
            coverageTags: [
                "drc.spacing",
                "drc.spacing.large-attached",
                "drc.spacing.large-attached.met2",
                "drc.spacing.large-attached.met2.external-oracle",
                "drc.spacing.large-attached.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via2WidthViolation = passingAuditCaseResult(
            caseID: "sky130-magic-via2-width-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.contact",
                "drc.contact.via2",
                "drc.contact.width",
                "drc.contact.width.via2",
                "drc.contact.width.via2.external-oracle",
                "drc.contact.width.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via2WidthClean = passingAuditCaseResult(
            caseID: "sky130-magic-via2-width-clean",
            coverageTags: [
                "drc.contact",
                "drc.contact.via2",
                "drc.contact.width",
                "drc.contact.width.via2",
                "drc.contact.width.via2.external-oracle",
                "drc.contact.width.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via2SpacingClean = passingAuditCaseResult(
            caseID: "sky130-magic-via2-spacing-clean",
            coverageTags: [
                "drc.contact",
                "drc.contact.via2",
                "drc.contact.spacing",
                "drc.contact.spacing.via2",
                "drc.contact.spacing.via2.external-oracle",
                "drc.contact.spacing.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via2SpacingViolation = passingAuditCaseResult(
            caseID: "sky130-magic-via2-spacing-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.contact",
                "drc.contact.spacing",
                "drc.contact.spacing.external-oracle",
                "drc.contact.spacing.fail",
                "drc.contact.spacing.via2",
                "drc.contact.spacing.via2.external-oracle",
                "drc.contact.via2",
                "external.magic",
                "layout.magic",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via2Metal2EnclosureViolation = passingAuditCaseResult(
            caseID: "sky130-magic-via2-met2-enclosure-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.enclosure",
                "drc.enclosure.external-oracle",
                "drc.enclosure.via2",
                "drc.enclosure.via2.met2",
                "drc.enclosure.via2.met2.external-oracle",
                "drc.enclosure.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via2Metal2EnclosureClean = passingAuditCaseResult(
            caseID: "sky130-magic-via2-met2-enclosure-clean",
            coverageTags: [
                "drc.enclosure",
                "drc.enclosure.external-oracle",
                "drc.enclosure.via2",
                "drc.enclosure.via2.met2",
                "drc.enclosure.via2.met2.external-oracle",
                "drc.enclosure.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via2Metal3EnclosureViolation = passingAuditCaseResult(
            caseID: "sky130-magic-via2-met3-enclosure-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.enclosure",
                "drc.enclosure.external-oracle",
                "drc.enclosure.via2",
                "drc.enclosure.via2.met3",
                "drc.enclosure.via2.met3.external-oracle",
                "drc.enclosure.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via2Metal3EnclosureClean = passingAuditCaseResult(
            caseID: "sky130-magic-via2-met3-enclosure-clean",
            coverageTags: [
                "drc.enclosure",
                "drc.enclosure.external-oracle",
                "drc.enclosure.via2",
                "drc.enclosure.via2.met3",
                "drc.enclosure.via2.met3.external-oracle",
                "drc.enclosure.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal3WidthViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met3-width-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.width",
                "drc.width.met3",
                "drc.width.met3.external-oracle",
                "drc.width.met3.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal3WidthClean = passingAuditCaseResult(
            caseID: "sky130-magic-met3-width-clean",
            coverageTags: [
                "drc.width",
                "drc.width.met3",
                "drc.width.met3.external-oracle",
                "drc.width.met3.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal3SpacingViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met3-spacing-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.spacing",
                "drc.spacing.met3",
                "drc.spacing.met3.external-oracle",
                "drc.spacing.met3.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal3SpacingClean = passingAuditCaseResult(
            caseID: "sky130-magic-met3-spacing-clean",
            coverageTags: [
                "drc.spacing",
                "drc.spacing.met3",
                "drc.spacing.met3.external-oracle",
                "drc.spacing.met3.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal3AreaViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met3-area-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.area",
                "drc.area.met3",
                "drc.area.met3.external-oracle",
                "drc.area.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal3AreaClean = passingAuditCaseResult(
            caseID: "sky130-magic-met3-area-clean",
            coverageTags: [
                "drc.area",
                "drc.area.met3",
                "drc.area.met3.external-oracle",
                "drc.area.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal3AngleViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met3-angle-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.angle",
                "drc.angle.met3",
                "drc.angle.met3.external-oracle",
                "drc.angle.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal3AngleClean = passingAuditCaseResult(
            caseID: "sky130-magic-met3-angle-clean",
            coverageTags: [
                "drc.angle",
                "drc.angle.met3",
                "drc.angle.met3.external-oracle",
                "drc.angle.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal3WideSpacingViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met3-wide-spacing-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.spacing",
                "drc.spacing.wide",
                "drc.spacing.wide.met3",
                "drc.spacing.wide.met3.external-oracle",
                "drc.spacing.wide.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal3WideSpacingClean = passingAuditCaseResult(
            caseID: "sky130-magic-met3-wide-spacing-clean",
            coverageTags: [
                "drc.spacing",
                "drc.spacing.wide",
                "drc.spacing.wide.met3",
                "drc.spacing.wide.met3.external-oracle",
                "drc.spacing.wide.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal3LargeAttachedSpacingViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met3-large-attached-spacing-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.spacing",
                "drc.spacing.large-attached",
                "drc.spacing.large-attached.met3",
                "drc.spacing.large-attached.met3.external-oracle",
                "drc.spacing.large-attached.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal3LargeAttachedSpacingClean = passingAuditCaseResult(
            caseID: "sky130-magic-met3-large-attached-spacing-clean",
            coverageTags: [
                "drc.spacing",
                "drc.spacing.large-attached",
                "drc.spacing.large-attached.met3",
                "drc.spacing.large-attached.met3.external-oracle",
                "drc.spacing.large-attached.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via3WidthViolation = passingAuditCaseResult(
            caseID: "sky130-magic-via3-width-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.contact",
                "drc.contact.via3",
                "drc.contact.width",
                "drc.contact.width.via3",
                "drc.contact.width.via3.external-oracle",
                "drc.contact.width.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via3WidthClean = passingAuditCaseResult(
            caseID: "sky130-magic-via3-width-clean",
            coverageTags: [
                "drc.contact",
                "drc.contact.via3",
                "drc.contact.width",
                "drc.contact.width.via3",
                "drc.contact.width.via3.external-oracle",
                "drc.contact.width.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via3SpacingClean = passingAuditCaseResult(
            caseID: "sky130-magic-via3-spacing-clean",
            coverageTags: [
                "drc.contact",
                "drc.contact.via3",
                "drc.contact.spacing",
                "drc.contact.spacing.via3",
                "drc.contact.spacing.via3.external-oracle",
                "drc.contact.spacing.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via3SpacingViolation = passingAuditCaseResult(
            caseID: "sky130-magic-via3-spacing-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.contact",
                "drc.contact.spacing",
                "drc.contact.spacing.external-oracle",
                "drc.contact.spacing.fail",
                "drc.contact.spacing.via3",
                "drc.contact.spacing.via3.external-oracle",
                "drc.contact.via3",
                "external.magic",
                "layout.magic",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via3Metal3EnclosureViolation = passingAuditCaseResult(
            caseID: "sky130-magic-via3-met3-enclosure-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.enclosure",
                "drc.enclosure.external-oracle",
                "drc.enclosure.via3",
                "drc.enclosure.via3.met3",
                "drc.enclosure.via3.met3.external-oracle",
                "drc.enclosure.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via3Metal3EnclosureClean = passingAuditCaseResult(
            caseID: "sky130-magic-via3-met3-enclosure-clean",
            coverageTags: [
                "drc.enclosure",
                "drc.enclosure.external-oracle",
                "drc.enclosure.via3",
                "drc.enclosure.via3.met3",
                "drc.enclosure.via3.met3.external-oracle",
                "drc.enclosure.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via3Metal4EnclosureViolation = passingAuditCaseResult(
            caseID: "sky130-magic-via3-met4-enclosure-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.enclosure",
                "drc.enclosure.external-oracle",
                "drc.enclosure.via3",
                "drc.enclosure.via3.met4",
                "drc.enclosure.via3.met4.external-oracle",
                "drc.enclosure.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via3Metal4EnclosureClean = passingAuditCaseResult(
            caseID: "sky130-magic-via3-met4-enclosure-clean",
            coverageTags: [
                "drc.enclosure",
                "drc.enclosure.external-oracle",
                "drc.enclosure.via3",
                "drc.enclosure.via3.met4",
                "drc.enclosure.via3.met4.external-oracle",
                "drc.enclosure.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal4WidthViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met4-width-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.width",
                "drc.width.met4",
                "drc.width.met4.external-oracle",
                "drc.width.met4.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal4WidthClean = passingAuditCaseResult(
            caseID: "sky130-magic-met4-width-clean",
            coverageTags: [
                "drc.width",
                "drc.width.met4",
                "drc.width.met4.external-oracle",
                "drc.width.met4.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal4SpacingViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met4-spacing-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.spacing",
                "drc.spacing.met4",
                "drc.spacing.met4.external-oracle",
                "drc.spacing.met4.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal4SpacingClean = passingAuditCaseResult(
            caseID: "sky130-magic-met4-spacing-clean",
            coverageTags: [
                "drc.spacing",
                "drc.spacing.met4",
                "drc.spacing.met4.external-oracle",
                "drc.spacing.met4.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal4AreaViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met4-area-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.area",
                "drc.area.met4",
                "drc.area.met4.external-oracle",
                "drc.area.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal4AreaClean = passingAuditCaseResult(
            caseID: "sky130-magic-met4-area-clean",
            coverageTags: [
                "drc.area",
                "drc.area.met4",
                "drc.area.met4.external-oracle",
                "drc.area.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal4AngleViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met4-angle-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.angle",
                "drc.angle.met4",
                "drc.angle.met4.external-oracle",
                "drc.angle.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal4AngleClean = passingAuditCaseResult(
            caseID: "sky130-magic-met4-angle-clean",
            coverageTags: [
                "drc.angle",
                "drc.angle.met4",
                "drc.angle.met4.external-oracle",
                "drc.angle.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal4WideSpacingViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met4-wide-spacing-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.spacing",
                "drc.spacing.wide",
                "drc.spacing.wide.met4",
                "drc.spacing.wide.met4.external-oracle",
                "drc.spacing.wide.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal4WideSpacingClean = passingAuditCaseResult(
            caseID: "sky130-magic-met4-wide-spacing-clean",
            coverageTags: [
                "drc.spacing",
                "drc.spacing.wide",
                "drc.spacing.wide.met4",
                "drc.spacing.wide.met4.external-oracle",
                "drc.spacing.wide.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal4LargeAttachedSpacingViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met4-large-attached-spacing-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.spacing",
                "drc.spacing.large-attached",
                "drc.spacing.large-attached.met4",
                "drc.spacing.large-attached.met4.external-oracle",
                "drc.spacing.large-attached.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal4LargeAttachedSpacingClean = passingAuditCaseResult(
            caseID: "sky130-magic-met4-large-attached-spacing-clean",
            coverageTags: [
                "drc.spacing",
                "drc.spacing.large-attached",
                "drc.spacing.large-attached.met4",
                "drc.spacing.large-attached.met4.external-oracle",
                "drc.spacing.large-attached.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via4WidthViolation = passingAuditCaseResult(
            caseID: "sky130-magic-via4-width-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.contact",
                "drc.contact.via4",
                "drc.contact.width",
                "drc.contact.width.fail",
                "drc.contact.width.via4",
                "drc.contact.width.via4.external-oracle",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via4WidthClean = passingAuditCaseResult(
            caseID: "sky130-magic-via4-width-clean",
            coverageTags: [
                "drc.contact",
                "drc.contact.via4",
                "drc.contact.width",
                "drc.contact.width.pass",
                "drc.contact.width.via4",
                "drc.contact.width.via4.external-oracle",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via4SpacingViolation = passingAuditCaseResult(
            caseID: "sky130-magic-via4-spacing-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.contact",
                "drc.contact.spacing",
                "drc.contact.spacing.external-oracle",
                "drc.contact.spacing.fail",
                "drc.contact.spacing.via4",
                "drc.contact.spacing.via4.external-oracle",
                "drc.contact.via4",
                "external.magic",
                "layout.magic",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via4SpacingClean = passingAuditCaseResult(
            caseID: "sky130-magic-via4-spacing-clean",
            coverageTags: [
                "drc.contact",
                "drc.contact.spacing",
                "drc.contact.spacing.external-oracle",
                "drc.contact.spacing.pass",
                "drc.contact.spacing.via4",
                "drc.contact.spacing.via4.external-oracle",
                "drc.contact.via4",
                "external.magic",
                "layout.magic",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via4Metal5EnclosureViolation = passingAuditCaseResult(
            caseID: "sky130-magic-via4-met5-enclosure-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.enclosure",
                "drc.enclosure.external-oracle",
                "drc.enclosure.fail",
                "drc.enclosure.via4",
                "drc.enclosure.via4.met5",
                "drc.enclosure.via4.met5.external-oracle",
                "external.magic",
                "layout.magic",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let via4Metal5EnclosureClean = passingAuditCaseResult(
            caseID: "sky130-magic-via4-met5-enclosure-clean",
            coverageTags: [
                "drc.enclosure",
                "drc.enclosure.external-oracle",
                "drc.enclosure.pass",
                "drc.enclosure.via4",
                "drc.enclosure.via4.met5",
                "drc.enclosure.via4.met5.external-oracle",
                "external.magic",
                "layout.magic",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal5WidthViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met5-width-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.width",
                "drc.width.met5",
                "drc.width.met5.external-oracle",
                "drc.width.met5.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal5WidthClean = passingAuditCaseResult(
            caseID: "sky130-magic-met5-width-clean",
            coverageTags: [
                "drc.width",
                "drc.width.met5",
                "drc.width.met5.external-oracle",
                "drc.width.met5.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal5SpacingViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met5-spacing-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.spacing",
                "drc.spacing.met5",
                "drc.spacing.met5.external-oracle",
                "drc.spacing.met5.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal5SpacingClean = passingAuditCaseResult(
            caseID: "sky130-magic-met5-spacing-clean",
            coverageTags: [
                "drc.spacing",
                "drc.spacing.met5",
                "drc.spacing.met5.external-oracle",
                "drc.spacing.met5.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal5AreaViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met5-area-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.area",
                "drc.area.met5",
                "drc.area.met5.external-oracle",
                "drc.area.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal5AreaClean = passingAuditCaseResult(
            caseID: "sky130-magic-met5-area-clean",
            coverageTags: [
                "drc.area",
                "drc.area.met5",
                "drc.area.met5.external-oracle",
                "drc.area.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal5AngleViolation = passingAuditCaseResult(
            caseID: "sky130-magic-met5-angle-violation",
            coverageTags: [
                "diagnostic.rule-id",
                "drc.angle",
                "drc.angle.met5",
                "drc.angle.met5.external-oracle",
                "drc.angle.fail",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        let metal5AngleClean = passingAuditCaseResult(
            caseID: "sky130-magic-met5-angle-clean",
            coverageTags: [
                "drc.angle",
                "drc.angle.met5",
                "drc.angle.met5.external-oracle",
                "drc.angle.pass",
                "external.magic",
                "layout.gds",
                "sky130",
            ],
            oracleBackendID: "magic",
            summary: summary
        )
        return DRCCorpusReport(
            passed: true,
            caseCount: 95,
            matchedCaseCount: 95,
            budgetExceededCaseCount: 0,
            totalDurationSeconds: 0.03,
            caseResults: [
                baseline,
                cutViolation,
                cutClean,
                widthViolation,
                widthClean,
                spacingViolation,
                spacingClean,
                areaViolation,
                areaClean,
                angleViolation,
                angleClean,
                wideSpacingViolation,
                wideSpacingClean,
                largeAttachedSpacingViolation,
                largeAttachedSpacingClean,
                enclosureViolation,
                enclosureClean,
                contactWidthViolation,
                contactWidthClean,
                contactSpacingViolation,
                contactSpacingClean,
                via1WidthViolation,
                via1WidthClean,
                via1SpacingViolation,
                via1SpacingClean,
                via1Metal1EnclosureViolation,
                via1Metal1EnclosureClean,
                via1Metal2EnclosureViolation,
                via1Metal2EnclosureClean,
                metal2WidthViolation,
                metal2WidthClean,
                metal2SpacingViolation,
                metal2SpacingClean,
                metal2AreaViolation,
                metal2AreaClean,
                metal2AngleViolation,
                metal2AngleClean,
                metal2WideSpacingViolation,
                metal2WideSpacingClean,
                metal2LargeAttachedSpacingViolation,
                metal2LargeAttachedSpacingClean,
                via2WidthViolation,
                via2WidthClean,
                via2SpacingClean,
                via2SpacingViolation,
                via2Metal2EnclosureViolation,
                via2Metal2EnclosureClean,
                via2Metal3EnclosureViolation,
                via2Metal3EnclosureClean,
                metal3WidthViolation,
                metal3WidthClean,
                metal3SpacingViolation,
                metal3SpacingClean,
                metal3AreaViolation,
                metal3AreaClean,
                metal3AngleViolation,
                metal3AngleClean,
                metal3WideSpacingViolation,
                metal3WideSpacingClean,
                metal3LargeAttachedSpacingViolation,
                metal3LargeAttachedSpacingClean,
                via3WidthViolation,
                via3WidthClean,
                via3SpacingClean,
                via3SpacingViolation,
                via3Metal3EnclosureViolation,
                via3Metal3EnclosureClean,
                via3Metal4EnclosureViolation,
                via3Metal4EnclosureClean,
                metal4WidthViolation,
                metal4WidthClean,
                metal4SpacingViolation,
                metal4SpacingClean,
                metal4AreaViolation,
                metal4AreaClean,
                metal4AngleViolation,
                metal4AngleClean,
                metal4WideSpacingViolation,
                metal4WideSpacingClean,
                metal4LargeAttachedSpacingViolation,
                metal4LargeAttachedSpacingClean,
                via4WidthViolation,
                via4WidthClean,
                via4SpacingViolation,
                via4SpacingClean,
                via4Metal5EnclosureViolation,
                via4Metal5EnclosureClean,
                metal5WidthViolation,
                metal5WidthClean,
                metal5SpacingViolation,
                metal5SpacingClean,
                metal5AreaViolation,
                metal5AreaClean,
                metal5AngleViolation,
                metal5AngleClean,
            ]
        )
    }
}
