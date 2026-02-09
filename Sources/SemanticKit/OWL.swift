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
        public static let ObjectProperty = makeIRI("\(namespace)ObjectProperty")
        public static let DatatypeProperty = makeIRI("\(namespace)DatatypeProperty")
        public static let AnnotationProperty = makeIRI("\(namespace)AnnotationProperty")
        public static let NamedIndividual = makeIRI("\(namespace)NamedIndividual")

        public static let equivalentClass = makeIRI("\(namespace)equivalentClass")
        public static let disjointWith = makeIRI("\(namespace)disjointWith")

        private static func makeIRI(_ string: String) -> IRI {
            try! IRI(string)
        }
    }
}
