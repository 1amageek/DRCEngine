import Foundation
import DRCCLICore

@main
struct DRCCLIEntry {
    static func main() async {
        let exitCode = await DRCCLI.run(arguments: Array(CommandLine.arguments.dropFirst()))
        Foundation.exit(exitCode)
    }
}
