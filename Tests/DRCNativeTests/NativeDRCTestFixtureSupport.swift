import Foundation
import DRCNative

func makeNativeDRCTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: "NativeDRCTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

func writeNativeDRCLayout(_ layout: NativeDRCLayout, in directory: URL) throws -> URL {
    let url = directory.appending(path: "layout.json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(layout)
    try data.write(to: url)
    return url
}
