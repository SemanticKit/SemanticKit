import Foundation
import Testing
@testable import SemanticKit

@Test func iriRejectsMissingScheme() async throws {
    do {
        _ = try ConcreteIri("example.com/path")
        #expect(Bool(false), "Expected missing scheme to throw.")
    } catch {
        #expect(Bool(true))
    }
}

@Test func iriRejectsInvalidScheme() async throws {
    do {
        _ = try ConcreteIri("1http://example.com")
        #expect(Bool(false), "Expected invalid scheme to throw.")
    } catch {
        #expect(Bool(true))
    }
}

@Test func iriPercentEncodesUnicodeInString() async throws {
    let iri = try ConcreteIri("https://ex\u{00E4}mple.com/\u{8DEF}\u{5F84}")
    #expect(iri.string.contains("%"))
    #expect(!iri.string.contains("\u{00E4}"))
    #expect(!iri.string.contains("\u{8DEF}\u{5F84}"))
}

@Test func iriAsURLUsesEncodedString() async throws {
    let iri = try ConcreteIri("https://ex\u{00E4}mple.com/\u{8DEF}\u{5F84}")
    let url = try iri.asURL()
    #expect(url.absoluteString == iri.string)
}
