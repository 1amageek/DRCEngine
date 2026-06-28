import Foundation
import DRCCore
import LayoutCore
import LayoutIO
import LayoutTech

struct DRCCorpusGeneratedInputFactory: Sendable {
    private func resolve(_ path: String, relativeTo base: URL) -> URL {
        if path.hasPrefix("/") {
            return URL(filePath: path)
        }
        return base.appending(path: path)
    }

    func prepareInputs(
        for corpusCase: DRCCorpusCase,
        specDirectory: URL,
        caseDirectory: URL
    ) throws -> PreparedDRCCorpusInputs {
        guard let fixture = corpusCase.generatedLayoutFixture else {
            return PreparedDRCCorpusInputs(
                layoutURL: resolve(corpusCase.layoutPath, relativeTo: specDirectory),
                layoutFormat: corpusCase.layoutFormat,
                technologyURL: corpusCase.technologyPath.map { resolve($0, relativeTo: specDirectory) }
            )
        }

        let generatedDirectory = caseDirectory.appending(path: "generated-inputs")
        try FileManager.default.createDirectory(at: generatedDirectory, withIntermediateDirectories: true)
        let technology = try DRCCorpusGeneratedTechnologyFactory().technology(for: fixture, specDirectory: specDirectory)
        let technologyURL = generatedDirectory.appending(path: "technology.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(technology).write(to: technologyURL, options: [.atomic])

        let layoutFormat = corpusCase.layoutFormat ?? fixture.format
        let layoutURL = try generatedOutputURL(
            path: corpusCase.layoutPath,
            format: layoutFormat,
            in: generatedDirectory
        )
        let document = try DRCCorpusGeneratedLayoutFactory().document(for: fixture)
        if layoutFormat == .nativeJSON {
            try LayoutDocumentSerializer().encodeDocument(document).write(to: layoutURL, options: [.atomic])
        } else {
            try MaskDataFormatConverter(tech: technology).exportDocument(
                document,
                to: layoutURL,
                format: try layoutFileFormat(for: layoutFormat)
            )
        }

        return PreparedDRCCorpusInputs(
            layoutURL: layoutURL,
            layoutFormat: layoutFormat,
            technologyURL: technologyURL
        )
    }

    private func generatedOutputURL(
        path: String,
        format: DRCLayoutFormat,
        in directory: URL
    ) throws -> URL {
        guard !path.hasPrefix("/") else {
            throw DRCError.invalidInput("Generated DRC layout path must be relative: \(path)")
        }
        let components = path.split(separator: "/").map(String.init)
        guard !components.isEmpty, !components.contains("..") else {
            throw DRCError.invalidInput("Generated DRC layout path must not escape its case directory: \(path)")
        }
        let requestedURL = components.reduce(directory) { partial, component in
            partial.appending(path: component)
        }
        try FileManager.default.createDirectory(
            at: requestedURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if requestedURL.pathExtension.isEmpty {
            return requestedURL.appendingPathExtension(fileExtension(for: format))
        }
        return requestedURL
    }

    private func layoutFileFormat(for format: DRCLayoutFormat) throws -> LayoutFileFormat {
        switch format {
        case .auto, .gds:
            return .gds
        case .oasis:
            return .oasis
        case .cif:
            return .cif
        case .dxf:
            return .dxf
        case .nativeJSON:
            return .gds
        case .magicLayout:
            throw DRCError.invalidInput("Generated magic-layout fixtures require a Magic layout artifact writer.")
        }
    }

    private func fileExtension(for format: DRCLayoutFormat) -> String {
        switch format {
        case .auto, .gds:
            return "gds"
        case .oasis:
            return "oas"
        case .cif:
            return "cif"
        case .dxf:
            return "dxf"
        case .nativeJSON:
            return "json"
        case .magicLayout:
            return "mag"
        }
    }

}
