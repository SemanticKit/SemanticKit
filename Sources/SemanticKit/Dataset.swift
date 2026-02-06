// Sources/SemanticKitRDF/Dataset.swift
import Foundation

// MARK: - RDFDataset ---------------------------------------------------------

/// A *dataset* is a collection of named graphs plus one default graph.
/// The dataset itself is immutable from the public API – mutations are performed
/// via `mutating` methods that return a **new** dataset (value‑type semantics).
public protocol RDFDataset: Hashable, CustomStringConvertible {
    associatedtype GraphType: RDFGraph & Hashable

    /// The default graph (graphName == nil).
    var defaultGraph: GraphType { get }

    /// All named graphs indexed by their (absolute) IRI name.
    var namedGraphs: [IRI: GraphType] { get }

    // Core operations
    func graph(named name: IRI) -> GraphType?
    func graph(_ name: IRI?) -> GraphType?

    // Produces a new dataset with an added (or replaced) graph.
    func inserting(_ graph: GraphType) throws -> Self

    // Produces a new dataset with a graph removed.
    func removing(graph name: IRI) -> Self
}

// -------------------------------------------------------------------------

public enum RDFDatasetError: Error, CustomStringConvertible {
    case duplicateGraphName
    case invalidGraphName

    public var description: String {
        switch self {
        case .duplicateGraphName: return "A graph with that name already exists"
        case .invalidGraphName:   return "Graph name must be an absolute IRI"
        }
    }
}

// MARK: - Default implementation

extension RDFDataset {
    public func graph(named name: IRI) -> GraphType? {
        namedGraphs[name]
    }

    public func graph(_ name: IRI?) -> GraphType? {
        if let n = name {
            return namedGraphs[n]
        } else {
            return defaultGraph
        }
    }

    public func contains(_ triple: GraphType.TripleType) -> Bool {
        // Look in default graph first, then in each named graph.
        if defaultGraph.contains(triple) { return true }
        for g in namedGraphs.values where g.contains(triple) {
            return true
        }
        return false
    }

    public var description: String {
        var lines: [String] = []
        lines.append(defaultGraph.description)
        for (_, g) in namedGraphs.sorted(by: { $0.key.string < $1.key.string }) {
            lines.append(g.description)
        }
        return lines.joined(separator: "\n")
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.defaultGraph == rhs.defaultGraph &&
        lhs.namedGraphs == rhs.namedGraphs
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(defaultGraph)
        hasher.combine(namedGraphs)
    }
}

// -------------------------------------------------------------------------

public struct Dataset: RDFDataset {
    public typealias GraphType = Graph

    public let defaultGraph: Graph
    public let namedGraphs: [IRI: Graph]

    // MARK: – Init

    /// Creates a dataset from a default graph and an optional collection of named graphs.
    public init(defaultGraph: Graph = Graph(),
                namedGraphs: [IRI: Graph] = [:]) {
        self.defaultGraph = defaultGraph
        self.namedGraphs = namedGraphs
    }

    // MARK: – Mutating style (returns a new dataset)

    public func inserting(_ graph: Graph) throws -> Dataset {
        var newNamed = namedGraphs
        if let gName = graph.name as? IRI {
            guard newNamed[gName] == nil else {
                throw RDFDatasetError.duplicateGraphName
            }
            newNamed[gName] = graph
        } else {
            // default graph replacement
            var newDefault = graph
            // merge with existing default graph to keep value-type semantics
            for triple in defaultGraph.triples where !newDefault.triples.contains(triple) {
                try? newDefault.insert(triple)
            }
            return Dataset(defaultGraph: newDefault, namedGraphs: newNamed)
        }
        return Dataset(defaultGraph: defaultGraph, namedGraphs: newNamed)
    }

    public func removing(graph name: IRI) -> Dataset {
        var newNamed = namedGraphs

        newNamed.removeValue(forKey: name)
        return Dataset(defaultGraph: defaultGraph, namedGraphs: newNamed)
    }
}

// MARK: - Dataset merge (RDF 1.2 Semantics §10)

public extension Dataset {
    func merged(with other: Dataset) -> Dataset {
        Dataset.merged([self, other])
    }

    static func merged(_ datasets: [Dataset]) -> Dataset {
        guard !datasets.isEmpty else { return Dataset() }
        var mergedDefault = Graph()
        var mergedNamed: [IRI: Graph] = [:]

        for (index, dataset) in datasets.enumerated() {
            let remapped = dataset.remappingBlankNodes(prefix: "ds\(index)_")
            mergedDefault = mergedDefault.merging(with: remapped.defaultGraph)
            for (name, graph) in remapped.namedGraphs {
                if let existing = mergedNamed[name] {
                    mergedNamed[name] = existing.merging(with: graph)
                } else {
                    mergedNamed[name] = graph
                }
            }
        }

        return Dataset(defaultGraph: mergedDefault, namedGraphs: mergedNamed)
    }
}

private extension Dataset {
    func remappingBlankNodes(prefix: String) -> Dataset {
        var mapping: [String: BlankNode] = [:]
        let newDefault = defaultGraph.remappingBlankNodes(using: &mapping, prefix: prefix)
        var newNamed: [IRI: Graph] = [:]

        for (name, graph) in namedGraphs {
            newNamed[name] = graph.remappingBlankNodes(using: &mapping, prefix: prefix)
        }

        return Dataset(defaultGraph: newDefault, namedGraphs: newNamed)
    }
}

private extension Graph {
    func remappingBlankNodes(using mapping: inout [String: BlankNode], prefix: String) -> Graph {
        var newGraph = Graph(name: name)

        for triple in triples {
            let newSubject = remapSubject(triple.subject, mapping: &mapping, prefix: prefix)
            let newObject = remapObject(triple.object, mapping: &mapping, prefix: prefix)
            let newTriple = Graph.TripleType(
                subject: newSubject,
                predicate: triple.predicate,
                object: newObject
            )
            try? newGraph.insert(newTriple)
        }

        return newGraph
    }

    func merging(with other: Graph) -> Graph {
        var merged = self
        for triple in other.triples {
            if !merged.contains(triple) {
                try? merged.insert(triple)
            }
        }
        return merged
    }
}

private func remapSubject(
    _ subject: AnyRDFSubject,
    mapping: inout [String: BlankNode],
    prefix: String
) -> AnyRDFSubject {
    if let blank = subject.node as? BlankNode {
        return AnyRDFSubject(remapBlank(blank, mapping: &mapping, prefix: prefix))
    }
    return subject
}

private func remapObject(
    _ object: AnyRDFObject,
    mapping: inout [String: BlankNode],
    prefix: String
) -> AnyRDFObject {
    if let blank = object.node as? BlankNode {
        return AnyRDFObject(remapBlank(blank, mapping: &mapping, prefix: prefix))
    }
    return object
}

private func remapBlank(
    _ blank: BlankNode,
    mapping: inout [String: BlankNode],
    prefix: String
) -> BlankNode {
    if let existing = mapping[blank.identifier] {
        return existing
    }
    let remapped = BlankNode("\(prefix)\(blank.identifier)")
    mapping[blank.identifier] = remapped
    return remapped
}
