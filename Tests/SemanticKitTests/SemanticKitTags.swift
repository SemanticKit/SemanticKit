import Testing

extension Tag {
    /// Tests that SemanticKit gives RDFCore's RDF 1.2 model.
    @Tag static var model: Self

    /// Tests of IRIKit's `IRI` used as SemanticKit's identifier type.
    @Tag static var iri: Self
}
