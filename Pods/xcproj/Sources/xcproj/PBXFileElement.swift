import Foundation

/// This element is an abstract parent for file and group elements.
public class PBXFileElement: PBXObject, Hashable, PlistSerializable {
    
    // MARK: - Attributes

    /// Element source tree.
    public var sourceTree: PBXSourceTree?
    
    /// Element path.
    public var path: String?
    
    /// Element name.
    public var name: String?
    
    // MARK: - Init
    
    /// Initializes the file element with its properties.
    ///
    /// - Parameters:
    ///   - reference: element reference.
    ///   - sourceTree: file source tree.
    ///   - name: file name.
    public init(reference: String,
                sourceTree: PBXSourceTree? = nil,
                path: String? = nil,
                name: String? = nil) {
        self.sourceTree = sourceTree
        self.path = path
        self.name = name
        super.init(reference: reference)
    }
    
    public static func == (lhs: PBXFileElement,
                           rhs: PBXFileElement) -> Bool {
        return lhs.reference == rhs.reference &&
            lhs.sourceTree == rhs.sourceTree &&
            lhs.path == rhs.path &&
            lhs.name == rhs.name
    }
    
    // MARK: - Decodable
    
    fileprivate enum CodingKeys: String, CodingKey {
        case sourceTree
        case name
        case path
        case reference
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sourceTree = try container.decodeIfPresent(.sourceTree)
        self.name = try container.decodeIfPresent(.name)
        self.path = try container.decodeIfPresent(.path)
        try super.init(from: decoder)
    }
    
    // MARK: - PlistSerializable

    var multiline: Bool { return true }
    
    func plistKeyAndValue(proj: PBXProj) -> (key: CommentedString, value: PlistValue) {
        var dictionary: [CommentedString: PlistValue] = [:]
        dictionary["isa"] = .string(CommentedString(PBXFileElement.isa))
        if let name = name {
            dictionary["name"] = .string(CommentedString(name))
        }
        if let path = path {
            dictionary["path"] = .string(CommentedString(path))
        }
        if let sourceTree = sourceTree {
            dictionary["sourceTree"] = sourceTree.plist()
        }
        return (key: CommentedString(self.reference,
                                     comment: self.name),
                value: .dictionary(dictionary))
    }
    
}
