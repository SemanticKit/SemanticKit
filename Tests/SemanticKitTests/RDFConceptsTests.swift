import Testing
@testable import SemanticKit

@Suite("RDF 1.2 Concepts", .tags(.concepts))
struct RDFConceptsTests {
    let subject = try! AnyRDFSubject(IRI(validating: "https://example.com/s"))
    let predicate = try! IRI(validating: "https://example.com/p")

    @Test("A graph holds a triple once and rejects a duplicate insert.")
    func graphIgnoresDuplicateTriples() throws {
        let object = AnyRDFObject(try Literal("o"))
        var graph = Graph()
        let triple = Graph.TripleType(subject: subject, predicate: predicate, object: object)
        try graph.insert(triple)

        #expect(throws: RDFGraphError.duplicateTriple) {
            try graph.insert(triple)
        }
        #expect(graph.triples.count == 1)
    }

    @Test("Blank nodes with different labels are distinct within a graph.")
    func blankNodesAreDistinctWithinGraph() throws {
        let b1 = try BlankNode("b1")
        let b2 = try BlankNode("b2")
        #expect(b1 != b2)

        let object = AnyRDFObject(try Literal("o"))
        var graph = Graph()
        try graph.insert(Graph.TripleType(subject: try AnyRDFSubject(b1), predicate: predicate, object: object))
        try graph.insert(Graph.TripleType(subject: try AnyRDFSubject(b2), predicate: predicate, object: object))

        #expect(graph.triples.count == 2)
    }

    @Test("A language-tagged literal and a typed literal with the same lexical form are distinct.")
    func literalsWithLanguageAndDatatypeAreDistinct() throws {
        let langLiteral = AnyRDFObject(try Literal("same", languageTag: "en"))
        let datatypeLiteral = AnyRDFObject(try Literal(
            "same",
            datatype: IRI(validating: "http://www.w3.org/2001/XMLSchema#string")
        ))
        #expect(langLiteral != datatypeLiteral)

        var graph = Graph()
        try graph.insert(Graph.TripleType(subject: subject, predicate: predicate, object: langLiteral))
        try graph.insert(Graph.TripleType(subject: subject, predicate: predicate, object: datatypeLiteral))

        #expect(graph.triples.count == 2)
    }

    @Test("A directional language-tagged literal prints its direction.")
    func literalWithDirectionFormats() throws {
        let directed = try Literal("hello", languageTag: "en", textDirection: .ltr)
        #expect(directed.description == "\"hello\"@en--ltr")

        let undirected = try Literal("hello", languageTag: "en")
        #expect(undirected.description == "\"hello\"@en")
    }
}
