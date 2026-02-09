import Testing
@testable import SemanticKit

@Test func owlFunctionalSyntaxParsesAdvancedAxioms() async throws {
    let text = """
    Prefix(:=<http://example.com#>)
    Prefix(owl:=<http://www.w3.org/2002/07/owl#>)
    Prefix(rdfs:=<http://www.w3.org/2000/01/rdf-schema#>)
    Prefix(xsd:=<http://www.w3.org/2001/XMLSchema#>)
    Ontology(
        Declaration(Class(:Person))
        Declaration(Class(:Employee))
        Declaration(ObjectProperty(:manages))
        Declaration(DataProperty(:age))
        Declaration(NamedIndividual(:Alice))
        Declaration(NamedIndividual(:Bob))
        DisjointClasses(:Person :Employee :Manager)
        DisjointUnion(:Role :Employee :Manager)
        SubObjectPropertyOf(ObjectPropertyChain(:manages :manages) :manages)
        ObjectPropertyDomain(:manages :Person)
        ObjectPropertyRange(:manages :Person)
        InverseObjectProperties(:manages ObjectInverseOf(:managedBy))
        FunctionalObjectProperty(:manages)
        SubDataPropertyOf(:age :age)
        DataPropertyRange(:age DataUnionOf(xsd:integer xsd:decimal))
        DatatypeDefinition(:SmallInt DatatypeRestriction(xsd:integer xsd:maxInclusive "10"^^xsd:integer))
        HasKey(:Person (:manages) (:age))
        SameIndividual(:Alice :Bob)
        DifferentIndividuals(:Alice :Bob :Charlie)
        ClassAssertion(ObjectIntersectionOf(:Person :Employee) :Alice)
        ObjectPropertyAssertion(ObjectInverseOf(:manages) :Alice :Bob)
        NegativeObjectPropertyAssertion(:manages :Alice :Bob)
        DataPropertyAssertion(:age :Alice "42"^^xsd:integer)
        NegativeDataPropertyAssertion(:age :Alice "43"^^xsd:integer)
        AnnotationAssertion(rdfs:label :Person "Person"@en)
    )
    """

    let graph = try Graph(owlFunctionalSyntax: text)
    let person = try IRI("http://example.com#Person")
    let employee = try IRI("http://example.com#Employee")
    let manages = try IRI("http://example.com#manages")
    let alice = try IRI("http://example.com#Alice")
    let bob = try IRI("http://example.com#Bob")
    let label = try IRI("http://www.w3.org/2000/01/rdf-schema#label")

    #expect(graph.contains(Graph.TripleType(
        subject: try AnyRDFSubject(manages),
        predicate: RDF.RDFS.domain,
        object: AnyRDFObject(person)
    )))

    #expect(graph.contains(Graph.TripleType(
        subject: try AnyRDFSubject(person),
        predicate: OWL.Vocabulary.disjointWith,
        object: AnyRDFObject(employee)
    )) || graph.triples.contains { $0.predicate == OWL.Vocabulary.members })

    #expect(graph.contains(Graph.TripleType(
        subject: try AnyRDFSubject(bob),
        predicate: manages,
        object: AnyRDFObject(alice)
    )))

    #expect(graph.contains(Graph.TripleType(
        subject: try AnyRDFSubject(person),
        predicate: label,
        object: AnyRDFObject(try Literal("Person", languageTag: "en"))
    )))
}
