import Testing
@testable import SemanticKit

@Test func literalWithDirectionFormats() async throws {
    let directed = try Literal("hello", languageTag: "en", textDirection: .ltr)
    #expect(directed.description == "\"hello\"@en--ltr")

    let undirected = try Literal("hello", languageTag: "en")
    #expect(undirected.description == "\"hello\"@en")
}

@Test func reifiedTripleExpansionIncludesAssertionAndAnnotations() async throws {
    let subject = try IRI("https://example.com/subject")
    let predicate = try IRI("https://example.com/predicate")
    let object = try IRI("https://example.com/object")

    let subjectRef = try AnyRDFSubject(subject)
    let triple = Graph.TripleType(
        subject: subjectRef,
        predicate: predicate,
        object: AnyRDFObject(object)
    )

    let reifier = try AnyRDFSubject(try BlankNode("reifier1"))
    let tripleTerm = TripleTerm(subject: triple.subject, predicate: triple.predicate, object: triple.object)

    let reified = ReifiedTriple(
        reifier: reifier,
        tripleTerm: tripleTerm,
        asserted: true,
        annotations: [
            PredicateObjectPair(
                predicate: RDF.Vocabulary.type,
                object: AnyRDFObject(RDF.RDFS.Proposition)
            )
        ]
    )

    let expanded = reified.expandedTriples()

    #expect(expanded.contains(triple))
    #expect(expanded.contains(
        Graph.TripleType(
            subject: reifier,
            predicate: RDF.Vocabulary.reifies,
            object: AnyRDFObject(tripleTerm)
        )
    ))
    #expect(expanded.contains(
        Graph.TripleType(
            subject: reifier,
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(RDF.RDFS.Proposition)
        )
    ))
}
