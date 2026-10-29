import IRIKit
import SemanticKitMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing
@testable import SemanticKit

@IRI("https://example.org/vocab#Thing")
private struct Thing {}

@Suite("@IRI macro", .tags(.macro, .iri))
struct IRIMacroTests {
    private let macros: [String: MacroSpec] = ["IRI": MacroSpec(type: IRIMacro.self)]

    private func failure(_ spec: TestFailureSpec) {
        Issue.record(
            Comment(rawValue: spec.message),
            sourceLocation: SourceLocation(
                fileID: spec.location.fileID,
                filePath: spec.location.filePath,
                line: spec.location.line,
                column: spec.location.column
            )
        )
    }

    @Test("The projected iri is IRIKit's IRI with the literal's text.")
    func projectsIRIKitIRI() throws {
        let iri: IRIKit.IRI = Thing.iri

        #expect(iri == (try IRI(validating: "https://example.org/vocab#Thing")))
    }

    @Test("A valid literal expands to a static IRIKit.IRI.")
    func expandsToTypedIRI() {
        assertMacroExpansion(
            """
            @IRI("https://example.org/vocab#Thing")
            struct Thing {}
            """,
            expandedSource: """
            struct Thing {

                public static let iri: IRIKit.IRI = "https://example.org/vocab#Thing"
            }
            """,
            macroSpecs: macros,
            failureHandler: failure
        )
    }

    @Test(
        "Text that is not an absolute IRI is a compile-time error.",
        arguments: ["vocab#Thing", "https://example.org/with space"]
    )
    func rejectsInvalidIRI(_ text: String) {
        assertMacroExpansion(
            """
            @IRI("\(text)")
            struct Thing {}
            """,
            expandedSource: """
            struct Thing {}
            """,
            diagnostics: [
                DiagnosticSpec(message: "@IRI requires an absolute IRI; \"\(text)\" is not one.", line: 1, column: 1)
            ],
            macroSpecs: macros,
            failureHandler: failure
        )
    }
}
