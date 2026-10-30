import Testing
import SemanticKit

@Suite("SemanticKit is the umbrella import of the RDF model", .tags(.model))
struct ModelTests {
    @Test("Importing SemanticKit decodes Turtle into RDFCore's graph and writes it as N-Triples.")
    func decodesIntoRDFCore() throws {
        let graph: RDFCore.Graph = try Fixture.turtle("model.ttl")

        #expect(graph == (try Fixture.nTriples("model.nt")))
        #expect(NTriplesEncoder().encode(graph) == (try Fixture.text("model.nt")))
        #expect(graph.contains { triple in
            guard case .literal(let literal) = triple.object else { return false }
            return literal.languageTag == "he" && literal.baseDirection == .rtl
        })
        #expect(graph.contains { triple in
            guard case .tripleTerm = triple.object else { return false }
            return true
        })
    }

    @Test("A dataset from SemanticKit is RDFCore's dataset.")
    func datasetIsRDFCore() throws {
        let triple = try #require(try Fixture.turtle("model.ttl").first)
        let name = triple.subject
        var dataset = RDFCore.Dataset()
        dataset[name].insert(triple)

        #expect(dataset.namedGraphs == [name: [triple]])
        #expect(dataset.defaultGraph.isEmpty)
    }
}
