// Sources/SemanticKitRDF/Graph.swift
import Foundation
import IRIKit

// MARK: - RDFGraph ----------------------------------------------------------

/// An RDF *graph* is a set of triples that share a single name (the *graph IRI* or a *blank node*).
/// A **default graph** has `graphName == nil`.
public protocol RDFGraph: CustomStringConvertible {
    associatedtype TripleType: RDFTriple

    /// The (optional) name of the graph.  `nil` → default graph.
    var name: (any RDFNode)? { get }

    /// All triples currently stored in the graph.
    var triples: Set<TripleType> { get }

    // Core mutating API
    mutating func insert(_ triple: TripleType) throws
    mutating func remove(_ triple: TripleType) throws
    func contains(_ triple: TripleType) -> Bool

    // Pattern-matching (any of the three components may be `nil` → wildcard)
    func match(
        subject: TripleType.Subject?,
        predicate: TripleType.Predicate?,
        object: TripleType.Object?
    ) -> Set<TripleType>
}

// -------------------------------------------------------------------------

public enum RDFGraphError: Error, CustomStringConvertible {
    case invalidSubject
    case invalidPredicate
    case duplicateTriple

    public var description: String {
        switch self {
        case .invalidSubject:   return "Subject must be IRI or BlankNode"
        case .invalidPredicate: return "Predicate must be an absolute IRI"
        case .duplicateTriple:  return "Triple already present in the graph"
        }
    }
}

// MARK: - Default implementation ------------------------------------------------

extension RDFGraph {
    public func contains(_ triple: TripleType) -> Bool {
        triples.contains(triple)
    }

    public func match(
        subject: TripleType.Subject? = nil,
        predicate: TripleType.Predicate? = nil,
        object: TripleType.Object? = nil
    ) -> Set<TripleType> {
        triples.filter { t in
            (subject == nil || t.subject == subject!) &&
            (predicate == nil || t.predicate == predicate!) &&
            (object == nil || t.object == object!)
        }
    }

    public var description: String {
        var lines = triples.map(\.description).sorted()
        if let gName = name {
            lines = lines.map { "<\(gName)> {\n\($0)\n}" }
        }
        return lines.joined(separator: "\n")
    }
}

// -------------------------------------------------------------------------

/// The concrete, mutable implementation used by the library.
public struct Graph: RDFGraph, Hashable, Sendable {
    public typealias TripleType = Triple<AnyRDFSubject, AnyRDFObject>

    public let name: (any RDFNode)? // nil → default graph
    public private(set) var triples: Set<TripleType> = []

    // MARK: - Init

    /// Creates an (empty) default graph.
    public init() {
        self.name = nil
    }

    /// Creates an (empty) graph.
    /// - Parameter name: `nil` for the default graph; otherwise an IRI or a BlankNode.
    public init(name: (any RDFNode)?) throws {
        if let n = name {
            guard n is IRI || n is BlankNode else {
                throw RDFTermError.invalidGraphName
            }
        }
        self.name = name
    }

    // MARK: - Mutating API

    public mutating func insert(_ triple: TripleType) throws {
        // Validation according to §4.2.1-4.2.3 of the RFC
        let subjectNode = triple.subject.node
        guard subjectNode is IRI || subjectNode is BlankNode else {
            throw RDFGraphError.invalidSubject
        }
        guard !triples.contains(triple) else {
            throw RDFGraphError.duplicateTriple
        }
        triples.insert(triple)
    }

    public mutating func remove(_ triple: TripleType) throws {
        guard triples.remove(triple) != nil else {
            // silent no-op is fine per the spec – we just ignore it.
            return
        }
    }

    public static func == (lhs: Graph, rhs: Graph) -> Bool {
        let lhsName = lhs.name.map { AnyHashable($0) }
        let rhsName = rhs.name.map { AnyHashable($0) }
        return lhsName == rhsName && lhs.triples == rhs.triples
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name.map { AnyHashable($0) })
        hasher.combine(triples)
    }
}

// -------------------------------------------------------------------------

/// Helper concrete node types used by `Graph`.
/// They **do not** expose themselves publicly – they are internal building blocks.

/// A node that may appear as a subject (IRI or BlankNode).
extension IRI: RDFSubject {}
extension BlankNode: RDFSubject {}

/// A node that may appear as a predicate (always IRI).
extension IRI: RDFPredicate {}

/// A node that may appear as an object (IRI, BlankNode, or Literal).
extension IRI: RDFObject {}
extension BlankNode: RDFObject {}
extension Literal: RDFObject {}

/// Type-erased subject wrapper so graphs can store heterogeneous subjects.
public struct AnyRDFSubject: RDFSubject, Sendable {
    public let node: any RDFSubject

    public init(_ node: any RDFSubject) throws {
        guard node is IRI || node is BlankNode else {
            throw RDFTermError.invalidSubject
        }
        self.node = node
    }

    public var description: String { node.description }

    public static func == (lhs: AnyRDFSubject, rhs: AnyRDFSubject) -> Bool {
        AnyHashable(lhs.node) == AnyHashable(rhs.node)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(AnyHashable(node))
    }
}

/// Type-erased object wrapper so graphs can store heterogeneous objects.
public struct AnyRDFObject: RDFObject, Sendable {
    public let node: any RDFObject

    public init(_ node: any RDFObject) {
        self.node = node
    }

    public var description: String { node.description }

    public static func == (lhs: AnyRDFObject, rhs: AnyRDFObject) -> Bool {
        AnyHashable(lhs.node) == AnyHashable(rhs.node)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(AnyHashable(node))
    }
}
