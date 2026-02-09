import Foundation

// MARK: - OWL 2 Functional-Style Syntax import

public enum OWLFunctionalSyntaxError: Error, CustomStringConvertible {
    case unexpectedEndOfInput(line: Int, column: Int)
    case unexpectedCharacter(Character, line: Int, column: Int)
    case unexpectedToken(String, line: Int, column: Int)
    case undefinedPrefix(String, line: Int, column: Int)
    case invalidIri(String)
    case invalidLiteral(String)
    case unsupportedConstruct(String, line: Int, column: Int)

    public var description: String {
        switch self {
        case let .unexpectedEndOfInput(line, column):
            return "Unexpected end of input at line \(line), column \(column)."
        case let .unexpectedCharacter(ch, line, column):
            return "Unexpected character '\(ch)' at line \(line), column \(column)."
        case let .unexpectedToken(token, line, column):
            return "Unexpected token '\(token)' at line \(line), column \(column)."
        case let .undefinedPrefix(prefix, line, column):
            return "Undefined prefix '\(prefix)' at line \(line), column \(column)."
        case let .invalidIri(value):
            return "Invalid IRI: \(value)"
        case let .invalidLiteral(value):
            return "Invalid literal: \(value)"
        case let .unsupportedConstruct(name, line, column):
            return "Unsupported OWL construct '\(name)' at line \(line), column \(column)."
        }
    }
}

public extension Graph {
    init(owlFunctionalSyntax text: String) throws {
        var parser = OWLFunctionalParser(text: text)
        self = try parser.parseGraph()
    }
}

private struct OWLFunctionalParser {
    private struct Annotation {
        let property: IRI
        let value: AnyRDFObject
    }

    private enum ObjectPropertyExpression {
        case iri(IRI)
        case inverse(IRI)

        var isInverse: Bool {
            switch self {
            case .inverse: return true
            case .iri: return false
            }
        }

        var baseIri: IRI {
            switch self {
            case let .iri(iri), let .inverse(iri):
                return iri
            }
        }
    }

    private let text: String
    private var index: String.Index
    private var line: Int = 1
    private var column: Int = 1

    private var prefixes: [String: IRI] = [:]
    private var graph = Graph()
    private var blankNodeCounter = 0

    init(text: String) {
        self.text = text
        self.index = text.startIndex
    }

    mutating func parseGraph() throws -> Graph {
        try parsePrefixDeclarations()
        try parseOntology()
        skipWhitespaceAndComments()
        if !isAtEnd {
            throw errorUnexpectedCharacter()
        }
        return graph
    }

    // MARK: - Top-level parsing

    private mutating func parsePrefixDeclarations() throws {
        while true {
            skipWhitespaceAndComments()
            if consumeWord("Prefix") {
                try parsePrefixDeclaration()
            } else {
                return
            }
        }
    }

    private mutating func parsePrefixDeclaration() throws {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()

        let prefixLabel = try parsePrefixLabel()
        skipWhitespaceAndComments()
        try expect(":=")
        skipWhitespaceAndComments()

        let iri = try parseIri()
        skipWhitespaceAndComments()
        try expect(")")

        prefixes[prefixLabel] = iri
    }

    private mutating func parseOntology() throws {
        skipWhitespaceAndComments()
        guard consumeWord("Ontology") else {
            throw errorUnexpectedToken("Ontology")
        }
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()

        var ontologyIRI: IRI? = nil
        var versionIRI: IRI? = nil

        if isStartOfIriRef() {
            ontologyIRI = try parseIri()
            skipWhitespaceAndComments()
            if isStartOfIriRef() {
                versionIRI = try parseIri()
                _ = versionIRI
                skipWhitespaceAndComments()
            }
        }

        if let ontologyIRI {
            try insertTriple(
                subject: try AnyRDFSubject(ontologyIRI),
                predicate: RDF.Vocabulary.type,
                object: AnyRDFObject(OWL.Vocabulary.Ontology)
            )
        }

        while true {
            skipWhitespaceAndComments()
            if peek() == ")" {
                _ = advance()
                return
            }
            let keyword = try parseIdentifier()
            switch keyword {
            case "Import":
                try parseImport(ontologyIRI: ontologyIRI)
            case "Annotation":
                _ = try parseAnnotation()
            case "Declaration":
                try parseDeclaration()
            case "SubClassOf":
                try parseSubClassOf()
            case "EquivalentClasses":
                try parseEquivalentClasses()
            case "DisjointClasses":
                try parseDisjointClasses()
            case "DisjointUnion":
                try parseDisjointUnion()
            case "SubObjectPropertyOf":
                try parseSubObjectPropertyOf()
            case "EquivalentObjectProperties":
                try parseEquivalentObjectProperties()
            case "DisjointObjectProperties":
                try parseDisjointObjectProperties()
            case "ObjectPropertyDomain":
                try parseObjectPropertyDomain()
            case "ObjectPropertyRange":
                try parseObjectPropertyRange()
            case "InverseObjectProperties":
                try parseInverseObjectProperties()
            case "FunctionalObjectProperty":
                try parsePropertyCharacteristic(OWL.Vocabulary.FunctionalProperty, objectProperty: true)
            case "InverseFunctionalObjectProperty":
                try parsePropertyCharacteristic(OWL.Vocabulary.InverseFunctionalProperty, objectProperty: true)
            case "ReflexiveObjectProperty":
                try parsePropertyCharacteristic(OWL.Vocabulary.ReflexiveProperty, objectProperty: true)
            case "IrreflexiveObjectProperty":
                try parsePropertyCharacteristic(OWL.Vocabulary.IrreflexiveProperty, objectProperty: true)
            case "SymmetricObjectProperty":
                try parsePropertyCharacteristic(OWL.Vocabulary.SymmetricProperty, objectProperty: true)
            case "AsymmetricObjectProperty":
                try parsePropertyCharacteristic(OWL.Vocabulary.AsymmetricProperty, objectProperty: true)
            case "TransitiveObjectProperty":
                try parsePropertyCharacteristic(OWL.Vocabulary.TransitiveProperty, objectProperty: true)
            case "SubDataPropertyOf":
                try parseSubDataPropertyOf()
            case "EquivalentDataProperties":
                try parseEquivalentDataProperties()
            case "DisjointDataProperties":
                try parseDisjointDataProperties()
            case "DataPropertyDomain":
                try parseDataPropertyDomain()
            case "DataPropertyRange":
                try parseDataPropertyRange()
            case "FunctionalDataProperty":
                try parsePropertyCharacteristic(OWL.Vocabulary.FunctionalProperty, objectProperty: false)
            case "DatatypeDefinition":
                try parseDatatypeDefinition()
            case "HasKey":
                try parseHasKey()
            case "SameIndividual":
                try parseSameIndividual()
            case "DifferentIndividuals":
                try parseDifferentIndividuals()
            case "ClassAssertion":
                try parseClassAssertion()
            case "ObjectPropertyAssertion":
                try parseObjectPropertyAssertion()
            case "NegativeObjectPropertyAssertion":
                try parseNegativeObjectPropertyAssertion()
            case "DataPropertyAssertion":
                try parseDataPropertyAssertion()
            case "NegativeDataPropertyAssertion":
                try parseNegativeDataPropertyAssertion()
            case "AnnotationAssertion":
                try parseAnnotationAssertion()
            case "SubAnnotationPropertyOf":
                try parseSubAnnotationPropertyOf()
            case "AnnotationPropertyDomain":
                try parseAnnotationPropertyDomain()
            case "AnnotationPropertyRange":
                try parseAnnotationPropertyRange()
            default:
                throw errorUnsupported(keyword)
            }
        }
    }

    // MARK: - Ontology items

    private mutating func parseImport(ontologyIRI: IRI?) throws {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let imported = try parseIri()
        skipWhitespaceAndComments()
        try expect(")")

        guard let ontologyIRI else { return }
        try insertTriple(
            subject: try AnyRDFSubject(ontologyIRI),
            predicate: OWL.Vocabulary.imports,
            object: AnyRDFObject(imported)
        )
    }

    private mutating func parseDeclaration() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()

        let entityType = try parseIdentifier()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let entity = try parseIri()
        skipWhitespaceAndComments()
        try expect(")")
        skipWhitespaceAndComments()
        try expect(")")

        let subject = try AnyRDFSubject(entity)
        let object: IRI

        switch entityType {
        case "Class":
            object = OWL.Vocabulary.Class
        case "ObjectProperty":
            object = OWL.Vocabulary.ObjectProperty
        case "DataProperty":
            object = OWL.Vocabulary.DatatypeProperty
        case "AnnotationProperty":
            object = OWL.Vocabulary.AnnotationProperty
        case "NamedIndividual":
            object = OWL.Vocabulary.NamedIndividual
        case "Datatype":
            object = RDF.RDFS.Datatype
        default:
            throw errorUnsupported(entityType)
        }

        try emitAnnotatedTriple(
            subject: subject,
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(object),
            annotations: annotations
        )
    }

    private mutating func parseSubClassOf() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let subClass = try parseClassExpression()
        skipWhitespaceAndComments()
        let superClass = try parseClassExpression()
        skipWhitespaceAndComments()
        try expect(")")

        try emitAnnotatedTriple(
            subject: try asSubject(subClass),
            predicate: RDF.RDFS.subClassOf,
            object: superClass,
            annotations: annotations
        )
    }

    private mutating func parseEquivalentClasses() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()

        var classes: [AnyRDFObject] = []
        while true {
            classes.append(try parseClassExpression())
            skipWhitespaceAndComments()
            if peek() == ")" { break }
        }
        try expect(")")

        guard let first = classes.first else { return }
        for other in classes.dropFirst() {
            try emitAnnotatedTriple(
                subject: try asSubject(first),
                predicate: OWL.Vocabulary.equivalentClass,
                object: other,
                annotations: annotations
            )
        }
    }

    private mutating func parseDisjointClasses() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()

        var classes: [AnyRDFObject] = []
        while true {
            classes.append(try parseClassExpression())
            skipWhitespaceAndComments()
            if peek() == ")" { break }
        }
        try expect(")")

        guard classes.count >= 2 else { return }
        if classes.count == 2 {
            try emitAnnotatedTriple(
                subject: try asSubject(classes[0]),
                predicate: OWL.Vocabulary.disjointWith,
                object: classes[1],
                annotations: annotations
            )
            return
        }

        let list = try makeList(classes)
        let axiomNode = try newBlankNode()
        try insertTriple(
            subject: try AnyRDFSubject(axiomNode),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(OWL.Vocabulary.AllDisjointClasses)
        )
        try emitAnnotatedTriple(
            subject: try AnyRDFSubject(axiomNode),
            predicate: OWL.Vocabulary.members,
            object: list,
            annotations: annotations
        )
    }

    private mutating func parseDisjointUnion() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()

        let clazz = try parseClassExpression()
        skipWhitespaceAndComments()

        var members: [AnyRDFObject] = []
        while true {
            members.append(try parseClassExpression())
            skipWhitespaceAndComments()
            if peek() == ")" { break }
        }
        try expect(")")

        let list = try makeList(members)
        try emitAnnotatedTriple(
            subject: try asSubject(clazz),
            predicate: OWL.Vocabulary.disjointUnionOf,
            object: list,
            annotations: annotations
        )
    }

    private mutating func parseSubObjectPropertyOf() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()

        if consumeWord("ObjectPropertyChain") {
            skipWhitespaceAndComments()
            try expect("(")
            skipWhitespaceAndComments()
            var chain: [AnyRDFObject] = []
            while true {
                let expr = try parseObjectPropertyExpression()
                chain.append(try propertyExpressionNode(expr))
                skipWhitespaceAndComments()
                if peek() == ")" { break }
            }
            try expect(")")
            skipWhitespaceAndComments()
            let superProperty = try parseObjectPropertyExpression()
            skipWhitespaceAndComments()
            try expect(")")

            let list = try makeList(chain)
            try emitAnnotatedTriple(
                subject: try asSubject(try propertyExpressionNode(superProperty)),
                predicate: OWL.Vocabulary.propertyChainAxiom,
                object: list,
                annotations: annotations
            )
            return
        }

        let subProperty = try parseObjectPropertyExpression()
        skipWhitespaceAndComments()
        let superProperty = try parseObjectPropertyExpression()
        skipWhitespaceAndComments()
        try expect(")")

        try emitAnnotatedTriple(
            subject: try asSubject(try propertyExpressionNode(subProperty)),
            predicate: RDF.RDFS.subPropertyOf,
            object: try propertyExpressionNode(superProperty),
            annotations: annotations
        )
    }

    private mutating func parseEquivalentObjectProperties() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        var properties: [AnyRDFObject] = []
        while true {
            let expr = try parseObjectPropertyExpression()
            properties.append(try propertyExpressionNode(expr))
            skipWhitespaceAndComments()
            if peek() == ")" { break }
        }
        try expect(")")

        guard let first = properties.first else { return }
        for other in properties.dropFirst() {
            try emitAnnotatedTriple(
                subject: try asSubject(first),
                predicate: OWL.Vocabulary.equivalentProperty,
                object: other,
                annotations: annotations
            )
        }
    }

    private mutating func parseDisjointObjectProperties() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        var properties: [AnyRDFObject] = []
        while true {
            let expr = try parseObjectPropertyExpression()
            properties.append(try propertyExpressionNode(expr))
            skipWhitespaceAndComments()
            if peek() == ")" { break }
        }
        try expect(")")

        guard properties.count >= 2 else { return }
        if properties.count == 2 {
            try emitAnnotatedTriple(
                subject: try asSubject(properties[0]),
                predicate: OWL.Vocabulary.propertyDisjointWith,
                object: properties[1],
                annotations: annotations
            )
            return
        }

        let list = try makeList(properties)
        let axiomNode = try newBlankNode()
        try insertTriple(
            subject: try AnyRDFSubject(axiomNode),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(OWL.Vocabulary.AllDisjointProperties)
        )
        try emitAnnotatedTriple(
            subject: try AnyRDFSubject(axiomNode),
            predicate: OWL.Vocabulary.members,
            object: list,
            annotations: annotations
        )
    }

    private mutating func parseObjectPropertyDomain() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let property = try parseObjectPropertyExpression()
        skipWhitespaceAndComments()
        let domain = try parseClassExpression()
        skipWhitespaceAndComments()
        try expect(")")

        try emitAnnotatedTriple(
            subject: try asSubject(try propertyExpressionNode(property)),
            predicate: RDF.RDFS.domain,
            object: domain,
            annotations: annotations
        )
    }

    private mutating func parseObjectPropertyRange() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let property = try parseObjectPropertyExpression()
        skipWhitespaceAndComments()
        let range = try parseClassExpression()
        skipWhitespaceAndComments()
        try expect(")")

        try emitAnnotatedTriple(
            subject: try asSubject(try propertyExpressionNode(property)),
            predicate: RDF.RDFS.range,
            object: range,
            annotations: annotations
        )
    }

    private mutating func parseInverseObjectProperties() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let first = try parseObjectPropertyExpression()
        skipWhitespaceAndComments()
        let second = try parseObjectPropertyExpression()
        skipWhitespaceAndComments()
        try expect(")")

        try emitAnnotatedTriple(
            subject: try asSubject(try propertyExpressionNode(first)),
            predicate: OWL.Vocabulary.inverseOf,
            object: try propertyExpressionNode(second),
            annotations: annotations
        )
        try emitAnnotatedTriple(
            subject: try asSubject(try propertyExpressionNode(second)),
            predicate: OWL.Vocabulary.inverseOf,
            object: try propertyExpressionNode(first),
            annotations: annotations
        )
    }

    private mutating func parsePropertyCharacteristic(_ type: IRI, objectProperty: Bool) throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        if objectProperty {
            let property = try parseObjectPropertyExpression()
            skipWhitespaceAndComments()
            try expect(")")
            let node = try propertyExpressionNode(property)
            try emitAnnotatedTriple(
                subject: try asSubject(node),
                predicate: RDF.Vocabulary.type,
                object: AnyRDFObject(type),
                annotations: annotations
            )
            return
        }

        let property = try parseDataPropertyExpression()
        skipWhitespaceAndComments()
        try expect(")")

        try emitAnnotatedTriple(
            subject: try AnyRDFSubject(property),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(type),
            annotations: annotations
        )
    }

    private mutating func parseSubDataPropertyOf() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let subProperty = try parseDataPropertyExpression()
        skipWhitespaceAndComments()
        let superProperty = try parseDataPropertyExpression()
        skipWhitespaceAndComments()
        try expect(")")

        try emitAnnotatedTriple(
            subject: try AnyRDFSubject(subProperty),
            predicate: RDF.RDFS.subPropertyOf,
            object: AnyRDFObject(superProperty),
            annotations: annotations
        )
    }

    private mutating func parseEquivalentDataProperties() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        var properties: [IRI] = []
        while true {
            properties.append(try parseDataPropertyExpression())
            skipWhitespaceAndComments()
            if peek() == ")" { break }
        }
        try expect(")")

        guard let first = properties.first else { return }
        for other in properties.dropFirst() {
            try emitAnnotatedTriple(
                subject: try AnyRDFSubject(first),
                predicate: OWL.Vocabulary.equivalentProperty,
                object: AnyRDFObject(other),
                annotations: annotations
            )
        }
    }

    private mutating func parseDisjointDataProperties() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        var properties: [AnyRDFObject] = []
        while true {
            properties.append(AnyRDFObject(try parseDataPropertyExpression()))
            skipWhitespaceAndComments()
            if peek() == ")" { break }
        }
        try expect(")")

        guard properties.count >= 2 else { return }
        if properties.count == 2 {
            try emitAnnotatedTriple(
                subject: try asSubject(properties[0]),
                predicate: OWL.Vocabulary.propertyDisjointWith,
                object: properties[1],
                annotations: annotations
            )
            return
        }

        let list = try makeList(properties)
        let axiomNode = try newBlankNode()
        try insertTriple(
            subject: try AnyRDFSubject(axiomNode),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(OWL.Vocabulary.AllDisjointProperties)
        )
        try emitAnnotatedTriple(
            subject: try AnyRDFSubject(axiomNode),
            predicate: OWL.Vocabulary.members,
            object: list,
            annotations: annotations
        )
    }

    private mutating func parseDataPropertyDomain() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let property = try parseDataPropertyExpression()
        skipWhitespaceAndComments()
        let domain = try parseClassExpression()
        skipWhitespaceAndComments()
        try expect(")")

        try emitAnnotatedTriple(
            subject: try AnyRDFSubject(property),
            predicate: RDF.RDFS.domain,
            object: domain,
            annotations: annotations
        )
    }

    private mutating func parseDataPropertyRange() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let property = try parseDataPropertyExpression()
        skipWhitespaceAndComments()
        let range = try parseDataRange()
        skipWhitespaceAndComments()
        try expect(")")

        try emitAnnotatedTriple(
            subject: try AnyRDFSubject(property),
            predicate: RDF.RDFS.range,
            object: range,
            annotations: annotations
        )
    }

    private mutating func parseDatatypeDefinition() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let datatype = try parseIri()
        skipWhitespaceAndComments()
        let range = try parseDataRange()
        skipWhitespaceAndComments()
        try expect(")")

        try insertTriple(
            subject: try AnyRDFSubject(datatype),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(RDF.RDFS.Datatype)
        )
        try emitAnnotatedTriple(
            subject: try AnyRDFSubject(datatype),
            predicate: OWL.Vocabulary.equivalentClass,
            object: range,
            annotations: annotations
        )
    }

    private mutating func parseHasKey() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let clazz = try parseClassExpression()
        skipWhitespaceAndComments()

        let objectProps = try parsePropertyExpressionList(isObject: true)
        skipWhitespaceAndComments()
        let dataProps = try parsePropertyExpressionList(isObject: false)
        skipWhitespaceAndComments()
        try expect(")")

        let list = try makeList(objectProps + dataProps)
        try emitAnnotatedTriple(
            subject: try asSubject(clazz),
            predicate: OWL.Vocabulary.hasKey,
            object: list,
            annotations: annotations
        )
    }

    private mutating func parseSameIndividual() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        var individuals: [AnyRDFObject] = []
        while true {
            individuals.append(try parseIndividualObject())
            skipWhitespaceAndComments()
            if peek() == ")" { break }
        }
        try expect(")")

        guard let first = individuals.first else { return }
        for other in individuals.dropFirst() {
            try emitAnnotatedTriple(
                subject: try asSubject(first),
                predicate: OWL.Vocabulary.sameAs,
                object: other,
                annotations: annotations
            )
        }
    }

    private mutating func parseDifferentIndividuals() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        var individuals: [AnyRDFObject] = []
        while true {
            individuals.append(try parseIndividualObject())
            skipWhitespaceAndComments()
            if peek() == ")" { break }
        }
        try expect(")")

        guard individuals.count >= 2 else { return }
        if individuals.count == 2 {
            try emitAnnotatedTriple(
                subject: try asSubject(individuals[0]),
                predicate: OWL.Vocabulary.differentFrom,
                object: individuals[1],
                annotations: annotations
            )
            return
        }

        let list = try makeList(individuals)
        let axiomNode = try newBlankNode()
        try insertTriple(
            subject: try AnyRDFSubject(axiomNode),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(OWL.Vocabulary.AllDifferent)
        )
        try emitAnnotatedTriple(
            subject: try AnyRDFSubject(axiomNode),
            predicate: OWL.Vocabulary.distinctMembers,
            object: list,
            annotations: annotations
        )
    }

    private mutating func parseClassAssertion() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let clazz = try parseClassExpression()
        skipWhitespaceAndComments()
        let individual = try parseIndividual()
        skipWhitespaceAndComments()
        try expect(")")

        try emitAnnotatedTriple(
            subject: individual,
            predicate: RDF.Vocabulary.type,
            object: clazz,
            annotations: annotations
        )
    }

    private mutating func parseObjectPropertyAssertion() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let property = try parseObjectPropertyExpression()
        skipWhitespaceAndComments()
        let subject = try parseIndividual()
        skipWhitespaceAndComments()
        var object = try parseIndividualObject()
        skipWhitespaceAndComments()
        try expect(")")

        if property.isInverse {
            let swapped = try asSubject(object)
            object = objectFromSubject(subject)
            try emitAnnotatedTriple(
                subject: swapped,
                predicate: property.baseIri,
                object: object,
                annotations: annotations
            )
        } else {
            try emitAnnotatedTriple(
                subject: subject,
                predicate: property.baseIri,
                object: object,
                annotations: annotations
            )
        }
    }

    private mutating func parseNegativeObjectPropertyAssertion() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let property = try parseObjectPropertyExpression()
        skipWhitespaceAndComments()
        let subject = try parseIndividual()
        skipWhitespaceAndComments()
        var object = try parseIndividualObject()
        skipWhitespaceAndComments()
        try expect(")")

        var source = subject
        if property.isInverse {
            source = try asSubject(object)
            object = objectFromSubject(subject)
        }

        let axiomNode = try newBlankNode()
        try insertTriple(
            subject: try AnyRDFSubject(axiomNode),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(OWL.Vocabulary.NegativePropertyAssertion)
        )
        try insertTriple(
            subject: try AnyRDFSubject(axiomNode),
            predicate: OWL.Vocabulary.sourceIndividual,
            object: objectFromSubject(source)
        )
        try insertTriple(
            subject: try AnyRDFSubject(axiomNode),
            predicate: OWL.Vocabulary.assertionProperty,
            object: AnyRDFObject(property.baseIri)
        )
        try insertTriple(
            subject: try AnyRDFSubject(axiomNode),
            predicate: OWL.Vocabulary.targetIndividual,
            object: object
        )
        try attachAnnotations(to: axiomNode, annotations: annotations)
    }

    private mutating func parseDataPropertyAssertion() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let property = try parseDataPropertyExpression()
        skipWhitespaceAndComments()
        let subject = try parseIndividual()
        skipWhitespaceAndComments()
        let literal = try parseLiteral()
        skipWhitespaceAndComments()
        try expect(")")

        try emitAnnotatedTriple(
            subject: subject,
            predicate: property,
            object: AnyRDFObject(literal),
            annotations: annotations
        )
    }

    private mutating func parseNegativeDataPropertyAssertion() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let property = try parseDataPropertyExpression()
        skipWhitespaceAndComments()
        let subject = try parseIndividual()
        skipWhitespaceAndComments()
        let literal = try parseLiteral()
        skipWhitespaceAndComments()
        try expect(")")

        let axiomNode = try newBlankNode()
        try insertTriple(
            subject: try AnyRDFSubject(axiomNode),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(OWL.Vocabulary.NegativePropertyAssertion)
        )
        try insertTriple(
            subject: try AnyRDFSubject(axiomNode),
            predicate: OWL.Vocabulary.sourceIndividual,
            object: AnyRDFObject(subject.node as! any RDFObject)
        )
        try insertTriple(
            subject: try AnyRDFSubject(axiomNode),
            predicate: OWL.Vocabulary.assertionProperty,
            object: AnyRDFObject(property)
        )
        try insertTriple(
            subject: try AnyRDFSubject(axiomNode),
            predicate: OWL.Vocabulary.targetValue,
            object: AnyRDFObject(literal)
        )
        try attachAnnotations(to: axiomNode, annotations: annotations)
    }

    private mutating func parseAnnotationAssertion() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()

        let property = try parseIri()
        skipWhitespaceAndComments()
        let subject = try parseAnnotationSubject()
        skipWhitespaceAndComments()
        let value = try parseAnnotationValue()
        skipWhitespaceAndComments()
        try expect(")")

        try emitAnnotatedTriple(
            subject: subject,
            predicate: property,
            object: value,
            annotations: annotations
        )
    }

    private mutating func parseSubAnnotationPropertyOf() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let subProperty = try parseIri()
        skipWhitespaceAndComments()
        let superProperty = try parseIri()
        skipWhitespaceAndComments()
        try expect(")")

        try emitAnnotatedTriple(
            subject: try AnyRDFSubject(subProperty),
            predicate: RDF.RDFS.subPropertyOf,
            object: AnyRDFObject(superProperty),
            annotations: annotations
        )
    }

    private mutating func parseAnnotationPropertyDomain() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let property = try parseIri()
        skipWhitespaceAndComments()
        let domain = try parseIri()
        skipWhitespaceAndComments()
        try expect(")")

        try emitAnnotatedTriple(
            subject: try AnyRDFSubject(property),
            predicate: RDF.RDFS.domain,
            object: AnyRDFObject(domain),
            annotations: annotations
        )
    }

    private mutating func parseAnnotationPropertyRange() throws {
        let annotations = try parseAnnotations()
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let property = try parseIri()
        skipWhitespaceAndComments()
        let range = try parseIri()
        skipWhitespaceAndComments()
        try expect(")")

        try emitAnnotatedTriple(
            subject: try AnyRDFSubject(property),
            predicate: RDF.RDFS.range,
            object: AnyRDFObject(range),
            annotations: annotations
        )
    }

    // MARK: - Expressions

    private mutating func parseClassExpression() throws -> AnyRDFObject {
        if isStartOfIriRef() {
            return AnyRDFObject(try parseIri())
        }
        let keyword = try parseIdentifier()
        switch keyword {
        case "ObjectIntersectionOf":
            return try parseNaryClassExpression(predicate: OWL.Vocabulary.intersectionOf)
        case "ObjectUnionOf":
            return try parseNaryClassExpression(predicate: OWL.Vocabulary.unionOf)
        case "ObjectComplementOf":
            return try parseUnaryClassExpression(predicate: OWL.Vocabulary.complementOf)
        case "ObjectOneOf":
            return try parseObjectOneOf()
        case "ObjectSomeValuesFrom":
            return try parseObjectRestriction(predicate: OWL.Vocabulary.someValuesFrom, qualified: true)
        case "ObjectAllValuesFrom":
            return try parseObjectRestriction(predicate: OWL.Vocabulary.allValuesFrom, qualified: true)
        case "ObjectHasValue":
            return try parseObjectHasValue()
        case "ObjectHasSelf":
            return try parseObjectHasSelf()
        case "ObjectMinCardinality":
            return try parseObjectCardinality(kind: .min)
        case "ObjectMaxCardinality":
            return try parseObjectCardinality(kind: .max)
        case "ObjectExactCardinality":
            return try parseObjectCardinality(kind: .exact)
        case "DataSomeValuesFrom":
            return try parseDataRestriction(predicate: OWL.Vocabulary.someValuesFrom)
        case "DataAllValuesFrom":
            return try parseDataRestriction(predicate: OWL.Vocabulary.allValuesFrom)
        case "DataHasValue":
            return try parseDataHasValue()
        case "DataMinCardinality":
            return try parseDataCardinality(kind: .min)
        case "DataMaxCardinality":
            return try parseDataCardinality(kind: .max)
        case "DataExactCardinality":
            return try parseDataCardinality(kind: .exact)
        default:
            throw errorUnsupported(keyword)
        }
    }

    private mutating func parseDataRange() throws -> AnyRDFObject {
        if isStartOfIriRef() {
            return AnyRDFObject(try parseIri())
        }
        let keyword = try parseIdentifier()
        switch keyword {
        case "DataIntersectionOf":
            return try parseNaryDataRange(predicate: OWL.Vocabulary.intersectionOf)
        case "DataUnionOf":
            return try parseNaryDataRange(predicate: OWL.Vocabulary.unionOf)
        case "DataComplementOf":
            return try parseUnaryDataRange(predicate: OWL.Vocabulary.complementOf)
        case "DataOneOf":
            return try parseDataOneOf()
        case "DatatypeRestriction":
            return try parseDatatypeRestriction()
        default:
            throw errorUnsupported(keyword)
        }
    }

    private mutating func parseObjectPropertyExpression() throws -> ObjectPropertyExpression {
        if consumeWord("ObjectInverseOf") {
            skipWhitespaceAndComments()
            try expect("(")
            skipWhitespaceAndComments()
            let iri = try parseIri()
            skipWhitespaceAndComments()
            try expect(")")
            return .inverse(iri)
        }
        return .iri(try parseIri())
    }

    private mutating func parseDataPropertyExpression() throws -> IRI {
        try parseIri()
    }

    private mutating func parseObjectOneOf() throws -> AnyRDFObject {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        var individuals: [AnyRDFObject] = []
        while true {
            individuals.append(try parseIndividualObject())
            skipWhitespaceAndComments()
            if peek() == ")" { break }
        }
        try expect(")")

        let list = try makeList(individuals)
        let node = try newBlankNode()
        try insertTriple(
            subject: try AnyRDFSubject(node),
            predicate: OWL.Vocabulary.oneOf,
            object: list
        )
        return AnyRDFObject(node)
    }

    private mutating func parseNaryClassExpression(predicate: IRI) throws -> AnyRDFObject {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        var members: [AnyRDFObject] = []
        while true {
            members.append(try parseClassExpression())
            skipWhitespaceAndComments()
            if peek() == ")" { break }
        }
        try expect(")")

        let list = try makeList(members)
        let node = try newBlankNode()
        try insertTriple(
            subject: try AnyRDFSubject(node),
            predicate: predicate,
            object: list
        )
        return AnyRDFObject(node)
    }

    private mutating func parseUnaryClassExpression(predicate: IRI) throws -> AnyRDFObject {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let member = try parseClassExpression()
        skipWhitespaceAndComments()
        try expect(")")

        let node = try newBlankNode()
        try insertTriple(
            subject: try AnyRDFSubject(node),
            predicate: predicate,
            object: member
        )
        return AnyRDFObject(node)
    }

    private mutating func parseObjectRestriction(predicate: IRI, qualified: Bool) throws -> AnyRDFObject {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let property = try parseObjectPropertyExpression()
        skipWhitespaceAndComments()
        let classExpr = try parseClassExpression()
        skipWhitespaceAndComments()
        try expect(")")

        let restriction = try newBlankNode()
        try insertTriple(
            subject: try AnyRDFSubject(restriction),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(OWL.Vocabulary.Restriction)
        )
        try insertTriple(
            subject: try AnyRDFSubject(restriction),
            predicate: OWL.Vocabulary.onProperty,
            object: try propertyExpressionNode(property)
        )
        try insertTriple(
            subject: try AnyRDFSubject(restriction),
            predicate: predicate,
            object: classExpr
        )

        return AnyRDFObject(restriction)
    }

    private mutating func parseObjectHasValue() throws -> AnyRDFObject {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let property = try parseObjectPropertyExpression()
        skipWhitespaceAndComments()
        let value = try parseIndividualObject()
        skipWhitespaceAndComments()
        try expect(")")

        let restriction = try newBlankNode()
        try insertTriple(
            subject: try AnyRDFSubject(restriction),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(OWL.Vocabulary.Restriction)
        )
        try insertTriple(
            subject: try AnyRDFSubject(restriction),
            predicate: OWL.Vocabulary.onProperty,
            object: try propertyExpressionNode(property)
        )
        try insertTriple(
            subject: try AnyRDFSubject(restriction),
            predicate: OWL.Vocabulary.hasValue,
            object: value
        )
        return AnyRDFObject(restriction)
    }

    private mutating func parseObjectHasSelf() throws -> AnyRDFObject {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let property = try parseObjectPropertyExpression()
        skipWhitespaceAndComments()
        try expect(")")

        let restriction = try newBlankNode()
        try insertTriple(
            subject: try AnyRDFSubject(restriction),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(OWL.Vocabulary.Restriction)
        )
        try insertTriple(
            subject: try AnyRDFSubject(restriction),
            predicate: OWL.Vocabulary.onProperty,
            object: try propertyExpressionNode(property)
        )
        try insertTriple(
            subject: try AnyRDFSubject(restriction),
            predicate: OWL.Vocabulary.hasSelf,
            object: AnyRDFObject(try Literal("true", datatype: xsdBoolean))
        )
        return AnyRDFObject(restriction)
    }

    private enum CardinalityKind {
        case min
        case max
        case exact
    }

    private mutating func parseObjectCardinality(kind: CardinalityKind) throws -> AnyRDFObject {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let count = try parseNonNegativeInteger()
        skipWhitespaceAndComments()
        let property = try parseObjectPropertyExpression()
        skipWhitespaceAndComments()

        var classExpr: AnyRDFObject? = nil
        if peek() != ")" {
            classExpr = try parseClassExpression()
            skipWhitespaceAndComments()
        }
        try expect(")")

        let restriction = try newBlankNode()
        try insertTriple(
            subject: try AnyRDFSubject(restriction),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(OWL.Vocabulary.Restriction)
        )
        try insertTriple(
            subject: try AnyRDFSubject(restriction),
            predicate: OWL.Vocabulary.onProperty,
            object: try propertyExpressionNode(property)
        )

        let countLiteral = try Literal(String(count), datatype: xsdNonNegativeInteger)
        if let classExpr {
            let predicate = qualifiedCardinalityPredicate(for: kind)
            try insertTriple(
                subject: try AnyRDFSubject(restriction),
                predicate: predicate,
                object: AnyRDFObject(countLiteral)
            )
            try insertTriple(
                subject: try AnyRDFSubject(restriction),
                predicate: OWL.Vocabulary.onClass,
                object: classExpr
            )
        } else {
            let predicate = unqualifiedCardinalityPredicate(for: kind)
            try insertTriple(
                subject: try AnyRDFSubject(restriction),
                predicate: predicate,
                object: AnyRDFObject(countLiteral)
            )
        }

        return AnyRDFObject(restriction)
    }

    private mutating func parseDataRestriction(predicate: IRI) throws -> AnyRDFObject {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let property = try parseDataPropertyExpression()
        skipWhitespaceAndComments()

        var ranges: [AnyRDFObject] = []
        while true {
            ranges.append(try parseDataRange())
            skipWhitespaceAndComments()
            if peek() == ")" { break }
        }
        try expect(")")

        let restriction = try newBlankNode()
        try insertTriple(
            subject: try AnyRDFSubject(restriction),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(OWL.Vocabulary.Restriction)
        )
        try insertTriple(
            subject: try AnyRDFSubject(restriction),
            predicate: OWL.Vocabulary.onProperty,
            object: AnyRDFObject(property)
        )

        if ranges.count == 1 {
            try insertTriple(
                subject: try AnyRDFSubject(restriction),
                predicate: predicate,
                object: ranges[0]
            )
        } else {
            let list = try makeList(ranges)
            let rangeNode = try newBlankNode()
            try insertTriple(
                subject: try AnyRDFSubject(rangeNode),
                predicate: OWL.Vocabulary.unionOf,
                object: list
            )
            try insertTriple(
                subject: try AnyRDFSubject(restriction),
                predicate: predicate,
                object: AnyRDFObject(rangeNode)
            )
        }

        return AnyRDFObject(restriction)
    }

    private mutating func parseDataHasValue() throws -> AnyRDFObject {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let property = try parseDataPropertyExpression()
        skipWhitespaceAndComments()
        let value = try parseLiteral()
        skipWhitespaceAndComments()
        try expect(")")

        let restriction = try newBlankNode()
        try insertTriple(
            subject: try AnyRDFSubject(restriction),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(OWL.Vocabulary.Restriction)
        )
        try insertTriple(
            subject: try AnyRDFSubject(restriction),
            predicate: OWL.Vocabulary.onProperty,
            object: AnyRDFObject(property)
        )
        try insertTriple(
            subject: try AnyRDFSubject(restriction),
            predicate: OWL.Vocabulary.hasValue,
            object: AnyRDFObject(value)
        )
        return AnyRDFObject(restriction)
    }

    private mutating func parseDataCardinality(kind: CardinalityKind) throws -> AnyRDFObject {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let count = try parseNonNegativeInteger()
        skipWhitespaceAndComments()
        let property = try parseDataPropertyExpression()
        skipWhitespaceAndComments()

        var range: AnyRDFObject? = nil
        if peek() != ")" {
            range = try parseDataRange()
            skipWhitespaceAndComments()
        }
        try expect(")")

        let restriction = try newBlankNode()
        try insertTriple(
            subject: try AnyRDFSubject(restriction),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(OWL.Vocabulary.Restriction)
        )
        try insertTriple(
            subject: try AnyRDFSubject(restriction),
            predicate: OWL.Vocabulary.onProperty,
            object: AnyRDFObject(property)
        )

        let countLiteral = try Literal(String(count), datatype: xsdNonNegativeInteger)
        if let range {
            let predicate = qualifiedCardinalityPredicate(for: kind)
            try insertTriple(
                subject: try AnyRDFSubject(restriction),
                predicate: predicate,
                object: AnyRDFObject(countLiteral)
            )
            try insertTriple(
                subject: try AnyRDFSubject(restriction),
                predicate: OWL.Vocabulary.onDataRange,
                object: range
            )
        } else {
            let predicate = unqualifiedCardinalityPredicate(for: kind)
            try insertTriple(
                subject: try AnyRDFSubject(restriction),
                predicate: predicate,
                object: AnyRDFObject(countLiteral)
            )
        }

        return AnyRDFObject(restriction)
    }

    private mutating func parseNaryDataRange(predicate: IRI) throws -> AnyRDFObject {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        var members: [AnyRDFObject] = []
        while true {
            members.append(try parseDataRange())
            skipWhitespaceAndComments()
            if peek() == ")" { break }
        }
        try expect(")")

        let list = try makeList(members)
        let node = try newBlankNode()
        try insertTriple(
            subject: try AnyRDFSubject(node),
            predicate: predicate,
            object: list
        )
        return AnyRDFObject(node)
    }

    private mutating func parseUnaryDataRange(predicate: IRI) throws -> AnyRDFObject {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let member = try parseDataRange()
        skipWhitespaceAndComments()
        try expect(")")

        let node = try newBlankNode()
        try insertTriple(
            subject: try AnyRDFSubject(node),
            predicate: predicate,
            object: member
        )
        return AnyRDFObject(node)
    }

    private mutating func parseDataOneOf() throws -> AnyRDFObject {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        var literals: [AnyRDFObject] = []
        while true {
            literals.append(AnyRDFObject(try parseLiteral()))
            skipWhitespaceAndComments()
            if peek() == ")" { break }
        }
        try expect(")")

        let list = try makeList(literals)
        let node = try newBlankNode()
        try insertTriple(
            subject: try AnyRDFSubject(node),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(RDF.RDFS.Datatype)
        )
        try insertTriple(
            subject: try AnyRDFSubject(node),
            predicate: OWL.Vocabulary.oneOf,
            object: list
        )
        return AnyRDFObject(node)
    }

    private mutating func parseDatatypeRestriction() throws -> AnyRDFObject {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let datatype = try parseIri()
        skipWhitespaceAndComments()
        var restrictions: [AnyRDFObject] = []
        while true {
            let facet = try parseIri()
            skipWhitespaceAndComments()
            let literal = try parseLiteral()
            let restriction = try newBlankNode()
            try insertTriple(
                subject: try AnyRDFSubject(restriction),
                predicate: facet,
                object: AnyRDFObject(literal)
            )
            restrictions.append(AnyRDFObject(restriction))
            skipWhitespaceAndComments()
            if peek() == ")" { break }
        }
        try expect(")")

        let list = try makeList(restrictions)
        let node = try newBlankNode()
        try insertTriple(
            subject: try AnyRDFSubject(node),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(RDF.RDFS.Datatype)
        )
        try insertTriple(
            subject: try AnyRDFSubject(node),
            predicate: OWL.Vocabulary.onDatatype,
            object: AnyRDFObject(datatype)
        )
        try insertTriple(
            subject: try AnyRDFSubject(node),
            predicate: OWL.Vocabulary.withRestrictions,
            object: list
        )
        return AnyRDFObject(node)
    }

    // MARK: - Annotations

    private mutating func parseAnnotations() throws -> [Annotation] {
        var annotations: [Annotation] = []
        skipWhitespaceAndComments()
        while consumeWord("Annotation") {
            annotations.append(try parseAnnotation())
            skipWhitespaceAndComments()
        }
        return annotations
    }

    private mutating func parseAnnotation() throws -> Annotation {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let property = try parseIri()
        skipWhitespaceAndComments()
        let value = try parseAnnotationValue()
        skipWhitespaceAndComments()
        try expect(")")
        return Annotation(property: property, value: value)
    }

    private mutating func parseAnnotationSubject() throws -> AnyRDFSubject {
        if starts(with: "_:") {
            return try AnyRDFSubject(parseBlankNode())
        }
        return try AnyRDFSubject(parseIri())
    }

    private mutating func parseAnnotationValue() throws -> AnyRDFObject {
        if peek() == "\"" {
            return AnyRDFObject(try parseLiteral())
        }
        if starts(with: "_:") {
            return AnyRDFObject(try parseBlankNode())
        }
        return AnyRDFObject(try parseIri())
    }

    // MARK: - Term parsing

    private mutating func parseIndividual() throws -> AnyRDFSubject {
        if starts(with: "_:") {
            let blank = try parseBlankNode()
            return try AnyRDFSubject(blank)
        }
        let iri = try parseIri()
        return try AnyRDFSubject(iri)
    }

    private mutating func parseIndividualObject() throws -> AnyRDFObject {
        if starts(with: "_:") {
            return AnyRDFObject(try parseBlankNode())
        }
        return AnyRDFObject(try parseIri())
    }

    private mutating func parseIri() throws -> IRI {
        if peek() == "<" {
            let value = try parseIriRefString()
            return try resolveIri(value)
        }
        let token = try parsePrefixedName()
        guard let base = prefixes[token.prefix] else {
            throw errorUndefinedPrefix(token.prefix)
        }
        return try resolveIri(base.string + token.local)
    }

    private mutating func parseIriRefString() throws -> String {
        try expect("<")
        var value = ""
        while let ch = peek() {
            if ch == ">" {
                _ = advance()
                return value
            }
            if ch == "\\" {
                _ = advance()
                guard let escaped = advance() else { throw errorUnexpectedEnd() }
                switch escaped {
                case "u":
                    value.append(try readUnicodeScalar(count: 4))
                case "U":
                    value.append(try readUnicodeScalar(count: 8))
                default:
                    value.append(escaped)
                }
            } else {
                value.append(ch)
                _ = advance()
            }
        }
        throw errorUnexpectedEnd()
    }

    private mutating func parsePrefixedName() throws -> (prefix: String, local: String) {
        var token = ""
        while let ch = peek(), !ch.isWhitespace, ch != "(", ch != ")" {
            token.append(ch)
            _ = advance()
        }
        guard let colonIndex = token.firstIndex(of: ":") else {
            throw errorUnexpectedToken(token)
        }
        let prefix = String(token[..<colonIndex])
        let local = String(token[token.index(after: colonIndex)...])
        return (prefix, local)
    }

    private mutating func parsePrefixLabel() throws -> String {
        var label = ""
        while let ch = peek() {
            if ch == ":" {
                _ = advance()
                return label
            }
            if ch.isWhitespace || ch == "(" || ch == ")" {
                break
            }
            label.append(ch)
            _ = advance()
        }
        throw errorUnexpectedCharacter()
    }

    private mutating func parseBlankNode() throws -> BlankNode {
        try expect("_:")
        let label = try parseNameToken()
        return try BlankNode(label)
    }

    private mutating func parseNameToken() throws -> String {
        var token = ""
        while let ch = peek(), !ch.isWhitespace, ch != "(", ch != ")" {
            token.append(ch)
            _ = advance()
        }
        if token.isEmpty {
            throw errorUnexpectedCharacter()
        }
        return token
    }

    private mutating func parseLiteral() throws -> Literal {
        let string = try parseStringLiteral()
        skipWhitespaceAndComments()
        if peek() == "@" {
            _ = advance()
            let lang = try parseLanguageTag()
            return try Literal(string, languageTag: lang)
        }
        if starts(with: "^^") {
            _ = advance()
            _ = advance()
            skipWhitespaceAndComments()
            let datatype = try parseIri()
            return try Literal(string, datatype: datatype)
        }
        return try Literal(string)
    }

    private mutating func parseStringLiteral() throws -> String {
        try expect("\"")
        var value = ""
        while let ch = peek() {
            if ch == "\"" {
                _ = advance()
                return value
            }
            if ch == "\\" {
                _ = advance()
                guard let escaped = advance() else { throw errorUnexpectedEnd() }
                switch escaped {
                case "t": value.append("\t")
                case "b": value.append("\u{0008}")
                case "n": value.append("\n")
                case "r": value.append("\r")
                case "f": value.append("\u{000C}")
                case "\"": value.append("\"")
                case "\\": value.append("\\")
                case "u": value.append(try readUnicodeScalar(count: 4))
                case "U": value.append(try readUnicodeScalar(count: 8))
                default: value.append(escaped)
                }
            } else {
                value.append(ch)
                _ = advance()
            }
        }
        throw errorUnexpectedEnd()
    }

    private mutating func parseLanguageTag() throws -> String {
        var tag = ""
        guard let first = peek(), first.isLetter else {
            throw errorUnexpectedCharacter()
        }
        while let ch = peek(), ch.isLetter {
            tag.append(ch)
            _ = advance()
        }
        while let ch = peek(), ch == "-" {
            _ = advance()
            tag.append("-")
            var segment = ""
            while let next = peek(), next.isLetter || next.isNumber {
                segment.append(next)
                _ = advance()
            }
            if segment.isEmpty {
                throw errorUnexpectedCharacter()
            }
            tag.append(segment)
        }
        return tag.lowercased()
    }

    private mutating func parseIdentifier() throws -> String {
        var ident = ""
        guard let first = peek(), first.isLetter else {
            throw errorUnexpectedCharacter()
        }
        while let ch = peek(), ch.isLetter || ch.isNumber || ch == "-" {
            ident.append(ch)
            _ = advance()
        }
        return ident
    }

    private mutating func parseNonNegativeInteger() throws -> Int {
        var digits = ""
        while let ch = peek(), ch.isNumber {
            digits.append(ch)
            _ = advance()
        }
        guard let value = Int(digits) else {
            throw errorUnexpectedToken(digits)
        }
        return value
    }

    private mutating func parsePropertyExpressionList(isObject: Bool) throws -> [AnyRDFObject] {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        var props: [AnyRDFObject] = []
        while true {
            if isObject {
                let expr = try parseObjectPropertyExpression()
                props.append(try propertyExpressionNode(expr))
            } else {
                props.append(AnyRDFObject(try parseDataPropertyExpression()))
            }
            skipWhitespaceAndComments()
            if peek() == ")" { break }
        }
        try expect(")")
        return props
    }

    // MARK: - Mapping helpers

    private mutating func propertyExpressionNode(_ expr: ObjectPropertyExpression) throws -> AnyRDFObject {
        switch expr {
        case let .iri(iri):
            return AnyRDFObject(iri)
        case let .inverse(iri):
            let node = try newBlankNode()
            try insertTriple(
                subject: try AnyRDFSubject(node),
                predicate: RDF.Vocabulary.type,
                object: AnyRDFObject(OWL.Vocabulary.ObjectProperty)
            )
            try insertTriple(
                subject: try AnyRDFSubject(node),
                predicate: OWL.Vocabulary.inverseOf,
                object: AnyRDFObject(iri)
            )
            return AnyRDFObject(node)
        }
    }

    private func qualifiedCardinalityPredicate(for kind: CardinalityKind) -> IRI {
        switch kind {
        case .min: return OWL.Vocabulary.minQualifiedCardinality
        case .max: return OWL.Vocabulary.maxQualifiedCardinality
        case .exact: return OWL.Vocabulary.qualifiedCardinality
        }
    }

    private func unqualifiedCardinalityPredicate(for kind: CardinalityKind) -> IRI {
        switch kind {
        case .min: return OWL.Vocabulary.minCardinality
        case .max: return OWL.Vocabulary.maxCardinality
        case .exact: return OWL.Vocabulary.cardinality
        }
    }

    private mutating func emitAnnotatedTriple(
        subject: AnyRDFSubject,
        predicate: IRI,
        object: AnyRDFObject,
        annotations: [Annotation]
    ) throws {
        try insertTriple(subject: subject, predicate: predicate, object: object)
        guard !annotations.isEmpty else { return }

        let axiom = try newBlankNode()
        try insertTriple(
            subject: try AnyRDFSubject(axiom),
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(OWL.Vocabulary.Axiom)
        )
        try insertTriple(
            subject: try AnyRDFSubject(axiom),
            predicate: OWL.Vocabulary.annotatedSource,
            object: AnyRDFObject(subject.node as! any RDFObject)
        )
        try insertTriple(
            subject: try AnyRDFSubject(axiom),
            predicate: OWL.Vocabulary.annotatedProperty,
            object: AnyRDFObject(predicate)
        )
        try insertTriple(
            subject: try AnyRDFSubject(axiom),
            predicate: OWL.Vocabulary.annotatedTarget,
            object: object
        )
        try attachAnnotations(to: axiom, annotations: annotations)
    }

    private mutating func attachAnnotations(to axiom: BlankNode, annotations: [Annotation]) throws {
        guard !annotations.isEmpty else { return }
        for annotation in annotations {
            try insertTriple(
                subject: try AnyRDFSubject(axiom),
                predicate: annotation.property,
                object: annotation.value
            )
        }
    }

    private mutating func makeList(_ items: [AnyRDFObject]) throws -> AnyRDFObject {
        guard !items.isEmpty else {
            return AnyRDFObject(RDF.Vocabulary.nilValue)
        }
        var nodes: [BlankNode] = []
        for _ in items {
            nodes.append(try newBlankNode())
        }
        for (index, item) in items.enumerated() {
            let current = nodes[index]
            try insertTriple(
                subject: try AnyRDFSubject(current),
                predicate: RDF.Vocabulary.first,
                object: item
            )
            let rest: AnyRDFObject
            if index == nodes.count - 1 {
                rest = AnyRDFObject(RDF.Vocabulary.nilValue)
            } else {
                rest = AnyRDFObject(nodes[index + 1])
            }
            try insertTriple(
                subject: try AnyRDFSubject(current),
                predicate: RDF.Vocabulary.rest,
                object: rest
            )
        }
        return AnyRDFObject(nodes[0])
    }

    private mutating func insertTriple(subject: AnyRDFSubject, predicate: IRI, object: AnyRDFObject) throws {
        do {
            try graph.insert(Graph.TripleType(subject: subject, predicate: predicate, object: object))
        } catch RDFGraphError.duplicateTriple {
            return
        }
    }

    private mutating func newBlankNode() throws -> BlankNode {
        blankNodeCounter += 1
        return try BlankNode("genid\(blankNodeCounter)")
    }

    private func asSubject(_ object: AnyRDFObject) throws -> AnyRDFSubject {
        if let iri = object.node as? IRI {
            return try AnyRDFSubject(iri)
        }
        if let blank = object.node as? BlankNode {
            return try AnyRDFSubject(blank)
        }
        throw OWLFunctionalSyntaxError.invalidLiteral("Object cannot be used as subject.")
    }

    private func objectFromSubject(_ subject: AnyRDFSubject) -> AnyRDFObject {
        AnyRDFObject(subject.node as! any RDFObject)
    }

    private func resolveIri(_ value: String) throws -> IRI {
        do {
            return try IRI(value)
        } catch {
            throw OWLFunctionalSyntaxError.invalidIri(value)
        }
    }

    // MARK: - XSD helpers

    private var xsdBoolean: IRI {
        try! IRI("http://www.w3.org/2001/XMLSchema#boolean")
    }

    private var xsdNonNegativeInteger: IRI {
        try! IRI("http://www.w3.org/2001/XMLSchema#nonNegativeInteger")
    }

    // MARK: - Lexer

    private var isAtEnd: Bool { index >= text.endIndex }

    private func peek() -> Character? {
        guard index < text.endIndex else { return nil }
        return text[index]
    }

    private func starts(with string: String) -> Bool {
        String(text[index...].prefix(string.count)) == string
    }

    @discardableResult
    private mutating func advance() -> Character? {
        guard index < text.endIndex else { return nil }
        let ch = text[index]
        index = text.index(after: index)
        if ch == "\n" || ch == "\r" {
            line += 1
            column = 1
        } else {
            column += 1
        }
        return ch
    }

    private mutating func skipWhitespaceAndComments() {
        while let ch = peek() {
            if ch == "#" {
                skipComment()
                continue
            }
            if ch.isWhitespace {
                _ = advance()
                continue
            }
            break
        }
    }

    private mutating func skipComment() {
        while let ch = advance() {
            if ch == "\n" || ch == "\r" { break }
        }
    }

    private mutating func expect(_ string: String) throws {
        for ch in string {
            guard let current = peek(), current == ch else {
                throw errorUnexpectedCharacter()
            }
            _ = advance()
        }
    }

    private mutating func consumeWord(_ word: String) -> Bool {
        let snapshot = index
        let snapLine = line
        let snapColumn = column
        if starts(with: word) {
            for _ in word { _ = advance() }
            return true
        }
        index = snapshot
        line = snapLine
        column = snapColumn
        return false
    }

    private func isStartOfIriRef() -> Bool {
        if peek() == "<" { return true }
        if starts(with: "_:") { return true }
        if let ch = peek(), ch == ":" || ch.isLetter { return true }
        return false
    }

    private mutating func readUnicodeScalar(count: Int) throws -> String {
        var hex = ""
        for _ in 0..<count {
            guard let ch = advance() else { throw errorUnexpectedEnd() }
            hex.append(ch)
        }
        guard let value = UInt32(hex, radix: 16), let scalar = UnicodeScalar(value) else {
            throw errorUnexpectedToken(hex)
        }
        return String(scalar)
    }

    // MARK: - Errors

    private func errorUnexpectedEnd() -> OWLFunctionalSyntaxError {
        .unexpectedEndOfInput(line: line, column: column)
    }

    private func errorUnexpectedCharacter() -> OWLFunctionalSyntaxError {
        let ch = peek() ?? "\0"
        return .unexpectedCharacter(ch, line: line, column: column)
    }

    private func errorUnexpectedToken(_ token: String) -> OWLFunctionalSyntaxError {
        .unexpectedToken(token, line: line, column: column)
    }

    private func errorUndefinedPrefix(_ prefix: String) -> OWLFunctionalSyntaxError {
        .undefinedPrefix(prefix, line: line, column: column)
    }

    private func errorUnsupported(_ name: String) -> OWLFunctionalSyntaxError {
        .unsupportedConstruct(name, line: line, column: column)
    }
}
