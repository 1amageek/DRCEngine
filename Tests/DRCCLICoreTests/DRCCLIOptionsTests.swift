import Testing
import DRCCLICore

@Suite("DRC CLI options")
struct DRCCLIOptionsTests {
    @Test func invalidTimeoutThrows() throws {
        let error = try captureError {
            _ = try DRCCLIOptions(arguments: [
                "--layout", "/tmp/inverter.gds",
                "--top-cell", "inv",
                "--out", "/tmp/drc",
                "--timeout", "abc",
            ])
        }

        #expect(error == .invalidValue(
            argument: "--timeout",
            value: "abc",
            expected: "positive finite seconds"
        ))
    }

    @Test func zeroTimeoutThrows() throws {
        let error = try captureError {
            _ = try DRCCLIOptions(arguments: [
                "--layout", "/tmp/inverter.gds",
                "--top-cell", "inv",
                "--out", "/tmp/drc",
                "--timeout", "0",
            ])
        }

        #expect(error == .invalidValue(
            argument: "--timeout",
            value: "0",
            expected: "positive finite seconds"
        ))
    }

    private func captureError(_ operation: () throws -> Void) throws -> DRCCLIError? {
        do {
            try operation()
            return nil
        } catch let error as DRCCLIError {
            return error
        } catch {
            throw error
        }
    }
}
