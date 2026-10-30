import Foundation
import IRIKit
import Testing
@testable import SemanticKit

@Suite("IRIKit's IRI is SemanticKit's identifier type", .tags(.iri))
struct IRIBoundaryTests {
    @Test("The IRI that SemanticKit's terms carry is IRIKit's IRI.")
    func predicateIsIRIKitsIRI() throws {
        let predicate: IRIKit.IRI = try IRI(validating: "https://example.com/p")
        let triple = Graph.TripleType(
            subject: try AnyRDFSubject(IRI(validating: "https://example.com/s")),
            predicate: predicate,
            object: AnyRDFObject(try IRI(validating: "https://example.com/o"))
        )

        #expect(triple.predicate == predicate)
        #expect(triple.description == "https://example.com/s https://example.com/p https://example.com/o .")
    }

    @Test(
        "Text that is not an absolute IRI is rejected by IRIKit.",
        arguments: ["example.com/path", "1http://example.com", ""]
    )
    func rejectsNonIRIText(_ text: String) {
        #expect(throws: IRIError.invalidIRI(text)) {
            _ = try IRI(validating: text)
        }
    }

    @Test("A literal's datatype keeps its Unicode characters in N-Triples, which allows them in IRIREF.")
    func literalDatatypeKeepsUnicode() throws {
        // The IRI stays as written; mapping to URI form is the job of a
        // boundary that needs a URL.
        let datatype = try IRI(validating: "https://exämple.com/\u{8DEF}\u{5F84}")
        let literal = try Literal("1", datatype: datatype)

        #expect(literal.description == "\"1\"^^<https://exämple.com/\u{8DEF}\u{5F84}>")
    }

    @Test("A boundary that needs a URL maps the IRI to URI form with URL(_:).")
    func urlMappingHappensAtTheBoundary() throws {
        // The mapping happens only when a caller asks for a Foundation URL.
        let iri = try IRI(validating: "https://example.com/\u{8DEF}\u{5F84}")

        #expect(URL(iri).absoluteString == "https://example.com/%E8%B7%AF%E5%BE%84")
    }

    @Test("Literals compare datatypes by exact IRI text, as RDF term equality requires.")
    func literalDatatypeEqualityIsExact() throws {
        let lhs = try Literal("1", datatype: IRI(validating: "http://example.org/~t"))
        let same = try Literal("1", datatype: IRI(validating: "http://example.org/~t"))
        let encoded = try Literal("1", datatype: IRI(validating: "http://example.org/%7Et"))

        #expect(lhs == same)
        #expect(lhs.hashValue == same.hashValue)
        #expect(lhs != encoded)
    }

    @Test("A dataset writes its named graphs in IRI order.")
    func datasetOrdersNamedGraphsByIRI() throws {
        let a = try IRI(validating: "https://example.com/a")
        let b = try IRI(validating: "https://example.com/b")
        func graph(named name: IRI) throws -> Graph {
            var graph = try Graph(name: name)
            try graph.insert(Graph.TripleType(subject: try AnyRDFSubject(name), predicate: name, object: AnyRDFObject(name)))
            return graph
        }
        let dataset = Dataset(namedGraphs: [b: try graph(named: b), a: try graph(named: a)])

        #expect(dataset.description == """

            <https://example.com/a> {
            https://example.com/a https://example.com/a https://example.com/a .
            }
            <https://example.com/b> {
            https://example.com/b https://example.com/b https://example.com/b .
            }
            """)
    }
}
