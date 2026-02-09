import Testing
@testable import SemanticKit

@Test func owlFunctionalSyntaxParsesBasicAxioms() async throws {
    let text = """
    Prefix(:=<http://example.com#>)
    Prefix(owl:=<http://www.w3.org/2002/07/owl#>)
    Prefix(rdfs:=<http://www.w3.org/2000/01/rdf-schema#>)
    Prefix(xsd:=<http://www.w3.org/2001/XMLSchema#>)
    Ontology(
        Declaration(Class(:Person))
        Declaration(NamedIndividual(:Alice))
        Declaration(ObjectProperty(:knows))
        Declaration(DataProperty(:age))
        SubClassOf(:Person owl:Thing)
        ClassAssertion(:Person :Alice)
        ObjectPropertyAssertion(:knows :Alice :Bob)
        DataPropertyAssertion(:age :Alice "42"^^xsd:integer)
        AnnotationAssertion(rdfs:label :Person "Person"@en)
    )
    """

    let graph = try Graph(owlFunctionalSyntax: text)
    let person = try IRI("http://example.com#Person")
    let alice = try IRI("http://example.com#Alice")
    let bob = try IRI("http://example.com#Bob")
    let knows = try IRI("http://example.com#knows")
    let age = try IRI("http://example.com#age")
    let label = try IRI("http://www.w3.org/2000/01/rdf-schema#label")
    let integer = try IRI("http://www.w3.org/2001/XMLSchema#integer")

    #expect(graph.contains(Graph.TripleType(
        subject: try AnyRDFSubject(person),
        predicate: RDF.Vocabulary.type,
        object: AnyRDFObject(OWL.Vocabulary.Class)
    )))

    #expect(graph.contains(Graph.TripleType(
        subject: try AnyRDFSubject(person),
        predicate: RDF.RDFS.subClassOf,
        object: AnyRDFObject(OWL.Vocabulary.Thing)
    )))

    #expect(graph.contains(Graph.TripleType(
        subject: try AnyRDFSubject(alice),
        predicate: RDF.Vocabulary.type,
        object: AnyRDFObject(person)
    )))

    #expect(graph.contains(Graph.TripleType(
        subject: try AnyRDFSubject(alice),
        predicate: knows,
        object: AnyRDFObject(bob)
    )))

    #expect(graph.contains(Graph.TripleType(
        subject: try AnyRDFSubject(alice),
        predicate: age,
        object: AnyRDFObject(try Literal("42", datatype: integer))
    )))

    #expect(graph.contains(Graph.TripleType(
        subject: try AnyRDFSubject(person),
        predicate: label,
        object: AnyRDFObject(try Literal("Person", languageTag: "en"))
    )))
}
