import Foundation

// MARK: - Turtle import / export

public enum TurtleError: Error, CustomStringConvertible {
    case unexpectedEndOfInput(line: Int, column: Int)
    case unexpectedCharacter(Character, line: Int, column: Int)
    case invalidToken(String, line: Int, column: Int)
    case undefinedPrefix(String, line: Int, column: Int)
    case invalidBaseIri(String)

    public var description: String {
        switch self {
        case let .unexpectedEndOfInput(line, column):
            return "Unexpected end of input at line \(line), column \(column)."
        case let .unexpectedCharacter(char, line, column):
            return "Unexpected character '\(char)' at line \(line), column \(column)."
        case let .invalidToken(token, line, column):
            return "Invalid token '\(token)' at line \(line), column \(column)."
        case let .undefinedPrefix(prefix, line, column):
            return "Undefined prefix '\(prefix)' at line \(line), column \(column)."
        case let .invalidBaseIri(value):
            return "Invalid base IRI: \(value)"
        }
    }
}

public extension Graph {
    init(turtle: String, baseIRI: IRI? = nil) throws {
        var parser = TurtleParser(text: turtle, baseIRI: baseIRI)
        self = try parser.parseGraph()
    }

    func turtleString(prefixes: [String: IRI] = [:], baseIRI: IRI? = nil) -> String {
        let serializer = TurtleSerializer(prefixes: prefixes, baseIRI: baseIRI)
        return serializer.serialize(graph: self)
    }
}

// MARK: - Serializer

private struct TurtleSerializer {
    private let prefixes: [String: IRI]
    private let baseIRI: IRI?

    init(prefixes: [String: IRI], baseIRI: IRI?) {
        self.prefixes = prefixes
        self.baseIRI = baseIRI
    }

    func serialize(graph: Graph) -> String {
        var lines: [String] = []
        if let base = baseIRI {
            lines.append("@base <\(base.string)> .")
        }
        for (prefix, iri) in prefixes.sorted(by: { $0.key < $1.key }) {
            lines.append("@prefix \(prefix): <\(iri.string)> .")
        }

        let sortedTriples = graph.triples.sorted { lhs, rhs in
            let ls = lhs.subject.description
            let rs = rhs.subject.description
            if ls != rs { return ls < rs }
            let lp = lhs.predicate.string
            let rp = rhs.predicate.string
            if lp != rp { return lp < rp }
            return lhs.object.description < rhs.object.description
        }

        for triple in sortedTriples {
            let subject = formatSubject(triple.subject)
            let predicate = formatPredicate(triple.predicate)
            let object = formatObject(triple.object)
            lines.append("\(subject) \(predicate) \(object) .")
        }

        return lines.joined(separator: "\n")
    }

    private func formatSubject(_ subject: AnyRDFSubject) -> String {
        if let iri = subject.node as? IRI {
            return formatIri(iri)
        }
        if let blank = subject.node as? BlankNode {
            return "_:\(blank.identifier)"
        }
        return subject.description
    }

    private func formatPredicate(_ predicate: IRI) -> String {
        if predicate == RDF.Vocabulary.type {
            return "a"
        }
        return formatIri(predicate)
    }

    private func formatObject(_ object: AnyRDFObject) -> String {
        if let iri = object.node as? IRI {
            return formatIri(iri)
        }
        if let blank = object.node as? BlankNode {
            return "_:\(blank.identifier)"
        }
        if let literal = object.node as? Literal {
            return formatLiteral(literal)
        }
        if let tripleTerm = object.node as? TripleTerm {
            let s = formatSubject(tripleTerm.subject)
            let p = formatPredicate(tripleTerm.predicate)
            let o = formatObject(tripleTerm.object)
            return "<< \(s) \(p) \(o) >>"
        }
        return object.description
    }

    private func formatIri(_ iri: IRI) -> String {
        for (prefix, base) in prefixes {
            if iri.string.hasPrefix(base.string) {
                let local = String(iri.string.dropFirst(base.string.count))
                if isValidPrefixedLocal(local) {
                    return "\(prefix):\(local)"
                }
            }
        }
        return "<\(iri.string)>"
    }

    private func formatLiteral(_ literal: Literal) -> String {
        var value = "\"\(escapeString(literal.lexicalForm))\""
        if let lang = literal.languageTag {
            value += "@\(lang)"
            if let direction = literal.textDirection {
                value += "--\(direction.rawValue)"
            }
        } else if let datatype = literal.datatype {
            value += "^^\(formatIriString(datatype))"
        }
        return value
    }

    private func escapeString(_ string: String) -> String {
        var result = ""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\\": result.append("\\\\")
            case "\"": result.append("\\\"")
            case "\n": result.append("\\n")
            case "\r": result.append("\\r")
            case "\t": result.append("\\t")
            default:
                result.append(String(scalar))
            }
        }
        return result
    }

    private func isValidPrefixedLocal(_ local: String) -> Bool {
        guard !local.isEmpty else { return true }
        let invalidChars = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: ";,.[]()"))
        return local.rangeOfCharacter(from: invalidChars) == nil
    }

    private func formatIriString(_ iri: any Iri) -> String {
        if let concrete = iri as? IRI {
            return formatIri(concrete)
        }
        return "<\(iri.string)>"
    }
}

// MARK: - Parser

private struct TurtleParser {
    private var lexer: TurtleLexer
    private var prefixes: [String: IRI] = [:]
    private var baseIRI: IRI?
    private var graph = Graph()
    private var blankNodeCounter = 0
    private let generatedBlankNodePrefix = "genid"

    init(text: String, baseIRI: IRI?) {
        self.lexer = TurtleLexer(text)
        self.baseIRI = baseIRI
    }

    mutating func parseGraph() throws -> Graph {
        while true {
            lexer.skipWhitespaceAndComments()
            if lexer.isAtEnd { break }
            if try parseDirectiveIfPresent() {
                continue
            }
            try parseTriples()
        }
        return graph
    }

    private mutating func parseDirectiveIfPresent() throws -> Bool {
        if lexer.peek() == "@" {
            _ = lexer.advance()
            lexer.skipWhitespaceAndComments()
            if lexer.consumeWord("prefix", caseInsensitive: true) {
                try parsePrefixDirective()
                return true
            }
            if lexer.consumeWord("base", caseInsensitive: true) {
                try parseBaseDirective()
                return true
            }
            throw lexer.errorUnexpectedToken("@")
        }

        if lexer.consumeWord("PREFIX", caseInsensitive: true) {
            try parsePrefixDirective()
            return true
        }
        if lexer.consumeWord("BASE", caseInsensitive: true) {
            try parseBaseDirective()
            return true
        }
        return false
    }

    private mutating func parsePrefixDirective() throws {
        lexer.skipWhitespaceAndComments()
        let prefix = try parsePrefixLabel()
        lexer.skipWhitespaceAndComments()
        let iriRef = try parseIriRef()
        lexer.skipWhitespaceAndComments()
        try lexer.expect(".")
        prefixes[prefix] = iriRef
    }

    private mutating func parseBaseDirective() throws {
        lexer.skipWhitespaceAndComments()
        let iriRef = try parseIriRef()
        lexer.skipWhitespaceAndComments()
        try lexer.expect(".")
        baseIRI = iriRef
    }

    private mutating func parseTriples() throws {
        let subject = try parseSubject()
        lexer.skipWhitespaceAndComments()
        try parsePredicateObjectList(subject: subject)
        lexer.skipWhitespaceAndComments()
        try lexer.expect(".")
    }

    private mutating func parsePredicateObjectList(subject: AnyRDFSubject) throws {
        var continueList = true
        while continueList {
            let predicate = try parseVerb()
            lexer.skipWhitespaceAndComments()
            let objects = try parseObjectList()
            for object in objects {
                try addTriple(subject: subject, predicate: predicate, object: object)
            }
            lexer.skipWhitespaceAndComments()
            if lexer.peek() == ";" {
                _ = lexer.advance()
                lexer.skipWhitespaceAndComments()
                if lexer.peek() == "." || lexer.peek() == "]" {
                    return
                }
            } else {
                continueList = false
            }
        }
    }

    private mutating func parseVerb() throws -> IRI {
        if lexer.consumeWord("a", caseInsensitive: false, wordBoundary: true) {
            return RDF.Vocabulary.type
        }
        return try parseIri()
    }

    private mutating func parseObjectList() throws -> [AnyRDFObject] {
        var objects: [AnyRDFObject] = [try parseObject()]
        lexer.skipWhitespaceAndComments()
        while lexer.peek() == "," {
            _ = lexer.advance()
            lexer.skipWhitespaceAndComments()
            objects.append(try parseObject())
            lexer.skipWhitespaceAndComments()
        }
        return objects
    }

    private mutating func parseSubject() throws -> AnyRDFSubject {
        if lexer.peek() == "[" {
            let blank = try parseBlankNodePropertyList()
            return try AnyRDFSubject(blank)
        }
        if lexer.peek() == "(" {
            let obj = try parseCollection()
            return try asSubject(obj)
        }
        return try asSubject(parseIriOrBlankNode())
    }

    private mutating func parseObject() throws -> AnyRDFObject {
        if lexer.peek() == "[" {
            let blank = try parseBlankNodePropertyList()
            return AnyRDFObject(blank)
        }
        if lexer.peek() == "(" {
            return try parseCollection()
        }
        if lexer.starts(with: "<<") {
            let term = try parseTripleTerm()
            return AnyRDFObject(term)
        }
        if lexer.peek() == "<" || lexer.peek() == ":" || lexer.peek() == "_" || lexer.peek()?.isLetter == true {
            return parseIriOrBlankNode()
        }
        if lexer.peek() == "\"" || lexer.peek() == "'" {
            let literal = try parseLiteral()
            return AnyRDFObject(literal)
        }
        if let token = lexer.peek(), token == "-" || token == "+" || token.isNumber {
            let literal = try parseNumericOrBooleanLiteral()
            return AnyRDFObject(literal)
        }
        if lexer.consumeWord("true", caseInsensitive: true, wordBoundary: true) {
            return AnyRDFObject(try Literal("true", datatype: TurtleDatatypes.xsdBoolean))
        }
        if lexer.consumeWord("false", caseInsensitive: true, wordBoundary: true) {
            return AnyRDFObject(try Literal("false", datatype: TurtleDatatypes.xsdBoolean))
        }

        throw lexer.errorUnexpectedCharacter()
    }

    private mutating func parseBlankNodePropertyList() throws -> AnyRDFSubject {
        try lexer.expect("[")
        lexer.skipWhitespaceAndComments()
        let blank = try newBlankNode()
        if lexer.peek() == "]" {
            _ = lexer.advance()
            return AnyRDFSubject(blank)
        }
        let subject = try AnyRDFSubject(blank)
        try parsePredicateObjectList(subject: subject)
        lexer.skipWhitespaceAndComments()
        try lexer.expect("]")
        return subject
    }

    private mutating func parseCollection() throws -> AnyRDFObject {
        try lexer.expect("(")
        lexer.skipWhitespaceAndComments()
        if lexer.peek() == ")" {
            _ = lexer.advance()
            return AnyRDFObject(RDF.Vocabulary.nilValue)
        }

        var items: [AnyRDFObject] = []
        while lexer.peek() != ")" {
            items.append(try parseObject())
            lexer.skipWhitespaceAndComments()
        }
        try lexer.expect(")")

        let headBlank = try newBlankNode()
        var currentBlank = headBlank

        for (index, item) in items.enumerated() {
            let subject = try AnyRDFSubject(currentBlank)
            try addTriple(
                subject: subject,
                predicate: RDF.Vocabulary.first,
                object: item
            )

            if index == items.count - 1 {
                try addTriple(
                    subject: subject,
                    predicate: RDF.Vocabulary.rest,
                    object: AnyRDFObject(RDF.Vocabulary.nilValue)
                )
            } else {
                let nextBlank = try newBlankNode()
                try addTriple(
                    subject: subject,
                    predicate: RDF.Vocabulary.rest,
                    object: AnyRDFObject(nextBlank)
                )
                currentBlank = nextBlank
            }
        }

        return AnyRDFObject(headBlank)
    }

    private mutating func parseTripleTerm() throws -> TripleTerm {
        try lexer.expect("<<")
        lexer.skipWhitespaceAndComments()
        let subject = try parseSubject()
        lexer.skipWhitespaceAndComments()
        let predicate = try parseVerb()
        lexer.skipWhitespaceAndComments()
        let object = try parseObject()
        lexer.skipWhitespaceAndComments()
        try lexer.expect(">>")
        return TripleTerm(subject: subject, predicate: predicate, object: object)
    }

    private mutating func parseIriOrBlankNode() throws -> AnyRDFObject {
        if lexer.starts(with: "_:") {
            _ = lexer.advance()
            _ = lexer.advance()
            let label = try parseNameToken()
            return AnyRDFObject(try BlankNode(label))
        }
        let iri = try parseIri()
        return AnyRDFObject(iri)
    }

    private mutating func parseIri() throws -> IRI {
        if lexer.peek() == "<" {
            let value = try parseIriRefString()
            return try resolveIri(value)
        }
        if lexer.peek() == ":" || lexer.peek()?.isLetter == true || lexer.peek() == "_" {
            let (prefix, local) = try parsePrefixedName()
            guard let base = prefixes[prefix] else {
                throw lexer.errorUndefinedPrefix(prefix)
            }
            let iriString = base.string + local
            return try resolveIri(iriString)
        }
        throw lexer.errorUnexpectedCharacter()
    }

    private mutating func parseIriRef() throws -> IRI {
        let value = try parseIriRefString()
        return try resolveIri(value)
    }

    private mutating func parseIriRefString() throws -> String {
        try lexer.expect("<")
        var value = ""
        while let ch = lexer.peek() {
            if ch == ">" {
                _ = lexer.advance()
                return unescapeIri(value)
            }
            if ch == "\\" {
                _ = lexer.advance()
                guard let escaped = lexer.advance() else {
                    throw lexer.errorUnexpectedEnd()
                }
                switch escaped {
                case "u":
                    value.append(try lexer.readUnicodeScalar(count: 4))
                case "U":
                    value.append(try lexer.readUnicodeScalar(count: 8))
                default:
                    value.append(escaped)
                }
            } else {
                value.append(ch)
                _ = lexer.advance()
            }
        }
        throw lexer.errorUnexpectedEnd()
    }

    private mutating func parsePrefixedName() throws -> (String, String) {
        var prefix = ""
        if lexer.peek() == ":" {
            _ = lexer.advance()
        } else {
            prefix = try parseNameToken()
            try lexer.expect(":")
        }

        var local = ""
        while let ch = lexer.peek() {
            if ch.isWhitespace || ";,.[]()".contains(ch) {
                break
            }
            if ch == "\\" {
                _ = lexer.advance()
                guard let escaped = lexer.advance() else {
                    throw lexer.errorUnexpectedEnd()
                }
                switch escaped {
                case "u":
                    local.append(try lexer.readUnicodeScalar(count: 4))
                case "U":
                    local.append(try lexer.readUnicodeScalar(count: 8))
                default:
                    local.append(escaped)
                }
            } else {
                local.append(ch)
                _ = lexer.advance()
            }
        }
        return (prefix, local)
    }

    private mutating func parsePrefixLabel() throws -> String {
        var prefix = ""
        while let ch = lexer.peek() {
            if ch == ":" { _ = lexer.advance(); return prefix }
            if ch.isWhitespace { break }
            prefix.append(ch)
            _ = lexer.advance()
        }
        throw lexer.errorUnexpectedCharacter()
    }

    private mutating func parseNameToken() throws -> String {
        var token = ""
        while let ch = lexer.peek() {
            if ch.isWhitespace || ":;,.[]()".contains(ch) {
                break
            }
            token.append(ch)
            _ = lexer.advance()
        }
        if token.isEmpty {
            throw lexer.errorUnexpectedCharacter()
        }
        return token
    }

    private mutating func parseLiteral() throws -> Literal {
        let string = try parseStringLiteral()
        lexer.skipWhitespaceAndComments()
        if lexer.peek() == "@" {
            _ = lexer.advance()
            let lang = try parseLanguageTag()
            var direction: TextDirection? = nil
            if lexer.starts(with: "--") {
                _ = lexer.advance()
                _ = lexer.advance()
                let dirToken = try parseNameToken()
                guard let parsed = TextDirection(rawValue: dirToken) else {
                    throw lexer.errorUnexpectedToken(dirToken)
                }
                direction = parsed
            }
            return try Literal(string, languageTag: lang, textDirection: direction)
        }
        if lexer.starts(with: "^^") {
            _ = lexer.advance()
            _ = lexer.advance()
            let datatype = try parseIri()
            return try Literal(string, datatype: datatype)
        }
        return try Literal(string)
    }

    private mutating func parseStringLiteral() throws -> String {
        guard let quote = lexer.peek(), quote == "\"" || quote == "'" else {
            throw lexer.errorUnexpectedCharacter()
        }
        let quoteChar = quote
        _ = lexer.advance()

        var triple = false
        if lexer.peek() == quoteChar {
            _ = lexer.advance()
            if lexer.peek() == quoteChar {
                _ = lexer.advance()
                triple = true
            } else {
                return ""
            }
        }

        var value = ""
        while let ch = lexer.peek() {
            if ch == quoteChar {
                _ = lexer.advance()
                if triple {
                    if lexer.peek() == quoteChar {
                        _ = lexer.advance()
                        if lexer.peek() == quoteChar {
                            _ = lexer.advance()
                            return value
                        }
                        value.append(quoteChar)
                    } else {
                        value.append(ch)
                    }
                } else {
                    return value
                }
            } else if ch == "\\" {
                _ = lexer.advance()
                guard let escaped = lexer.advance() else {
                    throw lexer.errorUnexpectedEnd()
                }
                switch escaped {
                case "n": value.append("\n")
                case "t": value.append("\t")
                case "r": value.append("\r")
                case "\\": value.append("\\")
                case "\"": value.append("\"")
                case "'": value.append("'")
                case "u": value.append(try lexer.readUnicodeScalar(count: 4))
                case "U": value.append(try lexer.readUnicodeScalar(count: 8))
                default: value.append(escaped)
                }
            } else {
                value.append(ch)
                _ = lexer.advance()
            }
        }
        throw lexer.errorUnexpectedEnd()
    }

    private mutating func parseLanguageTag() throws -> String {
        var tag = ""
        while let ch = lexer.peek() {
            if ch.isWhitespace || ";,.[]()".contains(ch) {
                break
            }
            if ch == "-" || ch.isLetter || ch.isNumber {
                tag.append(ch)
                _ = lexer.advance()
            } else {
                break
            }
        }
        if tag.isEmpty {
            throw lexer.errorUnexpectedCharacter()
        }
        return tag.lowercased()
    }

    private mutating func parseNumericOrBooleanLiteral() throws -> Literal {
        let token = try parseNumericToken()
        let lower = token.lowercased()
        if lower == "true" || lower == "false" {
            return try Literal(lower, datatype: TurtleDatatypes.xsdBoolean)
        }
        if lower.contains("e") {
            return try Literal(token, datatype: TurtleDatatypes.xsdDouble)
        }
        if lower.contains(".") {
            return try Literal(token, datatype: TurtleDatatypes.xsdDecimal)
        }
        return try Literal(token, datatype: TurtleDatatypes.xsdInteger)
    }

    private mutating func resolveIri(_ value: String) throws -> IRI {
        if let base = baseIRI {
            if let resolved = URL(string: value, relativeTo: try base.asURL())?.absoluteString {
                return try IRI(resolved)
            }
        }
        return try IRI(value)
    }

    private func unescapeIri(_ value: String) -> String {
        value
    }

    private mutating func newBlankNode() throws -> BlankNode {
        defer { blankNodeCounter += 1 }
        return try BlankNode("\(generatedBlankNodePrefix)\(blankNodeCounter)")
    }

    private mutating func addTriple(subject: AnyRDFSubject, predicate: IRI, object: AnyRDFObject) throws {
        let triple = Graph.TripleType(subject: subject, predicate: predicate, object: object)
        do {
            try graph.insert(triple)
        } catch RDFGraphError.duplicateTriple {
            return
        }
    }

    private func asSubject(_ object: AnyRDFObject) throws -> AnyRDFSubject {
        if let iri = object.node as? IRI {
            return try AnyRDFSubject(iri)
        }
        if let blank = object.node as? BlankNode {
            return try AnyRDFSubject(blank)
        }
        throw TurtleError.invalidToken("Object is not a valid subject", line: lexer.line, column: lexer.column)
    }

    private mutating func parseNumericToken() throws -> String {
        var token = ""
        while let ch = lexer.peek() {
            if ch.isWhitespace || ";,[]()".contains(ch) {
                break
            }
            if ch == ";" || ch == "," || ch == "]" || ch == ")" {
                break
            }
            if ch == "." {
                let next = lexer.peekNext()
                if next == nil || next?.isWhitespace == true || ";,])".contains(next ?? " ") {
                    break
                }
            }
            if ch == "." || ch == "+" || ch == "-" || ch == "e" || ch == "E" || ch.isNumber {
                token.append(ch)
                _ = lexer.advance()
            } else {
                break
            }
        }
        if token.isEmpty {
            throw lexer.errorUnexpectedCharacter()
        }
        return token
    }

    private func isBooleanBoundary(offset: Int) -> Bool {
        guard let next = lexer.peek(after: offset) else { return true }
        if next.isWhitespace { return true }
        return ";,.])".contains(next)
    }
}

// MARK: - Lexer

private struct TurtleLexer {
    private let text: String
    private var index: String.Index
    private(set) var line: Int = 1
    private(set) var column: Int = 1

    init(_ text: String) {
        self.text = text
        self.index = text.startIndex
    }

    var isAtEnd: Bool {
        index >= text.endIndex
    }

    mutating func skipWhitespaceAndComments() {
        while let ch = peek() {
            if ch == "#" {
                skipComment()
            } else if ch.isWhitespace {
                _ = advance()
            } else {
                break
            }
        }
    }

    private mutating func skipComment() {
        while let ch = advance() {
            if ch == "\n" { break }
        }
    }

    func peek() -> Character? {
        guard index < text.endIndex else { return nil }
        return text[index]
    }

    func peekNext() -> Character? {
        guard index < text.endIndex else { return nil }
        let nextIndex = text.index(after: index)
        guard nextIndex < text.endIndex else { return nil }
        return text[nextIndex]
    }

    func peek(after offset: Int) -> Character? {
        guard offset > 0 else { return peek() }
        var cursor = index
        for _ in 0..<offset {
            if cursor >= text.endIndex { return nil }
            cursor = text.index(after: cursor)
        }
        return cursor < text.endIndex ? text[cursor] : nil
    }

    mutating func advance() -> Character? {
        guard index < text.endIndex else { return nil }
        let ch = text[index]
        index = text.index(after: index)
        if ch == "\n" {
            line += 1
            column = 1
        } else {
            column += 1
        }
        return ch
    }

    mutating func expect(_ string: String) throws {
        for ch in string {
            guard let current = peek(), current == ch else {
                throw errorUnexpectedCharacter()
            }
            _ = advance()
        }
    }

    func starts(with string: String, caseInsensitive: Bool = false) -> Bool {
        let substring = String(text[index...].prefix(string.count))
        if caseInsensitive {
            return substring.lowercased() == string.lowercased()
        }
        return substring == string
    }

    mutating func consumeWord(_ word: String, caseInsensitive: Bool, wordBoundary: Bool = false) -> Bool {
        let originalIndex = index
        let originalLine = line
        let originalColumn = column

        if starts(with: word, caseInsensitive: caseInsensitive) {
            for _ in word { _ = advance() }
            if wordBoundary {
                if let ch = peek(), ch.isLetter || ch.isNumber || ch == "_" {
                    index = originalIndex
                    line = originalLine
                    column = originalColumn
                    return false
                }
            }
            return true
        }
        return false
    }

    mutating func readUnicodeScalar(count: Int) throws -> String {
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

    func errorUnexpectedEnd() -> TurtleError {
        TurtleError.unexpectedEndOfInput(line: line, column: column)
    }

    func errorUnexpectedCharacter() -> TurtleError {
        if let ch = peek() {
            return TurtleError.unexpectedCharacter(ch, line: line, column: column)
        }
        return TurtleError.unexpectedEndOfInput(line: line, column: column)
    }

    func errorUnexpectedToken(_ token: String) -> TurtleError {
        TurtleError.invalidToken(token, line: line, column: column)
    }

    func errorUndefinedPrefix(_ prefix: String) -> TurtleError {
        TurtleError.undefinedPrefix(prefix, line: line, column: column)
    }
}

// MARK: - Datatypes

private enum TurtleDatatypes {
    private static let namespace = "http://www.w3.org/2001/XMLSchema#"
    static let xsdInteger = try! IRI("\(namespace)integer")
    static let xsdDecimal = try! IRI("\(namespace)decimal")
    static let xsdDouble = try! IRI("\(namespace)double")
    static let xsdBoolean = try! IRI("\(namespace)boolean")
}
