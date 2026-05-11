import Foundation

@attached(member, names: named(iri))
public macro IRI(_ value: String) = #externalMacro(module: "SemanticKitMacros", type: "IRIMacro")
