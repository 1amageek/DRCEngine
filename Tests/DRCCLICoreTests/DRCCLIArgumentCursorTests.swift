import Foundation
import Testing
import DRCCLICore

extension DRCCLIOptionsTests {
    @Test func runOptionsRejectOptionTokenAsLayoutValue() throws {
        let error = try captureError {
            _ = try DRCCLIOptions(arguments: [
                "--layout",
                "--top-cell", "inv",
                "--out", "/tmp/drc",
            ])
        }

        #expect(error == .missingValue("--layout"))
    }

    @Test func corpusOptionsRejectOptionTokenAsOracleBackendValue() throws {
        let error = try captureError {
            _ = try DRCCorpusCLIOptions(arguments: [
                "--corpus", "/tmp/drc-corpus.json",
                "--out", "/tmp/drc",
                "--oracle-backend",
                "--json",
            ])
        }

        #expect(error == .missingValue("--oracle-backend"))
    }

    @Test func runOptionsRejectWhitespaceOnlyTopCellValue() throws {
        let error = try captureError {
            _ = try DRCCLIOptions(arguments: [
                "--layout", "/tmp/layout.json",
                "--top-cell", "   ",
                "--out", "/tmp/drc",
            ])
        }

        #expect(error == .invalidValue(argument: "--top-cell", value: "   ", expected: "non-empty top cell"))
    }

    @Test func foundryImportOptionsRejectOptionTokenAsPDKRootValue() throws {
        let error = try captureError {
            _ = try DRCFoundryRuleImportCLIOptions(arguments: [
                "--import-foundry-magic-rules",
                "--pdk-root",
                "--tech-out", "/tmp/layout-tech.json",
            ])
        }

        #expect(error == .missingValue("--pdk-root"))
    }

    @Test func foundryImportOptionsRejectWhitespaceOnlyProfileResourceValue() throws {
        let error = try captureError {
            _ = try DRCFoundryRuleImportCLIOptions(arguments: [
                "--import-foundry-magic-rules",
                "--profile-resource", "   ",
                "--tech-out", "/tmp/layout-tech.json",
            ])
        }

        #expect(
            error == .invalidValue(
                argument: "--profile-resource",
                value: "   ",
                expected: "non-empty profile resource name"
            )
        )
    }

    @Test func magicImportOptionsRejectOptionTokenAsMagicTechValue() throws {
        let error = try captureError {
            _ = try DRCMagicRuleImportCLIOptions(arguments: [
                "--import-magic-rules",
                "--magic-tech",
                "--profile", "/tmp/profile.json",
                "--tech-out", "/tmp/layout-tech.json",
            ])
        }

        #expect(error == .missingValue("--magic-tech"))
    }
}
