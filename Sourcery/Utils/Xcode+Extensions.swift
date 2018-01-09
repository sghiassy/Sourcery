import Foundation
import xcproj

extension XcodeProj {

    func target(named targetName: String) -> PBXTarget? {
        return pbxproj.objects.nativeTargets.values.first(where: { $0.name == targetName })
    }

    func sourcesBuildPhase(forTarget target: PBXTarget) -> PBXSourcesBuildPhase? {
        return pbxproj.objects.sourcesBuildPhases.first(where: { target.buildPhases.contains($0.key) })?.value
    }

    func fullPath(fileElement: PBXFileElement, reference: String, sourceRoot: Path) -> Path? {
        switch fileElement.sourceTree {
        case .absolute?:
            return fileElement.path.flatMap({ Path($0) })
        case .sourceRoot?:
            return fileElement.path.flatMap({ Path($0, relativeTo: sourceRoot) })
        case .group?:
            guard let group = pbxproj.objects.groups.first(where: { $0.value.children.contains(reference) }) else { return sourceRoot }
            guard let groupPath = fullPath(fileElement: group.value, reference: group.key, sourceRoot: sourceRoot) else { return nil }
            return fileElement.path.flatMap({ Path($0, relativeTo: groupPath) })
        default:
            return nil
        }
    }

    func sourceFilesPaths(target: PBXTarget, sourceRoot: Path) -> [Path] {
        let sourceFilePaths = sourcesBuildPhase(forTarget: target)?.files
            .flatMap({ pbxproj.objects.buildFiles[$0]?.fileRef })
            .flatMap({ ref in pbxproj.objects.getFileElement(reference: ref).map({ (ref, $0) }) })
            .flatMap({ (reference, file) in
                fullPath(fileElement: file, reference: reference, sourceRoot: sourceRoot)
            })
        return sourceFilePaths ?? []
    }

    var rootGroup: PBXGroup {
        // swiftlint:disable:next force_unwrapping
        let groupRef = pbxproj.objects.projects[pbxproj.rootObject]!.mainGroup
        // swiftlint:disable:next force_unwrapping
        return pbxproj.objects.groups[groupRef]!
    }

    func group(named groupName: String, inGroup: PBXGroup?) -> PBXGroup? {
        var group: PBXGroup? = nil
        let inGroup = inGroup ?? rootGroup
        var children = inGroup.children
        for groupName in groupName.components(separatedBy: "/") {
            group = pbxproj.objects.groups.first(where: {
                children.contains($0.key) && $0.value.name == groupName || $0.value.path == groupName
            })?.value
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
                newGroup = PBXGroup(children: [], sourceTree: .group, path: groupName)
                let groupRef = pbxproj.objects.generateReference(newGroup, groupName)
                pbxproj.objects.addObject(newGroup, reference: groupRef)
                toGroup.children.append(groupRef)
                toGroup = newGroup
            }
        }
        return newGroup
    }

    func addSourceFile(at filePath: Path, toGroup: PBXGroup, target: PBXTarget) -> PBXFileReference? {
        guard let sourcesBuildPhase = sourcesBuildPhase(forTarget: target) else { return nil }

        let allFiles = pbxproj.objects.fileReferences
        let fileReference: PBXFileReference
        let fileRef: String
        if let existingFileReference = allFiles.first(where: { $0.value.path == filePath.string }) {
            fileReference = existingFileReference.value
            fileRef = existingFileReference.key
        } else {
            fileReference = PBXFileReference(sourceTree: .absolute, name: filePath.lastComponent, lastKnownFileType: PBXFileReference.fileType(path: filePath), path: filePath.string)
            fileRef = pbxproj.objects.generateReference(fileReference, filePath.string)
            pbxproj.objects.addObject(fileReference, reference: fileRef)

            let buildFile = PBXBuildFile(fileRef: fileRef)
            let buildFileRef = pbxproj.objects.generateReference(buildFile, filePath.string)
            pbxproj.objects.addObject(buildFile, reference: buildFileRef)
            sourcesBuildPhase.files.append(buildFileRef)
        }

        let groupFiles = allFiles.filter({ toGroup.children.contains($0.key) })
        if groupFiles.first(where: { $0.value.path == filePath.string }) == nil {
            toGroup.children.append(fileRef)
        }

        return fileReference
    }

}
