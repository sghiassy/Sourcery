import Foundation
import xcproj

extension XcodeProj {
    func sourceFilesPaths(targetName: String, sourceRoot: Path) throws -> [Path] {
        guard let target = pbxproj.objects.targets(named: targetName).first else {
            throw "Missing target \(targetName)."
        }
        guard let sourcesBuildPhase = pbxproj.objects.sourcesBuildPhases.values.first(where: { target.buildPhases.contains($0.reference) }) else {
            throw "Missing sources build phase for target \(targetName)."
        }
        let sourceFilePaths = sourcesBuildPhase.files
            .flatMap({ pbxproj.objects.buildFiles[$0]?.fileRef })
            .flatMap(pbxproj.objects.getFileElement(reference:))
            .flatMap({ (file: PBXFileElement) -> Path? in
                switch file.sourceTree {
                case .absolute?:
                    return file.path.flatMap({ Path($0) })
                case .sourceRoot?:
                    return file.path.flatMap({ Path($0, relativeTo: sourceRoot) })
                default:
                    return nil
                }
            })
        return sourceFilePaths
    }
}
