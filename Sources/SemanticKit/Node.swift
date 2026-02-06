// Sources/SemanticKitRDF/Node.swift
import Foundation

// MARK: - RDFNode -----------------------------------------------------------

/// The most generic protocol for every RDF term.
public protocol RDFNode: Hashable, CustomStringConvertible {}

extension RDFNode {
    /// A handy shortcut for converting the node to an N‑Triples literal.
    public var ntriples: String { description }
}

// MARK: - RDFBlankNode -------------------------------------------------------

/// A blank node, identified by a locally unique label.
public protocol RDFBlankNode: RDFNode {
    var identifier: String { get }
}

extension RDFBlankNode {
    public var description: String { "_:\(identifier)" }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.identifier == rhs.identifier
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}

// MARK: - RDFLiteral ---------------------------------------------------------

/// A literal consists of a lexical form, an optional language tag, and an optional datatype IRI.
public protocol RDFLiteral: RDFNode {
    var lexicalForm: String { get }
    var languageTag: String? { get }      // e.g. "en", "fr‑CA"
    var datatype: (any Iri)? { get }            // defaults to xsd:string when nil
}

extension RDFLiteral {
    public var description: String {
        var lit = "\"\(lexicalForm)\""
        if let lang = languageTag {
            lit += "@\(lang)"
        }
        if let dt = datatype {
            lit += "^^<\(try! dt.asURL().absoluteString)>"
        }
        return lit
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.lexicalForm == rhs.lexicalForm &&
        lhs.languageTag == rhs.languageTag &&
        lhs.datatype?.string == rhs.datatype?.string
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(lexicalForm)
        hasher.combine(languageTag)
        hasher.combine(datatype?.string)
    }
}

//public protocol RDFSubject: RDFNode {}
//extension IRI: RDFSubject {}
//extension BlankNode: RDFSubject {}
//
////public protocol RDFPredicate: RDFNode {}
//extension IRI: RDFPredicate {}
//
////public protocol RDFObject: RDFNode {}
//extension IRI: RDFObject {}
//extension BlankNode: RDFObject {}
//extension Literal: RDFObject {}
