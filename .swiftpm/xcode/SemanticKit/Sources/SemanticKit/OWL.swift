import Foundation

// MARK: - OWL Vocabulary

public struct OWL {}

public extension OWL {
    enum Vocabulary {
        public static let namespace = "http://www.w3.org/2002/07/owl#"

        public static let Ontology = makeIRI("\(namespace)Ontology")
        public static let imports = makeIRI("\(namespace)imports")

        public static let Class = makeIRI("\(namespace)Class")
        public static let Thing = makeIRI("\(namespace)Thing")
        public static let Nothing = makeIRI("\(namespace)Nothing")
        public static let ObjectProperty = makeIRI("\(namespace)ObjectProperty")
        public static let DatatypeProperty = makeIRI("\(namespace)DatatypeProperty")
        public static let AnnotationProperty = makeIRI("\(namespace)AnnotationProperty")
        public static let NamedIndividual = makeIRI("\(namespace)NamedIndividual")
        public static let Restriction = makeIRI("\(namespace)Restriction")
        public static let FunctionalProperty = makeIRI("\(namespace)FunctionalProperty")
        public static let InverseFunctionalProperty = makeIRI("\(namespace)InverseFunctionalProperty")
        public static let ReflexiveProperty = makeIRI("\(namespace)ReflexiveProperty")
        public static let IrreflexiveProperty = makeIRI("\(namespace)IrreflexiveProperty")
        public static let SymmetricProperty = makeIRI("\(namespace)SymmetricProperty")
        public static let AsymmetricProperty = makeIRI("\(namespace)AsymmetricProperty")
        public static let TransitiveProperty = makeIRI("\(namespace)TransitiveProperty")
        public static let Axiom = makeIRI("\(namespace)Axiom")
        public static let AllDisjointClasses = makeIRI("\(namespace)AllDisjointClasses")
        public static let AllDisjointProperties = makeIRI("\(namespace)AllDisjointProperties")
        public static let AllDifferent = makeIRI("\(namespace)AllDifferent")
        public static let NegativePropertyAssertion = makeIRI("\(namespace)NegativePropertyAssertion")

        public static let intersectionOf = makeIRI("\(namespace)intersectionOf")
        public static let unionOf = makeIRI("\(namespace)unionOf")
        public static let complementOf = makeIRI("\(namespace)complementOf")
        public static let oneOf = makeIRI("\(namespace)oneOf")
        public static let onProperty = makeIRI("\(namespace)onProperty")
        public static let someValuesFrom = makeIRI("\(namespace)someValuesFrom")
        public static let allValuesFrom = makeIRI("\(namespace)allValuesFrom")
        public static let hasValue = makeIRI("\(namespace)hasValue")
        public static let hasSelf = makeIRI("\(namespace)hasSelf")
        public static let minCardinality = makeIRI("\(namespace)minCardinality")
        public static let maxCardinality = makeIRI("\(namespace)maxCardinality")
        public static let cardinality = makeIRI("\(namespace)cardinality")
        public static let minQualifiedCardinality = makeIRI("\(namespace)minQualifiedCardinality")
        public static let maxQualifiedCardinality = makeIRI("\(namespace)maxQualifiedCardinality")
        public static let qualifiedCardinality = makeIRI("\(namespace)qualifiedCardinality")
        public static let onClass = makeIRI("\(namespace)onClass")
        public static let onDataRange = makeIRI("\(namespace)onDataRange")
        public static let onDatatype = makeIRI("\(namespace)onDatatype")
        public static let withRestrictions = makeIRI("\(namespace)withRestrictions")
        public static let propertyChainAxiom = makeIRI("\(namespace)propertyChainAxiom")
        public static let inverseOf = makeIRI("\(namespace)inverseOf")
        public static let disjointUnionOf = makeIRI("\(namespace)disjointUnionOf")

        public static let equivalentClass = makeIRI("\(namespace)equivalentClass")
        public static let disjointWith = makeIRI("\(namespace)disjointWith")
        public static let equivalentProperty = makeIRI("\(namespace)equivalentProperty")
        public static let propertyDisjointWith = makeIRI("\(namespace)propertyDisjointWith")
        public static let members = makeIRI("\(namespace)members")
        public static let distinctMembers = makeIRI("\(namespace)distinctMembers")
        public static let hasKey = makeIRI("\(namespace)hasKey")
        public static let sameAs = makeIRI("\(namespace)sameAs")
        public static let differentFrom = makeIRI("\(namespace)differentFrom")

        public static let annotatedSource = makeIRI("\(namespace)annotatedSource")
        public static let annotatedProperty = makeIRI("\(namespace)annotatedProperty")
        public static let annotatedTarget = makeIRI("\(namespace)annotatedTarget")

        public static let sourceIndividual = makeIRI("\(namespace)sourceIndividual")
        public static let assertionProperty = makeIRI("\(namespace)assertionProperty")
        public static let targetIndividual = makeIRI("\(namespace)targetIndividual")
        public static let targetValue = makeIRI("\(namespace)targetValue")

        private static func makeIRI(_ string: String) -> IRI {
            try! IRI(string)
        }
    }
}
