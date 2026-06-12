import Foundation
import DRCCore

public struct MagicDRCReportParser: Sendable {
    public init() {}

    public func parse(
        backendID: String = "magic",
        toolName: String = "magic",
        logPath: String,
        rawOutput: String,
        success: Bool,
        provenance: DRCToolProvenance? = nil
    ) -> DRCResult {
        var diagnostics = rawOutput
            .split(whereSeparator: \.isNewline)
            .compactMap { parseDiagnostic(line: String($0)) }

        let completed = containsExactLine("DRC_DONE", in: rawOutput)
        if completed {
            if let summaryLine = summaryLine(in: rawOutput) {
                let fields = keyValueFields(in: summaryLine)
                if let totalText = fields["total"], let total = Int(totalText) {
                    let enumeratedCount = enumeratedViolationCount(in: diagnostics)
                    if total != enumeratedCount {
                        diagnostics.append(DRCDiagnostic(
                            severity: .error,
                            message: "DRC_SUMMARY total=\(total) does not match enumerated violation count=\(enumeratedCount)",
                            ruleID: "DRC_SUMMARY_MISMATCH",
                            count: total,
                            rawLine: summaryLine
                        ))
                    }
                } else if !diagnostics.contains(where: { $0.severity == .error }) {
                    diagnostics.append(DRCDiagnostic(
                        severity: .error,
                        message: "DRC_SUMMARY total is missing or invalid",
                        ruleID: "DRC_SUMMARY_INVALID",
                        rawLine: summaryLine
                    ))
                }
            } else if !diagnostics.contains(where: { $0.severity == .error }) {
                diagnostics.append(DRCDiagnostic(
                    severity: .error,
                    message: "DRC completed without a DRC_SUMMARY line",
                    ruleID: "DRC_SUMMARY_MISSING",
                    rawLine: "DRC_DONE"
                ))
            }
        }

        return DRCResult(
            backendID: backendID,
            toolName: toolName,
            success: success,
            completed: completed,
            logPath: logPath,
            diagnostics: diagnostics,
            provenance: provenance
        )
    }

    private func parseDiagnostic(line: String) -> DRCDiagnostic? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let fields = keyValueFields(in: trimmed)
        let uppercased = trimmed.uppercased()

        if uppercased.hasPrefix("VIOLATION") {
            guard let ruleID = fields["rule"] else { return nil }
            return DRCDiagnostic(
                severity: .error,
                message: fields["message"] ?? strippedMessage(from: trimmed),
                ruleID: ruleID,
                count: fields["count"].flatMap(Int.init),
                rawLine: trimmed
            )
        }

        if uppercased.hasPrefix("ERROR") {
            return DRCDiagnostic(
                severity: .error,
                message: fields["message"] ?? strippedMessage(from: trimmed),
                ruleID: fields["rule"],
                count: fields["count"].flatMap(Int.init),
                rawLine: trimmed
            )
        }

        return nil
    }

    private func containsExactLine(_ marker: String, in rawOutput: String) -> Bool {
        rawOutput
            .split(whereSeparator: \.isNewline)
            .contains { String($0).trimmingCharacters(in: .whitespacesAndNewlines) == marker }
    }

    private func summaryLine(in rawOutput: String) -> String? {
        for line in rawOutput.split(whereSeparator: \.isNewline) {
            let text = String(line)
            guard text.contains("DRC_SUMMARY") else { continue }
            return text
        }
        return nil
    }

    private func enumeratedViolationCount(in diagnostics: [DRCDiagnostic]) -> Int {
        diagnostics
            .filter { $0.rawLine.uppercased().hasPrefix("VIOLATION") }
            .reduce(0) { total, diagnostic in
                total + (diagnostic.count ?? 1)
            }
    }

    private func keyValueFields(in line: String) -> [String: String] {
        var result: [String: String] = [:]
        var index = line.startIndex
        while index < line.endIndex {
            while index < line.endIndex, isFieldSeparator(line[index]) {
                index = line.index(after: index)
            }
            let keyStart = index
            while index < line.endIndex, line[index] != "=", !isFieldSeparator(line[index]) {
                index = line.index(after: index)
            }
            guard index < line.endIndex, line[index] == "=" else {
                while index < line.endIndex, !isFieldSeparator(line[index]) {
                    index = line.index(after: index)
                }
                continue
            }
            let key = String(line[keyStart..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
            index = line.index(after: index)

            let value: String
            if index < line.endIndex && (line[index] == "\"" || line[index] == "'") {
                let quote = line[index]
                index = line.index(after: index)
                var characters: [Character] = []
                while index < line.endIndex, line[index] != quote {
                    if line[index] == "\\" {
                        let escapeIndex = line.index(after: index)
                        guard escapeIndex < line.endIndex else { break }
                        characters.append(unescapedCharacter(line[escapeIndex]))
                        index = line.index(after: escapeIndex)
                    } else {
                        characters.append(line[index])
                        index = line.index(after: index)
                    }
                }
                value = String(characters)
                if index < line.endIndex {
                    index = line.index(after: index)
                }
            } else {
                let valueStart = index
                while index < line.endIndex, !isFieldSeparator(line[index]) {
                    index = line.index(after: index)
                }
                value = String(line[valueStart..<index])
            }

            if !key.isEmpty {
                result[key] = value
            }
        }
        return result
    }

    private func isFieldSeparator(_ character: Character) -> Bool {
        character == " " || character == "\t" || character == ","
    }

    private func unescapedCharacter(_ character: Character) -> Character {
        switch character {
        case "n":
            return "\n"
        case "r":
            return "\r"
        case "t":
            return "\t"
        default:
            return character
        }
    }

    private func strippedMessage(from line: String) -> String {
        line.replacingOccurrences(of: "VIOLATION", with: "")
            .replacingOccurrences(of: "ERROR", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
