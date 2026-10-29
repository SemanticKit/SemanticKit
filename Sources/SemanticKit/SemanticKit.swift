// SemanticKit is the umbrella import of the SemanticKit stack. It holds no
// RDF model of its own: `import SemanticKit` gives IRIKit's `IRI`, RDFCore's
// RDF 1.2 model (`BlankNode`, `Literal`, `Triple`, `Graph`, `Dataset`),
// RDFKit's DSL and vocabularies, and RDFFormats' decoders and encoders.
@_exported import IRIKit
@_exported import RDFCore
@_exported import RDFFormats
@_exported import RDFKit
