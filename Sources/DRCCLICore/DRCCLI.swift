import Foundation
import DRCEngine

public enum DRCCLIError: Error, LocalizedError, Equatable {
    case missingValue(String)
    case missingRequired(String)
    case invalidValue(argument: String, value: String, expected: String)
    case unknownArgument(String)

    public var errorDescription: String? {
        switch self {
        case .missingValue(let argument):
            return "Missing value after \(argument)"
        case .missingRequired(let argument):
            return "Missing required argument: \(argument)"
        case .invalidValue(let argument, let value, let expected):
            return "Invalid value for \(argument): \(value). Expected \(expected)"
        case .unknownArgument(let argument):
            return "Unknown argument: \(argument)"
        }
    }
}

public struct DRCCLIOptions: Sendable, Hashable {
    public let layoutURL: URL
    public let topCell: String
    public let outputDirectory: URL
    public let timeoutSeconds: Double

    public init(arguments: [String]) throws {
        var layoutURL: URL?
        var topCell: String?
        var outputDirectory: URL?
        var timeoutSeconds = 300.0
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--layout":
                layoutURL = URL(filePath: try Self.value(after: argument, in: arguments, index: &index))
            case "--top-cell":
                topCell = try Self.value(after: argument, in: arguments, index: &index)
            case "--out":
                outputDirectory = URL(filePath: try Self.value(after: argument, in: arguments, index: &index))
            case "--timeout":
                timeoutSeconds = try Self.positiveFiniteDouble(after: argument, in: arguments, index: &index)
            default:
                throw DRCCLIError.unknownArgument(argument)
            }
            index += 1
        }

        guard let layoutURL else { throw DRCCLIError.missingRequired("--layout") }
        guard let topCell else { throw DRCCLIError.missingRequired("--top-cell") }
        guard let outputDirectory else { throw DRCCLIError.missingRequired("--out") }
        self.layoutURL = layoutURL
        self.topCell = topCell
        self.outputDirectory = outputDirectory
        self.timeoutSeconds = timeoutSeconds
    }

    public func makeRequest() -> DRCRequest {
        DRCRequest(
            layoutURL: layoutURL,
            topCell: topCell,
            workingDirectory: outputDirectory,
            options: DRCOptions(timeoutSeconds: timeoutSeconds)
        )
    }

    private static func value(after argument: String, in arguments: [String], index: inout Int) throws -> String {
        let valueIndex = index + 1
        guard valueIndex < arguments.count else {
            throw DRCCLIError.missingValue(argument)
        }
        index = valueIndex
        return arguments[valueIndex]
    }

    private static func positiveFiniteDouble(after argument: String, in arguments: [String], index: inout Int) throws -> Double {
        let rawValue = try value(after: argument, in: arguments, index: &index)
        guard let value = Double(rawValue), value.isFinite, value > 0 else {
            throw DRCCLIError.invalidValue(argument: argument, value: rawValue, expected: "positive finite seconds")
        }
        return value
    }
}

public enum DRCCLI {
    public static func run(arguments: [String]) async -> Int32 {
        do {
            let options = try DRCCLIOptions(arguments: arguments)
            let result = try await DefaultDRCEngine().run(options.makeRequest())
            print("status=\(result.result.passed ? "passed" : "failed")")
            if let reportURL = result.reportURL {
                print("report=\(reportURL.path(percentEncoded: false))")
            }
            return result.result.passed ? 0 : 2
        } catch {
            FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
            return 1
        }
    }
}
