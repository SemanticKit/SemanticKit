// SemanticKit uses IRIKit's `IRI` as its one identifier type at the I/O
// boundary. Re-exporting IRIKit lets code that imports SemanticKit name
// `IRI` without a second import.
@_exported import IRIKit
