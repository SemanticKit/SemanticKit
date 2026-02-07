import Testing
@testable import SemanticKit

@Test func ntriplesParsesGraphWithTripleTerms() async throws {
    let ntriples = """
    VERSION "1.2"
    <https://example.com/s> <https://example.com/p> "hello"@en--ltr .
    <https://example.com/s> <https://example.com/p> <<( <https://example.com/a> <https://example.com/b> "c" )>> .
    """

    let graph = try Graph(ntriples: ntriples)

    let s = try IRI("https://example.com/s")
    let p = try IRI("https://example.com/p")
    let a = try IRI("https://example.com/a")
    let b = try IRI("https://example.com/b")

    let subject = try AnyRDFSubject(s)
    let literal = try Literal("hello", languageTag: "en", textDirection: .ltr)

    #expect(graph.contains(Graph.TripleType(
        subject: subject,
        predicate: p,
        object: AnyRDFObject(literal)
    )))

    let tripleTerm = TripleTerm(
        subject: try AnyRDFSubject(a),
        predicate: b,
        object: AnyRDFObject(try Literal("c"))
    )

    #expect(graph.contains(Graph.TripleType(
        subject: subject,
        predicate: p,
        object: AnyRDFObject(tripleTerm)
    )))
}

@Test func ntriplesSerializesGraph() async throws {
    let s = try IRI("https://example.com/s")
    let p = try IRI("https://example.com/p")

    let subject = try AnyRDFSubject(s)
    let literal = try Literal("hello", languageTag: "en", textDirection: .rtl)

    var graph = Graph()
    try graph.insert(Graph.TripleType(
        subject: subject,
        predicate: p,
        object: AnyRDFObject(literal)
    ))

    let tripleTerm = TripleTerm(
        subject: subject,
        predicate: p,
        object: AnyRDFObject(try Literal("c"))
    )
    try graph.insert(Graph.TripleType(
        subject: subject,
        predicate: p,
        object: AnyRDFObject(tripleTerm)
    ))

    let output = graph.ntriplesString()

    #expect(output.contains("\"hello\"@en--rtl"))
    #expect(output.contains("<<( <https://example.com/s> <https://example.com/p> \"c\" )>>"))
}
