import IRIKit

/// Adds a static `iri` that projects the annotated type to its IRI for use at
/// the I/O boundary. The string literal is validated as an absolute RFC 3987
/// IRI when the macro expands, so an invalid IRI is a compile-time error.
@attached(member, names: named(iri))
public macro IRI(_ value: String) = #externalMacro(module: "SemanticKitMacros", type: "IRIMacro")
