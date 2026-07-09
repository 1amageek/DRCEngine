import Foundation

struct DRCCLIArgumentCursor: Sendable {
    private let arguments: [String]
    private var index = 0

    init(arguments: [String]) {
        self.arguments = arguments
    }

    mutating func next() -> String? {
        guard index < arguments.count else { return nil }
        let value = arguments[index]
        index += 1
        return value
    }

    mutating func requireValue(for option: String) throws -> String {
        guard let value = next(), !value.isEmpty, !value.hasPrefix("--") else {
            throw DRCCLIError.missingValue(option)
        }
        return value
    }

    mutating func requireNonEmptyValue(for option: String, expected: String) throws -> String {
        let value = try requireValue(for: option)
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DRCCLIError.invalidValue(argument: option, value: value, expected: expected)
        }
        return value
    }

    static func value(
        after argument: String,
        in arguments: [String],
        index: inout Int
    ) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw DRCCLIError.missingValue(argument)
        }
        let value = arguments[valueIndex]
        guard !value.hasPrefix("--") else {
            throw DRCCLIError.missingValue(argument)
        }
        index = valueIndex
        return value
    }

    static func nonEmptyValue(
        after argument: String,
        in arguments: [String],
        index: inout Int,
        expected: String
    ) throws -> String {
        let value = try value(after: argument, in: arguments, index: &index)
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DRCCLIError.invalidValue(argument: argument, value: value, expected: expected)
        }
        return value
    }
}
