import Foundation

public struct PredicateObjectPair: Hashable {
    public let predicate: IRI
    public let object: AnyRDFObject

    public init(predicate: IRI, object: AnyRDFObject) {
        self.predicate = predicate
        self.object = object
    }
}

/// Represents a reified triple term with optional assertion and annotations.
public struct ReifiedTriple: Hashable {
    public let reifier: AnyRDFSubject
    public let tripleTerm: TripleTerm
    public let asserted: Bool
    public let annotations: [PredicateObjectPair]

    public init(
        reifier: AnyRDFSubject,
        tripleTerm: TripleTerm,
        asserted: Bool = false,
        annotations: [PredicateObjectPair] = []
    ) {
        self.reifier = reifier
        self.tripleTerm = tripleTerm
        self.asserted = asserted
        self.annotations = annotations
    }

    public init(
        reifier: AnyRDFSubject,
        triple: Graph.TripleType,
        asserted: Bool = false,
        annotations: [PredicateObjectPair] = []
    ) {
        self.init(
            reifier: reifier,
            tripleTerm: TripleTerm(subject: triple.subject, predicate: triple.predicate, object: triple.object),
            asserted: asserted,
            annotations: annotations
        )
    }

    public func expandedTriples() -> [Graph.TripleType] {
        var result: [Graph.TripleType] = []

        if asserted {
            result.append(
                Graph.TripleType(
                    subject: tripleTerm.subject,
                    predicate: tripleTerm.predicate,
                    object: tripleTerm.object
                )
            )
        }

        result.append(
            Graph.TripleType(
                subject: reifier,
                predicate: RDF.Vocabulary.reifies,
                object: AnyRDFObject(tripleTerm)
            )
        )

        for annotation in annotations {
            result.append(
                Graph.TripleType(
                    subject: reifier,
                    predicate: annotation.predicate,
                    object: annotation.object
                )
            )
        }

        return result
    }
}

public extension Graph {
    mutating func insert(_ reified: ReifiedTriple) throws {
        for triple in reified.expandedTriples() {
            try insert(triple)
        }
    }
}
