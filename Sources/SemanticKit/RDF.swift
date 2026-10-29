// Sources/SemanticKitRDF/RDF.swift
import Foundation
import IRIKit

public enum RDFTermError: Error, LocalizedError {
    case emptyBlankNodeIdentifier
    case emptyLanguageTag
    case languageTagWithDatatype
    case textDirectionRequiresLanguageTag
    case invalidGraphName
    case invalidSubject
    case invalidContainerMembershipIndex

    public var errorDescription: String? {
        switch self {
        case .emptyBlankNodeIdentifier:
            return "Blank node identifier must not be empty."
        case .emptyLanguageTag:
            return "Language tag must not be empty."
        case .languageTagWithDatatype:
            return "Language-tagged strings must not declare a datatype."
        case .textDirectionRequiresLanguageTag:
            return "Text direction requires a language tag."
        case .invalidGraphName:
            return "Graph name must be IRI or BlankNode."
        case .invalidSubject:
            return "RDF subject must be IRI or BlankNode."
        case .invalidContainerMembershipIndex:
            return "Container membership property index must be positive."
        }
    }
}

// MARK: - Blank node --------------------------------------------------------

public struct BlankNode: RDFBlankNode {
    public let identifier: String
    public init(_ identifier: String) throws {
        // Blank node labels cannot be empty – enforce a minimal rule.
        guard !identifier.isEmpty else {
            throw RDFTermError.emptyBlankNodeIdentifier
        }
        self.identifier = identifier
    }
}

// MARK: - Literal -----------------------------------------------------------

public struct Literal: RDFLiteral {
    public let lexicalForm: String
    public let languageTag: String?
    public let textDirection: TextDirection?
    public let datatype: IRI?

    /// Designated initializer.
    ///
    /// - Parameters:
    ///   - lexicalForm: the raw string value.
    ///   - languageTag: optional BCP‑47 tag (must be lower‑case per RDF‑1.2).
    ///   - textDirection: optional initial text direction for language-tagged strings.
    ///   - datatype: optional datatype IRI (defaults to `xsd:string` when nil).
    public init(
        _ lexicalForm: String,
        languageTag: String? = nil,
        textDirection: TextDirection? = nil,
        datatype: IRI? = nil
    ) throws {
        self.lexicalForm = lexicalForm
        self.languageTag = languageTag?.lowercased()
        self.textDirection = textDirection
        self.datatype = datatype
        // Validation according to §4.2 of the RFC
        if let lang = self.languageTag {
            guard !lang.isEmpty else {
                throw RDFTermError.emptyLanguageTag
            }
            guard datatype == nil else {
                throw RDFTermError.languageTagWithDatatype
            }
        } else {
            guard textDirection == nil else {
                throw RDFTermError.textDirectionRequiresLanguageTag
            }
        }
    }
}
