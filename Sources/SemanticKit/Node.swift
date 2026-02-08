// Sources/SemanticKitRDF/Node.swift
import Foundation

// MARK: - RDFNode -----------------------------------------------------------

/// The most generic protocol for every RDF term.
public protocol RDFNode: Hashable, CustomStringConvertible, Sendable {}

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

// MARK: - RDF Literal Direction ---------------------------------------------

/// Initial text direction for directional language-tagged strings.
public enum TextDirection: String, Hashable, Sendable {
    case ltr
    case rtl
}

// MARK: - RDFLiteral ---------------------------------------------------------

/// A literal consists of a lexical form, an optional language tag, and an optional datatype IRI.
public protocol RDFLiteral: RDFNode {
    var lexicalForm: String { get }
    var languageTag: String? { get }      // e.g. "en", "fr‑CA"
    var textDirection: TextDirection? { get }
    var datatype: (any Iri)? { get }            // defaults to xsd:string when nil
}

extension RDFLiteral {
    public var description: String {
        var lit = "\"\(lexicalForm)\""
        if let lang = languageTag {
            lit += "@\(lang)"
            if let direction = textDirection {
                lit += "--\(direction.rawValue)"
            }
        }
        if let dt = datatype {
            lit += "^^<\(try! dt.asURL().absoluteString)>"
        }
        return lit
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.lexicalForm == rhs.lexicalForm &&
        lhs.languageTag == rhs.languageTag &&
        lhs.textDirection == rhs.textDirection &&
        lhs.datatype?.string == rhs.datatype?.string
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(lexicalForm)
        hasher.combine(languageTag)
        hasher.combine(textDirection)
        hasher.combine(datatype?.string)
    }
}
