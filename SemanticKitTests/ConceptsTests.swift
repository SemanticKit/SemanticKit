import Testing
@testable import SemanticKit

@Test func graphIgnoresDuplicateTriples() async throws {
    let subject = try AnyRDFSubject(IRI("https://example.com/s"))
    let predicate = try IRI("https://example.com/p")
    let object = try AnyRDFObject(Literal("o"))

    var graph = Graph()
    let triple = Graph.TripleType(subject: subject, predicate: predicate, object: object)
    try graph.insert(triple)
    do {
        try graph.insert(triple)
        #expect(Bool(false), "Expected duplicate triple insertion to throw.")
    } catch {
        #expect(Bool(true))
    }

    #expect(graph.triples.count == 1)
}

@Test func blankNodesAreDistinctWithinGraph() async throws {
    let b1 = try BlankNode("b1")
    let b2 = try BlankNode("b2")
    #expect(b1 != b2)

    let predicate = try IRI("https://example.com/p")
    let object = try AnyRDFObject(Literal("o"))
    var graph = Graph()
    try graph.insert(Graph.TripleType(subject: try AnyRDFSubject(b1), predicate: predicate, object: object))
    try graph.insert(Graph.TripleType(subject: try AnyRDFSubject(b2), predicate: predicate, object: object))

    #expect(graph.triples.count == 2)
}

@Test func literalsWithLanguageAndDatatypeAreDistinct() async throws {
    let subject = try AnyRDFSubject(IRI("https://example.com/s"))
    let predicate = try IRI("https://example.com/p")
    let langLiteral = try AnyRDFObject(Literal("same", languageTag: "en"))
    let datatypeLiteral = try AnyRDFObject(Literal("same", datatype: IRI("http://www.w3.org/2001/XMLSchema#string")))

    #expect(langLiteral != datatypeLiteral)

    var graph = Graph()
    try graph.insert(Graph.TripleType(subject: subject, predicate: predicate, object: langLiteral))
    try graph.insert(Graph.TripleType(subject: subject, predicate: predicate, object: datatypeLiteral))

    #expect(graph.triples.count == 2)
}
