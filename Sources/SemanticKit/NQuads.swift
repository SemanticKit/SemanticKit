import Foundation

// MARK: - N-Quads import / export

public enum NQuadsError: Error, CustomStringConvertible {
    case unexpectedEndOfInput(line: Int, column: Int)
    case unexpectedCharacter(Character, line: Int, column: Int)
    case invalidToken(String, line: Int, column: Int)
    case invalidGraphName(line: Int, column: Int)

    public var description: String {
        switch self {
        case let .unexpectedEndOfInput(line, column):
            return "Unexpected end of input at line \(line), column \(column)."
        case let .unexpectedCharacter(char, line, column):
            return "Unexpected character '\(char)' at line \(line), column \(column)."
        case let .invalidToken(token, line, column):
            return "Invalid token '\(token)' at line \(line), column \(column)."
        case let .invalidGraphName(line, column):
            return "Invalid graph name at line \(line), column \(column). Graph names must be IRIs."
        }
    }
}

public extension Dataset {
    init(nquads: String) throws {
        var parser = NQuadsParser(text: nquads)
        self = try parser.parseDataset()
    }

    func nquadsString() -> String {
        let serializer = NQuadsSerializer()
        return serializer.serialize(dataset: self)
    }
}

// MARK: - Serializer

private struct NQuadsSerializer {
    func serialize(dataset: Dataset) -> String {
        var lines: [String] = []

        let defaultTriples = dataset.defaultGraph.triples.sorted { lhs, rhs in
            let ls = lhs.subject.description
            let rs = rhs.subject.description
            if ls != rs { return ls < rs }
            let lp = lhs.predicate.string
            let rp = rhs.predicate.string
            if lp != rp { return lp < rp }
            return lhs.object.description < rhs.object.description
        }

        for triple in defaultTriples {
            lines.append("\(formatSubject(triple.subject)) \(formatPredicate(triple.predicate)) \(formatObject(triple.object)) .")
        }

        for (graphName, graph) in dataset.namedGraphs.sorted(by: { $0.key.string < $1.key.string }) {
            let graphTriples = graph.triples.sorted { lhs, rhs in
                let ls = lhs.subject.description
                let rs = rhs.subject.description
                if ls != rs { return ls < rs }
                let lp = lhs.predicate.string
                let rp = rhs.predicate.string
                if lp != rp { return lp < rp }
                return lhs.object.description < rhs.object.description
            }

            for triple in graphTriples {
                lines.append("\(formatSubject(triple.subject)) \(formatPredicate(triple.predicate)) \(formatObject(triple.object)) \(formatIri(graphName)) .")
            }
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
            default:
                result.append(String(scalar))
            }
        }
        return result
    }
}

// MARK: - Parser

private struct NQuadsParser {
    private var lexer: NQuadsLexer
    private var defaultGraph = Graph()
    private var namedGraphs: [IRI: Graph] = [:]

    init(text: String) {
        self.lexer = NQuadsLexer(text)
    }

    mutating func parseDataset() throws -> Dataset {
        while true {
            lexer.skipWhitespaceAndComments()
            if lexer.isAtEnd { break }
            if try parseVersionDirectiveIfPresent() {
                continue
            }
            try parseQuad()
        }

        return Dataset(defaultGraph: defaultGraph, namedGraphs: namedGraphs)
    }

    private mutating func parseVersionDirectiveIfPresent() throws -> Bool {
        if lexer.consumeWord("VERSION", caseInsensitive: false, wordBoundary: true) {
            lexer.skipWhitespaceAndComments()
            _ = try parseStringLiteral()
            lexer.skipWhitespaceAndComments()
            if lexer.peek() == "." {
                _ = lexer.advance()
            }
            return true
        }
        return false
    }

    private mutating func parseQuad() throws {
        let subject = try parseSubject()
        lexer.skipWhitespaceAndComments()
        let predicate = try parsePredicate()
        lexer.skipWhitespaceAndComments()
        let object = try parseObject()
        lexer.skipWhitespaceAndComments()

        var graphName: IRI? = nil
        if let ch = lexer.peek(), ch != "." {
            graphName = try parseGraphName()
            lexer.skipWhitespaceAndComments()
        }

        try lexer.expect(".")
        try addQuad(subject: subject, predicate: predicate, object: object, graphName: graphName)
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
        if lexer.starts(with: "<<") {
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
        if lexer.peek() == "\"" || lexer.peek() == "'" {
            let literal = try parseLiteral()
            return AnyRDFObject(literal)
        }

        throw lexer.errorUnexpectedCharacter()
    }

    private mutating func parseGraphName() throws -> IRI {
        if lexer.starts(with: "_:") {
            _ = try parseBlankNode()
            throw NQuadsError.invalidGraphName(line: lexer.line, column: lexer.column)
        }
        return try parseIriRef()
    }

    private mutating func parseTripleTerm() throws -> TripleTerm {
        try lexer.expect("<<")
        lexer.skipWhitespaceAndComments()
        var hasParens = false
        if lexer.peek() == "(" {
            hasParens = true
            _ = lexer.advance()
            lexer.skipWhitespaceAndComments()
        }
        let subject = try parseSubject()
        lexer.skipWhitespaceAndComments()
        let predicate = try parsePredicate()
        lexer.skipWhitespaceAndComments()
        let object = try parseObject()
        lexer.skipWhitespaceAndComments()
        if hasParens {
            try lexer.expect(")")
            lexer.skipWhitespaceAndComments()
        }
        try lexer.expect(">>")
        return TripleTerm(subject: subject, predicate: predicate, object: object)
    }

    private mutating func parseBlankNode() throws -> BlankNode {
        try lexer.expect("_:")
        let label = try parseNameToken()
        return try BlankNode(label)
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
            let datatype = try parseIriRef()
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

        var value = ""
        while let ch = lexer.peek() {
            if ch == quoteChar {
                _ = lexer.advance()
                return value
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
            if ch.isWhitespace { break }
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

    private mutating func parseNameToken() throws -> String {
        var token = ""
        while let ch = lexer.peek() {
            if ch.isWhitespace || "<>\"'".contains(ch) { break }
            if ch == "." {
                if lexer.peekNext()?.isWhitespace == true { break }
            }
            token.append(ch)
            _ = lexer.advance()
        }
        if token.isEmpty {
            throw lexer.errorUnexpectedCharacter()
        }
        return token
    }

    private mutating func addQuad(
        subject: AnyRDFSubject,
        predicate: IRI,
        object: AnyRDFObject,
        graphName: IRI?
    ) throws {
        let triple = Graph.TripleType(subject: subject, predicate: predicate, object: object)
        if let name = graphName {
            var graph = try (namedGraphs[name] ?? Graph(name: name))
            do {
                try graph.insert(triple)
            } catch RDFGraphError.duplicateTriple {
                return
            }
            namedGraphs[name] = graph
        } else {
            do {
                try defaultGraph.insert(triple)
            } catch RDFGraphError.duplicateTriple {
                return
            }
        }
    }
}

// MARK: - Lexer

private struct NQuadsLexer {
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

    func errorUnexpectedEnd() -> NQuadsError {
        NQuadsError.unexpectedEndOfInput(line: line, column: column)
    }

    func errorUnexpectedCharacter() -> NQuadsError {
        if let ch = peek() {
            return NQuadsError.unexpectedCharacter(ch, line: line, column: column)
        }
        return NQuadsError.unexpectedEndOfInput(line: line, column: column)
    }

    func errorUnexpectedToken(_ token: String) -> NQuadsError {
        NQuadsError.invalidToken(token, line: line, column: column)
    }
}
