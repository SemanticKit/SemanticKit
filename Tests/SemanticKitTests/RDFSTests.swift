import Testing
@testable import SemanticKit

@Test func rdfsClosureDerivesExpectedTriples() async throws {
    func ex(_ local: String) throws -> IRI {
        try IRI("https://example.com/\(local)")
    }

    let parent = try ex("parent")
    let ancestor = try ex("ancestor")
    let child = try ex("child")
    let person = try ex("Person")
    let agent = try ex("Agent")
    let worksFor = try ex("worksFor")
    let organization = try ex("Organization")
    let org1 = try ex("Org1")
    let containerMember = try ex("memberProp")
    let item1 = try ex("item1")
    let customDatatype = try ex("CustomDatatype")

    var graph = Graph()

    let triples: [Graph.TripleType] = [
        Graph.TripleType(
            subject: try AnyRDFSubject(parent),
            predicate: RDF.RDFS.subPropertyOf,
            object: AnyRDFObject(ancestor)
        ),
        Graph.TripleType(
            subject: try AnyRDFSubject(child),
            predicate: parent,
            object: AnyRDFObject(org1)
        ),
        Graph.TripleType(
            subject: try AnyRDFSubject(person),
            predicate: RDF.RDFS.subClassOf,
            object: AnyRDFObject(agent)
        ),
        Graph.TripleType(
            subject: try AnyRDFSubject(child),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(person)
        ),
        Graph.TripleType(
            subject: try AnyRDFSubject(worksFor),
            predicate: RDF.RDFS.domain,
            object: AnyRDFObject(person)
        ),
        Graph.TripleType(
            subject: try AnyRDFSubject(worksFor),
            predicate: RDF.RDFS.range,
            object: AnyRDFObject(organization)
        ),
        Graph.TripleType(
            subject: try AnyRDFSubject(child),
            predicate: worksFor,
            object: AnyRDFObject(org1)
        ),
        Graph.TripleType(
            subject: try AnyRDFSubject(containerMember),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(RDF.RDFS.ContainerMembershipProperty)
        ),
        Graph.TripleType(
            subject: try AnyRDFSubject(child),
            predicate: containerMember,
            object: AnyRDFObject(item1)
        ),
        Graph.TripleType(
            subject: try AnyRDFSubject(customDatatype),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(RDF.RDFS.Datatype)
        )
    ]

    for triple in triples {
        try graph.insert(triple)
    }

    let closure = graph.rdfsClosure()

    #expect(closure.contains(
        Graph.TripleType(
            subject: try AnyRDFSubject(child),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(agent)
        )
    ))

    #expect(closure.contains(
        Graph.TripleType(
            subject: try AnyRDFSubject(org1),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(organization)
        )
    ))

    #expect(closure.contains(
        Graph.TripleType(
            subject: try AnyRDFSubject(parent),
            predicate: RDF.RDFS.subPropertyOf,
            object: AnyRDFObject(ancestor)
        )
    ))

    #expect(closure.contains(
        Graph.TripleType(
            subject: try AnyRDFSubject(child),
            predicate: ancestor,
            object: AnyRDFObject(org1)
        )
    ))

    #expect(closure.contains(
        Graph.TripleType(
            subject: try AnyRDFSubject(child),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(RDF.RDFS.Resource)
        )
    ))

    #expect(closure.contains(
        Graph.TripleType(
            subject: try AnyRDFSubject(org1),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(RDF.RDFS.Resource)
        )
    ))

    #expect(closure.contains(
        Graph.TripleType(
            subject: try AnyRDFSubject(containerMember),
            predicate: RDF.RDFS.subPropertyOf,
            object: AnyRDFObject(RDF.RDFS.member)
        )
    ))

    #expect(closure.contains(
        Graph.TripleType(
            subject: try AnyRDFSubject(child),
            predicate: RDF.RDFS.member,
            object: AnyRDFObject(item1)
        )
    ))

    #expect(closure.contains(
        Graph.TripleType(
            subject: try AnyRDFSubject(customDatatype),
            predicate: RDF.RDFS.subClassOf,
            object: AnyRDFObject(RDF.RDFS.Literal)
        )
    ))
}
