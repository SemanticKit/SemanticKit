import Testing
@testable import SemanticKit

@Test func rdfxmlParsesCoreForms() async throws {
    let xml = """
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
             xmlns:ex="http://example.org/ns#"
             xmlns:its="http://www.w3.org/2005/11/its">
      <rdf:Description rdf:about="http://example.org/thing">
        <ex:name xml:lang="en" its:dir="ltr">Thing</ex:name>
        <ex:link rdf:resource="http://example.org/other"/>
      </rdf:Description>
      <rdf:Description rdf:about="http://example.org/collection">
        <ex:hasItem rdf:parseType="Collection">
          <rdf:Description rdf:about="http://example.org/a"/>
          <rdf:Description rdf:about="http://example.org/b"/>
        </ex:hasItem>
      </rdf:Description>
      <rdf:Description rdf:about="http://example.org/subject">
        <ex:editor rdf:parseType="Resource">
          <ex:fullName>Editor</ex:fullName>
        </ex:editor>
      </rdf:Description>
      <rdf:Description rdf:about="http://example.org/annotated">
        <ex:prop rdf:annotation="http://example.org/reif">value</ex:prop>
      </rdf:Description>
      <rdf:Description rdf:about="http://example.org/termHolder">
        <ex:prop rdf:parseType="Triple">
          <rdf:Description rdf:about="http://example.org/s">
            <ex:p rdf:resource="http://example.org/o" />
          </rdf:Description>
        </ex:prop>
      </rdf:Description>
    </rdf:RDF>
    """

    let graph = try Graph(rdfxml: xml)

    let thing = try IRI("http://example.org/thing")
    let other = try IRI("http://example.org/other")
    let name = try IRI("http://example.org/ns#name")
    let link = try IRI("http://example.org/ns#link")

    let nameLiteral = try Literal("Thing", languageTag: "en", textDirection: .ltr)
    #expect(graph.contains(Graph.TripleType(
        subject: try AnyRDFSubject(thing),
        predicate: name,
        object: AnyRDFObject(nameLiteral)
    )))
    #expect(graph.contains(Graph.TripleType(
        subject: try AnyRDFSubject(thing),
        predicate: link,
        object: AnyRDFObject(other)
    )))

    let subject = try IRI("http://example.org/subject")
    let editor = try IRI("http://example.org/ns#editor")
    let fullName = try IRI("http://example.org/ns#fullName")
    let editorTriples = graph.match(
        subject: try AnyRDFSubject(subject),
        predicate: editor,
        object: nil
    )
    #expect(editorTriples.count == 1)
    if let triple = editorTriples.first, let blank = triple.object.node as? BlankNode {
        let editorName = try Literal("Editor")
        #expect(graph.contains(Graph.TripleType(
            subject: try AnyRDFSubject(blank),
            predicate: fullName,
            object: AnyRDFObject(editorName)
        )))
    } else {
        #expect(false, "Expected blank node for rdf:parseType=\"Resource\".")
    }

    let collection = try IRI("http://example.org/collection")
    let hasItem = try IRI("http://example.org/ns#hasItem")
    let items = graph.match(
        subject: try AnyRDFSubject(collection),
        predicate: hasItem,
        object: nil
    )
    #expect(items.count == 1)
    if let triple = items.first, let head = triple.object.node as? BlankNode {
        let a = try IRI("http://example.org/a")
        let b = try IRI("http://example.org/b")
        #expect(graph.contains(Graph.TripleType(
            subject: try AnyRDFSubject(head),
            predicate: RDF.Vocabulary.first,
            object: AnyRDFObject(a)
        )))
        let restTriples = graph.match(
            subject: try AnyRDFSubject(head),
            predicate: RDF.Vocabulary.rest,
            object: nil
        )
        #expect(restTriples.count == 1)
        if let rest = restTriples.first, let next = rest.object.node as? BlankNode {
            #expect(graph.contains(Graph.TripleType(
                subject: try AnyRDFSubject(next),
                predicate: RDF.Vocabulary.first,
                object: AnyRDFObject(b)
            )))
            #expect(graph.contains(Graph.TripleType(
                subject: try AnyRDFSubject(next),
                predicate: RDF.Vocabulary.rest,
                object: AnyRDFObject(RDF.Vocabulary.nilValue)
            )))
        }
    }

    let annotated = try IRI("http://example.org/annotated")
    let prop = try IRI("http://example.org/ns#prop")
    let annotationTriples = graph.match(
        subject: try AnyRDFSubject(annotated),
        predicate: prop,
        object: AnyRDFObject(try Literal("value"))
    )
    #expect(annotationTriples.count == 1)
    let reifier = try IRI("http://example.org/reif")
    let reifyMatches = graph.match(
        subject: try AnyRDFSubject(reifier),
        predicate: RDF.Vocabulary.reifies,
        object: nil
    )
    #expect(reifyMatches.count == 1)

    let termHolder = try IRI("http://example.org/termHolder")
    let termTriple = graph.triples.first { triple in
        triple.subject == (try? AnyRDFSubject(termHolder)) && triple.predicate == prop
    }
    #expect(termTriple != nil)
    if let termTriple, let tripleTerm = termTriple.object.node as? TripleTerm {
        #expect(tripleTerm.subject == (try? AnyRDFSubject(try IRI("http://example.org/s"))))
        #expect(tripleTerm.predicate == (try? IRI("http://example.org/ns#p")))
        #expect(tripleTerm.object == AnyRDFObject(try IRI("http://example.org/o")))
    } else {
        #expect(false, "Expected triple term object.")
    }
}
