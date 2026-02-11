import Testing
@testable import SemanticKit

@Test func literalWithDirectionFormats() async throws {
    let directed = try Literal("hello", languageTag: "en", textDirection: .ltr)
    #expect(directed.description == "\"hello\"@en--ltr")

    let undirected = try Literal("hello", languageTag: "en")
    #expect(undirected.description == "\"hello\"@en")
}
