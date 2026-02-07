import Foundation

// MARK: - N-Triples import / export

public enum NTriplesError: Error, CustomStringConvertible {
    case unexpectedEndOfInput(line: Int, column: Int)
    case unexpectedCharacter(Character, line: Int, column: Int)
    case invalidToken(String, line: Int, column: Int)
    case invalidBlankNodeLabel(line: Int, column: Int)
    case invalidLanguageTag(line: Int, column: Int)
    case invalidIriRef(line: Int, column: Int)

    public var description: String {
        switch self {
        case let .unexpectedEndOfInput(line, column):
            return "Unexpected end of input at line \(line), column \(column)."
        case let .unexpectedCharacter(char, line, column):
            return "Unexpected character '\(char)' at line \(line), column \(column)."
        case let .invalidToken(token, line, column):
            return "Invalid token '\(token)' at line \(line), column \(column)."
        case let .invalidBlankNodeLabel(line, column):
            return "Invalid blank node label at line \(line), column \(column)."
        case let .invalidLanguageTag(line, column):
            return "Invalid language tag at line \(line), column \(column)."
        case let .invalidIriRef(line, column):
            return "Invalid IRI reference at line \(line), column \(column)."
        }
    }
}

public extension Graph {
    init(ntriples: String) throws {
        var parser = NTriplesParser(text: ntriples)
        self = try parser.parseGraph()
    }

    func ntriplesString() -> String {
        let serializer = NTriplesSerializer()
        return serializer.serialize(graph: self)
    }
}

// MARK: - Serializer

private struct NTriplesSerializer {
    func serialize(graph: Graph) -> String {
        let sortedTriples = graph.triples.sorted { lhs, rhs in
            let ls = lhs.subject.description
            let rs = rhs.subject.description
            if ls != rs { return ls < rs }
            let lp = lhs.predicate.string
            let rp = rhs.predicate.string
            if lp != rp { return lp < rp }
            return lhs.object.description < rhs.object.description
        }

        var lines: [String] = []
        lines.reserveCapacity(sortedTriples.count)
        for triple in sortedTriples {
            lines.append(
                "\(formatSubject(triple.subject)) \(formatPredicate(triple.predicate)) \(formatObject(triple.object)) ."
            )
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
        formatIri(predicate)
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
            return "<<( \(s) \(p) \(o) )>>"
        }
        return object.description
    }

    private func formatIri(_ iri: IRI) -> String {
        "<\(iri.string)>"
    }

    private func formatLiteral(_ literal: Literal) -> String {
        var value = "\"\(escapeString(literal.lexicalForm))\""
        if let lang = literal.languageTag {
            value += "@\(lang)"
            if let direction = literal.textDirection {
                value += "--\(direction.rawValue)"
            }
        } else if let datatype = literal.datatype {
            value += "^^<\(datatype.string)>"
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
            case "\u{0008}": result.append("\\b")
            case "\u{000C}": result.append("\\f")
            default:
                result.append(String(scalar))
            }
        }
        return result
    }
}

// MARK: - Parser

private struct NTriplesParser {
    private var lexer: NTriplesLexer
    private var graph = Graph()

    init(text: String) {
        self.lexer = NTriplesLexer(text)
    }

    mutating func parseGraph() throws -> Graph {
        while true {
            lexer.skipHorizontalWhitespace()
            if lexer.isAtEnd { break }
            if lexer.consumeEOL() { continue }
            if lexer.peek() == "#" {
                lexer.skipComment()
                _ = lexer.consumeEOL()
                continue
            }
            if try parseVersionDirectiveIfPresent() { continue }
            try parseTriple()
        }
        return graph
    }

    private mutating func parseVersionDirectiveIfPresent() throws -> Bool {
        if lexer.consumeWord("VERSION", caseInsensitive: false, wordBoundary: true) {
            try lexer.requireHorizontalWhitespace()
            _ = try parseStringLiteral()
            lexer.skipHorizontalWhitespace()
            if lexer.peek() == "#" { lexer.skipComment() }
            _ = lexer.consumeEOL()
            return true
        }
        return false
    }

    private mutating func parseTriple() throws {
        let subject = try parseSubject()
        try lexer.requireHorizontalWhitespace()
        let predicate = try parsePredicate()
        try lexer.requireHorizontalWhitespace()
        let object = try parseObject()
        lexer.skipHorizontalWhitespace()
        try lexer.expect(".")
        lexer.skipHorizontalWhitespace()
        if lexer.peek() == "#" { lexer.skipComment() }
        if !lexer.consumeEOL(), !lexer.isAtEnd {
            throw lexer.errorUnexpectedCharacter()
        }

        let triple = Graph.TripleType(subject: subject, predicate: predicate, object: object)
        do {
            try graph.insert(triple)
        } catch RDFGraphError.duplicateTriple {
            return
        }
    }

    private mutating func parseSubject() throws -> AnyRDFSubject {
        if lexer.starts(with: "_:") {
            let blank = try parseBlankNode()
            return try AnyRDFSubject(blank)
        }
        let iri = try parseIriRef()
        return try AnyRDFSubject(iri)
    }

    private mutating func parsePredicate() throws -> IRI {
        return try parseIriRef()
    }

    private mutating func parseObject() throws -> AnyRDFObject {
        if lexer.starts(with: "<<(") {
            let term = try parseTripleTerm()
            return AnyRDFObject(term)
        }
        if lexer.starts(with: "_:") {
            let blank = try parseBlankNode()
            return AnyRDFObject(blank)
        }
        if lexer.peek() == "<" {
            let iri = try parseIriRef()
            return AnyRDFObject(iri)
        }
        if lexer.peek() == "\"" {
            let literal = try parseLiteral()
            return AnyRDFObject(literal)
        }

        throw lexer.errorUnexpectedCharacter()
    }

    private mutating func parseTripleTerm() throws -> TripleTerm {
        try lexer.expect("<<(")
        lexer.skipHorizontalWhitespace()
        let subject = try parseSubject()
        try lexer.requireHorizontalWhitespace()
        let predicate = try parsePredicate()
        try lexer.requireHorizontalWhitespace()
        let object = try parseObject()
        lexer.skipHorizontalWhitespace()
        try lexer.expect(")>>")
        return TripleTerm(subject: subject, predicate: predicate, object: object)
    }

    private mutating func parseBlankNode() throws -> BlankNode {
        try lexer.expect("_:")
        let label = try parseBlankNodeLabel()
        return try BlankNode(label)
    }

    private mutating func parseBlankNodeLabel() throws -> String {
        var token = ""
        guard let first = lexer.peek() else { throw lexer.errorUnexpectedEnd() }
        guard isPNCharsU(first) || isDigit(first) else {
            throw NTriplesError.invalidBlankNodeLabel(line: lexer.line, column: lexer.column)
        }
        token.append(first)
        _ = lexer.advance()

        var lastWasDot = false
        while let ch = lexer.peek() {
            if isPNChars(ch) {
                token.append(ch)
                lastWasDot = false
                _ = lexer.advance()
            } else if ch == "." {
                token.append(ch)
                lastWasDot = true
                _ = lexer.advance()
            } else {
                break
            }
        }

        if lastWasDot {
            throw NTriplesError.invalidBlankNodeLabel(line: lexer.line, column: lexer.column)
        }
        return token
    }

    private mutating func parseIriRef() throws -> IRI {
        let value = try parseIriRefString()
        return try IRI(value)
    }

    private mutating func parseIriRefString() throws -> String {
        try lexer.expect("<")
        var value = ""
        while let ch = lexer.peek() {
            if ch == ">" {
                _ = lexer.advance()
                return value
            }
            if ch == "\\" {
                _ = lexer.advance()
                guard let escaped = lexer.advance() else { throw lexer.errorUnexpectedEnd() }
                switch escaped {
                case "u":
                    value.append(try lexer.readUnicodeScalar(count: 4))
                case "U":
                    value.append(try lexer.readUnicodeScalar(count: 8))
                default:
                    throw NTriplesError.invalidIriRef(line: lexer.line, column: lexer.column)
                }
                continue
            }
            if isInvalidIriChar(ch) {
                throw NTriplesError.invalidIriRef(line: lexer.line, column: lexer.column)
            }
            value.append(ch)
            _ = lexer.advance()
        }
        throw lexer.errorUnexpectedEnd()
    }

    private mutating func parseLiteral() throws -> Literal {
        let string = try parseStringLiteral()
        lexer.skipHorizontalWhitespace()
        if lexer.peek() == "@" {
            _ = lexer.advance()
            let (lang, direction) = try parseLangDir()
            return try Literal(string, languageTag: lang, textDirection: direction)
        }
        if lexer.starts(with: "^^") {
            _ = lexer.advance()
            _ = lexer.advance()
            let datatype = try parseIriRef()
            return try Literal(string, datatype: datatype)
        }
        return try Literal(string)
    }

    private mutating func parseStringLiteral() throws -> String {
        try lexer.expect("\"")
        var value = ""
        while let ch = lexer.peek() {
            if ch == "\"" {
                _ = lexer.advance()
                return value
            }
            if ch == "\n" || ch == "\r" {
                throw lexer.errorUnexpectedCharacter()
            }
            if ch == "\\" {
                _ = lexer.advance()
                guard let escaped = lexer.advance() else { throw lexer.errorUnexpectedEnd() }
                switch escaped {
                case "t": value.append("\t")
                case "b": value.append("\u{0008}")
                case "n": value.append("\n")
                case "r": value.append("\r")
                case "f": value.append("\u{000C}")
                case "\\": value.append("\\")
                case "\"": value.append("\"")
                case "'": value.append("'")
                case "u": value.append(try lexer.readUnicodeScalar(count: 4))
                case "U": value.append(try lexer.readUnicodeScalar(count: 8))
                default:
                    throw lexer.errorUnexpectedCharacter()
                }
            } else {
                value.append(ch)
                _ = lexer.advance()
            }
        }
        throw lexer.errorUnexpectedEnd()
    }

    private mutating func parseLangDir() throws -> (String, TextDirection?) {
        var tag = ""
        guard let first = lexer.peek(), isAlpha(first) else {
            throw NTriplesError.invalidLanguageTag(line: lexer.line, column: lexer.column)
        }
        while let ch = lexer.peek(), isAlpha(ch) {
            tag.append(ch)
            _ = lexer.advance()
        }

        while lexer.peek() == "-" && lexer.peekNext() != "-" {
            _ = lexer.advance()
            tag.append("-")
            var hadSegment = false
            while let ch = lexer.peek(), isAlphaNumeric(ch) {
                hadSegment = true
                tag.append(ch)
                _ = lexer.advance()
            }
            if !hadSegment {
                throw NTriplesError.invalidLanguageTag(line: lexer.line, column: lexer.column)
            }
        }

        var direction: TextDirection? = nil
        if lexer.peek() == "-" && lexer.peekNext() == "-" {
            _ = lexer.advance()
            _ = lexer.advance()
            var dirToken = ""
            while let ch = lexer.peek(), isAlpha(ch) {
                dirToken.append(ch)
                _ = lexer.advance()
            }
            let normalized = dirToken.lowercased()
            if let parsed = TextDirection(rawValue: normalized) {
                direction = parsed
            } else {
                throw NTriplesError.invalidLanguageTag(line: lexer.line, column: lexer.column)
            }
        }

        return (tag.lowercased(), direction)
    }

    private func isAlpha(_ ch: Character) -> Bool {
        guard let scalar = singleScalar(ch) else { return false }
        return (0x41...0x5A).contains(scalar.value) || (0x61...0x7A).contains(scalar.value)
    }

    private func isDigit(_ ch: Character) -> Bool {
        guard let scalar = singleScalar(ch) else { return false }
        return (0x30...0x39).contains(scalar.value)
    }

    private func isAlphaNumeric(_ ch: Character) -> Bool {
        isAlpha(ch) || isDigit(ch)
    }

    private func isInvalidIriChar(_ ch: Character) -> Bool {
        guard let scalar = singleScalar(ch) else { return true }
        let value = scalar.value
        if value <= 0x20 { return true }
        if "<>\"{}|^`".contains(ch) { return true }
        return false
    }

    private func isPNCharsU(_ ch: Character) -> Bool {
        guard let scalar = singleScalar(ch) else { return false }
        return scalar.value == 0x5F || isPNCharsBase(scalar)
    }

    private func isPNChars(_ ch: Character) -> Bool {
        guard let scalar = singleScalar(ch) else { return false }
        let value = scalar.value
        if isPNCharsU(ch) { return true }
        if value == 0x2D { return true }
        if (0x30...0x39).contains(value) { return true }
        if value == 0x00B7 { return true }
        if (0x0300...0x036F).contains(value) { return true }
        if (0x203F...0x2040).contains(value) { return true }
        return false
    }

    private func isPNCharsBase(_ scalar: UnicodeScalar) -> Bool {
        let value = scalar.value
        switch value {
        case 0x41...0x5A, 0x61...0x7A:
            return true
        case 0x00C0...0x00D6,
             0x00D8...0x00F6,
             0x00F8...0x02FF,
             0x0370...0x037D,
             0x037F...0x1FFF,
             0x200C...0x200D,
             0x2070...0x218F,
             0x2C00...0x2FEF,
             0x3001...0xD7FF,
             0xF900...0xFDCF,
             0xFDF0...0xFFFD,
             0x10000...0xEFFFF:
            return true
        default:
            return false
        }
    }

    private func singleScalar(_ ch: Character) -> UnicodeScalar? {
        let scalars = String(ch).unicodeScalars
        return scalars.count == 1 ? scalars.first : nil
    }
}

// MARK: - Lexer

private struct NTriplesLexer {
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

    mutating func skipHorizontalWhitespace() {
        while let ch = peek(), ch == " " || ch == "\t" {
            _ = advance()
        }
    }

    mutating func requireHorizontalWhitespace() throws {
        if let ch = peek(), ch == " " || ch == "\t" {
            skipHorizontalWhitespace()
            return
        }
        throw errorUnexpectedCharacter()
    }

    mutating func skipComment() {
        while let ch = advance() {
            if ch == "\n" || ch == "\r" { break }
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

    mutating func advance() -> Character? {
        guard index < text.endIndex else { return nil }
        let ch = text[index]
        index = text.index(after: index)
        if ch == "\n" {
            line += 1
            column = 1
        } else if ch == "\r" {
            line += 1
            column = 1
        } else {
            column += 1
        }
        return ch
    }

    mutating func consumeEOL() -> Bool {
        guard let ch = peek(), ch == "\n" || ch == "\r" else { return false }
        var consumed = false
        while let c = peek(), c == "\n" || c == "\r" {
            _ = advance()
            consumed = true
        }
        return consumed
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
        if caseInsensitive { return substring.lowercased() == string.lowercased() }
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

    func errorUnexpectedEnd() -> NTriplesError {
        NTriplesError.unexpectedEndOfInput(line: line, column: column)
    }

    func errorUnexpectedCharacter() -> NTriplesError {
        if let ch = peek() {
            return NTriplesError.unexpectedCharacter(ch, line: line, column: column)
        }
        return NTriplesError.unexpectedEndOfInput(line: line, column: column)
    }

    func errorUnexpectedToken(_ token: String) -> NTriplesError {
        NTriplesError.invalidToken(token, line: line, column: column)
    }
}
