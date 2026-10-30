import Foundation
import IRIKit
import Testing
import SemanticKit

/// IRIKit's `IRI` as the identifier that SemanticKit's terms carry, checked
/// on IRIs decoded from fixtures. RFC 3987 conformance is tested in IRIKit.
@Suite("IRIKit's IRI is SemanticKit's identifier type", .tags(.iri))
struct IRIBoundaryTests {
    @Test("The IRI that SemanticKit's terms carry is IRIKit's IRI.")
    func predicateIsIRIKitsIRI() throws {
        let triple = try #require(try Fixture.turtle("model.ttl").first)
        let predicate: IRIKit.IRI = triple.predicate

        #expect(predicate.description == "https://example.com/p")
    }

    @Test("IRIs keep their Unicode characters through Turtle and N-Triples, which allow them in IRIREF.")
    func unicodeIRIsRoundTrip() throws {
        // RDF 1.2 Concepts compares IRIs character by character, with no
        // normalization or percent-encoding.
        let graph = try Fixture.turtle("unicode-iris.ttl")

        #expect(NTriplesEncoder().encode(graph) == (try Fixture.text("unicode-iris.nt")))
        #expect(try TurtleDecoder().decode(TurtleEncoder().encode(graph)).isIsomorphic(to: graph))
    }

    @Test("A boundary that needs a URL maps the IRI to URI form with URL(_:).")
    func urlMappingHappensAtTheBoundary() throws {
        let graph = try Fixture.turtle("unicode-iris.ttl")
        let iri = try #require(graph.compactMap { triple -> IRI? in
            guard case .iri(let iri) = triple.object else { return nil }
            return iri
        }.first)

        #expect(URL(iri).absoluteString == "https://example.com/%E8%B7%AF%E5%BE%84")
    }
}
