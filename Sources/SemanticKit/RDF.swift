// Sources/SemanticKitRDF/RDF.swift
import Foundation

// MARK: - IRI term ----------------------------------------------------------

//public struct IRI: RDFIRI {
//    public let iri: IRI
//    public init(_ iri: IRI) {
//        self.iri = iri
//    }
//    // Conformance to RDFIRI (and thus RDFNode) is supplied by the extension in Node.swift
//}

public typealias IRI = ConcreteIri

// MARK: - Blank node --------------------------------------------------------

public struct BlankNode: RDFBlankNode {
    public let identifier: String
    public init(_ identifier: String) {
        // Blank node labels cannot be empty – enforce a minimal rule.
        precondition(!identifier.isEmpty, "Blank node identifier must not be empty")
        self.identifier = identifier
    }
}

// MARK: - Literal -----------------------------------------------------------

public struct Literal: RDFLiteral {
    public let lexicalForm: String
    public let languageTag: String?
    public let datatype: (any Iri)?

    /// Designated initializer.
    ///
    /// - Parameters:
    ///   - lexicalForm: the raw string value.
    ///   - languageTag: optional BCP‑47 tag (must be lower‑case per RDF‑1.2).
    ///   - datatype: optional datatype IRI (defaults to `xsd:string` when nil).
    public init(
        _ lexicalForm: String,
        languageTag: String? = nil,
        datatype: (any Iri)? = nil
    ) {
        self.lexicalForm = lexicalForm
        self.languageTag = languageTag?.lowercased()
        self.datatype = datatype
        // Validation according to §4.2 of the RFC
        if let lang = languageTag {
            precondition(!lang.isEmpty, "Language tag must not be empty")
        }
        if let dt = datatype {
            precondition(NSString(string: dt.string).isAbsolutePath, "Datatype IRI must be absolute")
        }
    }
}
