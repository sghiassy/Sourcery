import Foundation
import xcproj

extension XcodeProj {

    func target(named targetName: String) -> PBXTarget? {
        return pbxproj.objects.nativeTargets.values.first(where: { $0.name == targetName })
    }

    func sourcesBuildPhase(forTarget target: PBXTarget) -> PBXSourcesBuildPhase? {
        return pbxproj.objects.sourcesBuildPhases.values.first(where: { target.buildPhases.contains($0.reference) })
    }

    func sourceFilesPaths(target: PBXTarget, sourceRoot: Path) -> [Path] {
        let sourceFilePaths = sourcesBuildPhase(forTarget: target)?.files
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
        return sourceFilePaths ?? []
    }

    var rootGroup: PBXGroup {
        // swiftlint:disable:next force_cast
        let groupRef = (pbxproj.objects.getReference(pbxproj.rootObject) as! PBXProject).mainGroup
        // swiftlint:disable:next force_unwrapping
        return pbxproj.objects.groups[groupRef]!
    }

    func group(named groupName: String, inGroup: PBXGroup?) -> PBXGroup? {
        var group: PBXGroup? = nil
        let inGroup = inGroup ?? rootGroup
        var children = inGroup.children
        for groupName in groupName.components(separatedBy: "/") {
            let groups = pbxproj.objects.groups.flatMap({ children.contains($0.key) ? $0.value : nil })
            group = groups.first(where: { $0.name == groupName || $0.path == groupName })
            children = group?.children ?? []
        }
        return group
    }

    func addGroup(named groupName: String, toGroup: PBXGroup?) -> PBXGroup {
        var toGroup = toGroup ?? rootGroup
        var newGroup: PBXGroup!
        for groupName in groupName.components(separatedBy: "/") {
            if let existingGroup = group(named: groupName, inGroup: toGroup) {
                newGroup = existingGroup
                toGroup = existingGroup
            } else {
                newGroup = PBXGroup(reference: pbxproj.generateUUID(for: PBXGroup.self), children: [], sourceTree: .group, path: groupName)
                pbxproj.objects.addObject(newGroup)
                toGroup.children.append(newGroup.reference)
                toGroup = newGroup
            }
        }
        return newGroup
    }

    func addSourceFile(at filePath: Path, toGroup: PBXGroup, target: PBXTarget) -> PBXFileReference? {
        guard let sourcesBuildPhase = sourcesBuildPhase(forTarget: target) else { return nil }

        let allFiles = pbxproj.objects.fileReferences.values
        let fileReference: PBXFileReference
        if let existingFileReference = allFiles.first(where: { $0.path == filePath.string }) {
            fileReference = existingFileReference
        } else {
            fileReference = PBXFileReference(reference: pbxproj.generateUUID(for: PBXFileReference.self), sourceTree: .absolute, name: filePath.lastComponent, lastKnownFileType: PBXFileReference.fileType(path: filePath), path: filePath.string)
            pbxproj.objects.addObject(fileReference)

            let buildFile = PBXBuildFile(reference: pbxproj.generateUUID(for: PBXBuildFile.self), fileRef: fileReference.reference)
            sourcesBuildPhase.files.append(buildFile.reference)
            pbxproj.objects.addObject(buildFile)
        }

        let groupFiles = allFiles.filter({ toGroup.children.contains($0.reference) })
        if groupFiles.first(where: { $0.path == filePath.string }) == nil {
            toGroup.children.append(fileReference.reference)
        }

        return fileReference
    }

}
