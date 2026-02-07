import Foundation
import SwiftUI
import SemanticKit

@main
struct SemanticKitGraphViewerApp: App {
    private let graph: Graph = SampleGraphBuilder.make()

    var body: some Scene {
        WindowGroup {
            GraphSidebarView(graph: graph)
        }
    }
}

private enum SampleGraphBuilder {
    static func make() -> Graph {
        var graph = Graph()

        guard
            let alice = try? IRI(iriString: "https://example.com/alice"),
            let knows = try? IRI(iriString: "https://example.com/knows"),
            let name = try? IRI(iriString: "https://schema.org/name"),
            let age = try? IRI(iriString: "https://schema.org/age"),
            let rdfType = try? IRI(iriString: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"),
            let schemaPerson = try? IRI(iriString: "https://schema.org/Person"),
            let xsdInteger = try? IRI(iriString: "http://www.w3.org/2001/XMLSchema#integer")
        else {
            return graph
        }

        let bob = BlankNode("b1")
        let aliceName = Literal("Alice", languageTag: "en")
        let aliceAge = Literal("29", datatype: xsdInteger)

        let triples = [
            Triple(subject: AnyRDFSubject(alice), predicate: rdfType, object: AnyRDFObject(schemaPerson)),
            Triple(subject: AnyRDFSubject(alice), predicate: knows, object: AnyRDFObject(bob)),
            Triple(subject: AnyRDFSubject(alice), predicate: name, object: AnyRDFObject(aliceName)),
            Triple(subject: AnyRDFSubject(alice), predicate: age, object: AnyRDFObject(aliceAge))
        ]

        for triple in triples {
            try? graph.insert(triple)
        }

        return graph
    }
}
