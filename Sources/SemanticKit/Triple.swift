// Sources/SemanticKitRDF/Triple.swift
import Foundation

// MARK: - RDFTriple ---------------------------------------------------------

/// A triple consists of a *subject*, *predicate*, and *object*.
///
/// - The **subject** must be an IRI or a BlankNode.
/// - The **predicate** must always be an IRI.
/// - The **object** may be an IRI, BlankNode, Literal, or TripleTerm.
public protocol RDFTriple: Hashable, CustomStringConvertible {
    associatedtype Subject: RDFNode where Subject: RDFSubject
    associatedtype Predicate: RDFNode where Predicate: RDFPredicate
    associatedtype Object: RDFNode where Object: RDFObject

    var subject: Subject   { get }
    var predicate: Predicate { get }
    var object: Object     { get }
}

// -------------------------------------------------------------------------

/// Helper protocols that restrict the allowed node classes for each position.
public protocol RDFSubject: RDFNode {}
public protocol RDFPredicate: RDFNode {}
public protocol RDFObject: RDFNode {}

extension RDFTriple {
    public var description: String {
        "\(subject) \(predicate) \(object) ."
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.subject == rhs.subject &&
        lhs.predicate == rhs.predicate &&
        lhs.object == rhs.object
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(subject)
        hasher.combine(predicate)
        hasher.combine(object)
    }
}

// MARK: - Concrete triple ----------------------------------------------------

/// The default concrete triple used by the library.  It is a *value type*,
/// therefore it can be stored efficiently in Sets.
public struct Triple<S: RDFSubject, O: RDFObject>: RDFTriple {
    public typealias Subject = S
    public typealias Predicate = IRI
    public typealias Object = O

    public let subject: S
    public let predicate: IRI
    public let object: O

    public init(subject: S, predicate: IRI, object: O) {
        // Subject-type rule (subject may not be a Literal).
        // Predicate-type rule (must be IRI).
        self.subject = subject
        self.predicate = predicate
        self.object = object
    }
}

// MARK: - Triple Term --------------------------------------------------------

/// A triple term is an RDF term that can be used as the object of another triple.
public struct TripleTerm: RDFObject, Hashable, CustomStringConvertible {
    public let subject: AnyRDFSubject
    public let predicate: IRI
    public let object: AnyRDFObject

    public init(subject: AnyRDFSubject, predicate: IRI, object: AnyRDFObject) {
        self.subject = subject
        self.predicate = predicate
        self.object = object
    }

    public var description: String {
        "<<\(subject) \(predicate) \(object)>>"
    }
}
