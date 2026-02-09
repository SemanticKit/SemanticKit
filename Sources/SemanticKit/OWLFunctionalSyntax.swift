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
            case "ClassAssertion":
                try parseClassAssertion()
            case "ObjectPropertyAssertion":
                try parseObjectPropertyAssertion()
            case "DataPropertyAssertion":
                try parseDataPropertyAssertion()
            case "AnnotationAssertion":
                try parseAnnotationAssertion()
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

        try insertTriple(
            subject: subject,
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(object)
        )
    }

    private mutating func parseSubClassOf() throws {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let subClass = try parseClassIriOnly()
        skipWhitespaceAndComments()
        let superClass = try parseClassIriOnly()
        skipWhitespaceAndComments()
        try expect(")")

        try insertTriple(
            subject: try AnyRDFSubject(subClass),
            predicate: RDF.RDFS.subClassOf,
            object: AnyRDFObject(superClass)
        )
    }

    private mutating func parseEquivalentClasses() throws {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()

        var classes: [IRI] = []
        while true {
            classes.append(try parseClassIriOnly())
            skipWhitespaceAndComments()
            if peek() == ")" { break }
        }
        try expect(")")

        guard let first = classes.first else { return }
        for other in classes.dropFirst() {
            try insertTriple(
                subject: try AnyRDFSubject(first),
                predicate: OWL.Vocabulary.equivalentClass,
                object: AnyRDFObject(other)
            )
        }
    }

    private mutating func parseDisjointClasses() throws {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()

        var classes: [IRI] = []
        while true {
            classes.append(try parseClassIriOnly())
            skipWhitespaceAndComments()
            if peek() == ")" { break }
        }
        try expect(")")

        guard let first = classes.first else { return }
        for other in classes.dropFirst() {
            try insertTriple(
                subject: try AnyRDFSubject(first),
                predicate: OWL.Vocabulary.disjointWith,
                object: AnyRDFObject(other)
            )
        }
    }

    private mutating func parseClassAssertion() throws {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let classIri = try parseClassIriOnly()
        skipWhitespaceAndComments()
        let individual = try parseIndividual()
        skipWhitespaceAndComments()
        try expect(")")

        try insertTriple(
            subject: individual,
            predicate: RDF.Vocabulary.type,
            object: AnyRDFObject(classIri)
        )
    }

    private mutating func parseObjectPropertyAssertion() throws {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let property = try parseIri()
        skipWhitespaceAndComments()
        let subject = try parseIndividual()
        skipWhitespaceAndComments()
        let object = try parseIndividualObject()
        skipWhitespaceAndComments()
        try expect(")")

        try insertTriple(
            subject: subject,
            predicate: property,
            object: object
        )
    }

    private mutating func parseDataPropertyAssertion() throws {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let property = try parseIri()
        skipWhitespaceAndComments()
        let subject = try parseIndividual()
        skipWhitespaceAndComments()
        let literal = try parseLiteral()
        skipWhitespaceAndComments()
        try expect(")")

        try insertTriple(
            subject: subject,
            predicate: property,
            object: AnyRDFObject(literal)
        )
    }

    private mutating func parseAnnotationAssertion() throws {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()

        while consumeWord("Annotation") {
            _ = try parseAnnotation()
            skipWhitespaceAndComments()
        }

        let property = try parseIri()
        skipWhitespaceAndComments()
        let subject = try parseAnnotationSubject()
        skipWhitespaceAndComments()
        let value = try parseAnnotationValue()
        skipWhitespaceAndComments()
        try expect(")")

        try insertTriple(
            subject: subject,
            predicate: property,
            object: value
        )
    }

    private mutating func parseAnnotation() throws -> (IRI, AnyRDFObject) {
        skipWhitespaceAndComments()
        try expect("(")
        skipWhitespaceAndComments()
        let property = try parseIri()
        skipWhitespaceAndComments()
        let value = try parseAnnotationValue()
        skipWhitespaceAndComments()
        try expect(")")
        return (property, value)
    }

    // MARK: - Term parsing

    private mutating func parseClassIriOnly() throws -> IRI {
        if isStartOfIriRef() {
            return try parseIri()
        }
        let keyword = try parseIdentifier()
        throw errorUnsupported(keyword)
    }

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

    // MARK: - Helpers

    private mutating func insertTriple(subject: AnyRDFSubject, predicate: IRI, object: AnyRDFObject) throws {
        do {
            try graph.insert(Graph.TripleType(subject: subject, predicate: predicate, object: object))
        } catch RDFGraphError.duplicateTriple {
            return
        }
    }

    private func resolveIri(_ value: String) throws -> IRI {
        do {
            return try IRI(value)
        } catch {
            throw OWLFunctionalSyntaxError.invalidIri(value)
        }
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
