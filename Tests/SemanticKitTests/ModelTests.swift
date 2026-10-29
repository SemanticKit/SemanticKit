import Testing
import SemanticKit

@Suite("SemanticKit is the umbrella import of the RDF model", .tags(.model))
struct ModelTests {
    @Test("Importing SemanticKit decodes Turtle into RDFCore's graph and writes it as N-Triples.")
    func decodesIntoRDFCore() throws {
        let graph: RDFCore.Graph = try TurtleDecoder().decode("""
            PREFIX : <https://example.com/>
            :s :p "שלום"@he--rtl, <<( :s :p :o )>> .
            """)
        let s: SubjectTerm = .iri("https://example.com/s")
        let p: IRI = "https://example.com/p"
        let inner = Graph.Element(subject: s, predicate: p, object: .iri("https://example.com/o"))

        #expect(graph == [
            Graph.Element(subject: s, predicate: p, object: .literal(try Literal("שלום", languageTag: "he", baseDirection: .rtl))),
            Graph.Element(subject: s, predicate: p, object: .tripleTerm(inner)),
        ])
        #expect(NTriplesEncoder().encode(graph) == """
            <https://example.com/s> <https://example.com/p> "שלום"@he--rtl .
            <https://example.com/s> <https://example.com/p> <<( <https://example.com/s> <https://example.com/p> <https://example.com/o> )>> .

            """)
    }

    @Test("A dataset from SemanticKit is RDFCore's dataset.")
    func datasetIsRDFCore() throws {
        let name: SubjectTerm = .iri("https://example.com/g")
        var dataset = RDFCore.Dataset()
        dataset[name].insert(Graph.Element(subject: name, predicate: "https://example.com/p", object: .literal(Literal("o"))))

        #expect(dataset.namedGraphs.keys.contains(name))
        #expect(dataset.defaultGraph.isEmpty)
    }
}
