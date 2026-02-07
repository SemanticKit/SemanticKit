import Testing
@testable import SemanticKit

@Test func turtleRoundTripParsesCoreForms() async throws {
    func ex(_ local: String) throws -> IRI {
        try IRI("https://example.com/ns#\(local)")
    }

    let turtle = """
    @base <https://example.com/> .
    @prefix ex: <https://example.com/ns#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

    ex:alice a ex:Person ;
        ex:age 42 ;
        ex:knows ex:bob , ex:carol ;
        ex:name "Alice"@en ;
        ex:height "1.70"^^xsd:decimal .

    [] ex:label "anon" .

    (ex:alice ex:bob) ex:linked ex:carol .
    """

    let graph = try Graph(turtle: turtle)

    let alice = try ex("alice")
    let person = try ex("Person")
    let age = try ex("age")
    let knows = try ex("knows")
    let name = try ex("name")
    let height = try ex("height")
    let label = try ex("label")
    let linked = try ex("linked")
    let bob = try ex("bob")
    let carol = try ex("carol")

    #expect(graph.contains(Graph.TripleType(
        subject: try AnyRDFSubject(alice),
        predicate: RDF.Vocabulary.type,
        object: AnyRDFObject(person)
    )))

    let xsdInteger = try IRI("http://www.w3.org/2001/XMLSchema#integer")
    let xsdDecimal = try IRI("http://www.w3.org/2001/XMLSchema#decimal")
    let ageLiteral = try Literal("42", datatype: xsdInteger)
    #expect(graph.contains(Graph.TripleType(
        subject: try AnyRDFSubject(alice),
        predicate: age,
        object: AnyRDFObject(ageLiteral)
    )))

    let heightLiteral = try Literal("1.70", datatype: xsdDecimal)
    #expect(graph.contains(Graph.TripleType(
        subject: try AnyRDFSubject(alice),
        predicate: height,
        object: AnyRDFObject(heightLiteral)
    )))

    let labelMatches = graph.match(
        subject: nil,
        predicate: label,
        object: AnyRDFObject(try Literal("anon"))
    )
    #expect(labelMatches.count == 1)

    let linkedTriples = graph.match(
        subject: nil,
        predicate: linked,
        object: AnyRDFObject(carol)
    )
    #expect(linkedTriples.count == 1)
    if let linkedTriple = linkedTriples.first {
        #expect(linkedTriple.subject.node is BlankNode)
    }

    let firstTriples = graph.match(
        subject: nil,
        predicate: RDF.Vocabulary.first,
        object: AnyRDFObject(alice)
    )
    #expect(firstTriples.count == 1)

    let output = graph.turtleString(prefixes: [
        "ex": try IRI("https://example.com/ns#"),
        "xsd": try IRI("http://www.w3.org/2001/XMLSchema#")
    ])
    #expect(output.contains("@prefix ex: <https://example.com/ns#> ."))
    #expect(output.contains("a ex:Person"))
    #expect(output.contains("ex:alice"))
}
