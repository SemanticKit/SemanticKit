# RFC Test Checklist (SemanticKit)

This checklist tracks test coverage against the RFC/spec PDFs in `Sources/SemanticKit/RFCs/`. Items are grouped by document and marked as:
- [ ] Planned
- [x] Implemented + passing
- [~] Not implemented in library (documented gap)

## RDF 1.2 Concepts and Abstract Data Model
- [x] Graph uniqueness: duplicate triples are ignored on insert
- [x] Blank nodes treated as distinct identifiers within a graph
- [x] RDF literals with language tag and datatype are distinct
- [x] Triple term object support (RDF 1.2) round-trip in parsers/serializers that support it

## RDF 1.2 N-Triples
- [x] Parse simple IRIs, blank nodes, and literals with language tags
- [x] Reject unescaped newline in string literal
- [x] Accept escaped Unicode (\uXXXX / \UXXXXXXXX)
- [x] Enforce valid blank node labels
- [x] Parse and ignore VERSION directive
- [x] Language tags must be BCP47-like (reject invalid)

## RDF 1.2 N-Quads
- [x] Parse default graph triples and named graph quads
- [x] Reject non-IRI graph names (blank nodes)
- [x] Accept escaped Unicode in literals and IRIs
- [x] Parse and ignore VERSION directive

## RDF 1.2 Turtle
- [x] Prefix/base directives resolve prefixed names and relative IRIs
- [x] Collection syntax generates rdf:first/rest list
- [x] Blank node property lists
- [x] Language tags with text direction (e.g., "@en--ltr")
- [x] Triple term syntax (<< s p o >>) as object

## RDF 1.2 TriG
- [~] TriG parser/serializer not present in library

## RDF 1.2 RDF/XML Syntax
- [x] xml:lang with its:dir produces language literal with text direction
- [x] rdf:parseType="Collection" produces list structure
- [x] rdf:parseType="Resource" creates blank node and nested triples
- [x] rdf:parseType="Triple" produces triple term object
- [x] rdf:annotation creates reification link

## RDF 1.2 Semantics
- [~] Semantic entailment not implemented in library

## RDF 1.2 Schema (RDFS)
- [x] Basic RDFS vocabulary IRIs resolve (rdf/rdfs ttl files load)
- [x] rdfs:subClassOf and rdfs:subPropertyOf stored as triples

## RDF 1.2 Interoperability / Primer / What’s New
- [~] Informative docs; no normative tests planned

## OWL 2 (Mapping to RDF / Syntax)
- [x] Functional syntax parser handles a minimal ontology
- [~] OWL to RDF mapping not present in library

## RFC 3987 (IRIs)
- [x] Scheme validation (invalid scheme rejected)
- [x] Unicode authority/path are percent-encoded in .string
- [x] Missing scheme rejected
- [x] asURL() yields valid URL for Unicode input
