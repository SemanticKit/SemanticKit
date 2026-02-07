import Foundation

// MARK: - RDF/XML import / export

public enum RDFXMLError: Error, CustomStringConvertible {
    case invalidDocument(String)
    case invalidElement(String)
    case invalidAttribute(String)
    case invalidIri(String)
    case invalidTripleTerm(String)

    public var description: String {
        switch self {
        case let .invalidDocument(message):
            return "Invalid RDF/XML document: \(message)"
        case let .invalidElement(message):
            return "Invalid RDF/XML element: \(message)"
        case let .invalidAttribute(message):
            return "Invalid RDF/XML attribute: \(message)"
        case let .invalidIri(message):
            return "Invalid IRI: \(message)"
        case let .invalidTripleTerm(message):
            return "Invalid triple term: \(message)"
        }
    }
}

public extension Graph {
    init(rdfxml: String, baseIRI: IRI? = nil) throws {
        var parser = RDFXMLParser(text: rdfxml, baseIRI: baseIRI)
        self = try parser.parseGraph()
    }

    func rdfxmlString(baseIRI: IRI? = nil) -> String {
        let serializer = RDFXMLSerializer(baseIRI: baseIRI)
        return serializer.serialize(graph: self)
    }
}

// MARK: - XML tree model

private enum XMLChild {
    case element(XMLElement)
    case text(String)
}

private struct XMLAttribute {
    let localName: String
    let prefix: String?
    let namespaceURI: String?
    let value: String
}

private final class XMLElement {
    let localName: String
    let prefix: String?
    let namespaceURI: String?
    var attributes: [XMLAttribute]
    var children: [XMLChild] = []

    init(localName: String, prefix: String?, namespaceURI: String?, attributes: [XMLAttribute]) {
        self.localName = localName
        self.prefix = prefix
        self.namespaceURI = namespaceURI
        self.attributes = attributes
    }
}

private final class XMLTreeBuilder: NSObject, XMLParserDelegate {
    private var root: XMLElement?
    private var stack: [XMLElement] = []
    private var namespaceStack: [[String: String]] = [
        [
            "xml": "http://www.w3.org/XML/1998/namespace",
            "xmlns": "http://www.w3.org/2000/xmlns/"
        ]
    ]
    private var pendingNamespaceMappings: [String: String] = [:]
    private(set) var parseError: Error?

    func parser(_ parser: XMLParser, didStartMappingPrefix prefix: String?, toURI namespaceURI: String) {
        let key = prefix ?? ""
        pendingNamespaceMappings[key] = namespaceURI
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let mapping = mergedNamespaces()
        namespaceStack.append(mapping)
        pendingNamespaceMappings.removeAll()

        let (prefix, localName) = splitQName(qName ?? elementName)
        let attributes = attributeDict.map { key, value -> XMLAttribute in
            let (attrPrefix, attrLocal) = splitQName(key)
            let attrNamespace = attrPrefix.flatMap { mapping[$0] }
            return XMLAttribute(localName: attrLocal, prefix: attrPrefix, namespaceURI: attrNamespace, value: value)
        }

        let element = XMLElement(localName: localName, prefix: prefix, namespaceURI: namespaceURI, attributes: attributes)
        if let current = stack.last {
            current.children.append(.element(element))
        } else {
            root = element
        }
        stack.append(element)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard let current = stack.last else { return }
        current.children.append(.text(string))
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        _ = stack.popLast()
        _ = namespaceStack.popLast()
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }

    func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error) {
        self.parseError = validationError
    }

    func buildRoot(from data: Data) throws -> XMLElement {
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = true
        parser.delegate = self
        parser.parse()
        if let error = parseError ?? parser.parserError {
            throw error
        }
        guard let root else {
            throw RDFXMLError.invalidDocument("No document element.")
        }
        return root
    }

    private func mergedNamespaces() -> [String: String] {
        var result = namespaceStack.last ?? [:]
        for (key, value) in pendingNamespaceMappings {
            result[key] = value
        }
        return result
    }

    private func splitQName(_ name: String) -> (String?, String) {
        if let index = name.firstIndex(of: ":") {
            let prefix = String(name[..<index])
            let local = String(name[name.index(after: index)...])
            return (prefix, local)
        }
        return (nil, name)
    }
}

// MARK: - RDF/XML parser

private struct RDFXMLParser {
    private let text: String
    private let baseIRI: IRI?
    private var graph = Graph()
    private var blankNodeCounter: Int = 0

    private let rdfNamespace = RDF.Vocabulary.namespace
    private let itsNamespace = "http://www.w3.org/2005/11/its"

    init(text: String, baseIRI: IRI?) {
        self.text = text
        self.baseIRI = baseIRI
    }

    mutating func parseGraph() throws -> Graph {
        let builder = XMLTreeBuilder()
        let data = Data(text.utf8)
        let root = try builder.buildRoot(from: data)

        if isRdfElement(root, localName: "RDF") {
            for child in root.children {
                if case let .element(element) = child {
                    _ = try parseNodeElement(element, inherited: makeContext(from: root, base: baseIRI))
                } else if case let .text(text) = child, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw RDFXMLError.invalidDocument("Unexpected text at document root.")
                }
            }
        } else {
            _ = try parseNodeElement(root, inherited: makeContext(from: root, base: baseIRI))
        }
        return graph
    }

    private struct ElementContext {
        let baseIRI: IRI?
        let language: String?
        let direction: TextDirection?
    }

    private func makeContext(from element: XMLElement, base: IRI?) throws -> ElementContext {
        let baseValue = attributeValue(element, namespace: "http://www.w3.org/XML/1998/namespace", localName: "base")
        let baseIRI = try resolveBase(baseValue, inherited: base)
        let languageValue = attributeValue(element, namespace: "http://www.w3.org/XML/1998/namespace", localName: "lang")
        let language = languageValue?.isEmpty == true ? nil : languageValue
        let directionValue = attributeValue(element, namespace: itsNamespace, localName: "dir")
        let direction = directionValue.flatMap { TextDirection(rawValue: $0.lowercased()) }
        return ElementContext(baseIRI: baseIRI, language: language ?? base?.scheme.isEmpty == false ? nil : language, direction: direction)
    }

    private mutating func parseNodeElement(_ element: XMLElement, inherited: ElementContext) throws -> AnyRDFSubject {
        let context = try elementContext(element, inherited: inherited)
        let subject = try parseSubject(from: element, context: context)

        if !isRdfElement(element, localName: "Description") {
            let typeIRI = try elementIRI(element)
            try insertTriple(subject: subject, predicate: RDF.Vocabulary.type, object: AnyRDFObject(typeIRI))
        }

        for attr in element.attributes where isPropertyAttribute(attr) {
            let predicate = try attributeIRI(attr)
            let literal = try makeLiteral(
                value: attr.value,
                language: context.language,
                direction: context.direction
            )
            try insertTriple(subject: subject, predicate: predicate, object: AnyRDFObject(literal))
        }

        var liCounter = 1
        for child in element.children {
            switch child {
            case let .element(propertyElement):
                try parsePropertyElement(propertyElement, subject: subject, inherited: context, liCounter: &liCounter)
            case let .text(text):
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    throw RDFXMLError.invalidElement("Unexpected text in node element.")
                }
            }
        }

        return subject
    }

    private mutating func parsePropertyElement(_ element: XMLElement, subject: AnyRDFSubject, inherited: ElementContext, liCounter: inout Int) throws {
        let context = try elementContext(element, inherited: inherited)
        let predicate = try predicateIRI(for: element, liCounter: &liCounter)
        let parseType = attributeValue(element, namespace: rdfNamespace, localName: "parseType")
        let resourceAttr = attributeValue(element, namespace: rdfNamespace, localName: "resource")
        let nodeIdAttr = attributeValue(element, namespace: rdfNamespace, localName: "nodeID")
        let datatypeAttr = attributeValue(element, namespace: rdfNamespace, localName: "datatype")
        let idAttr = attributeValue(element, namespace: rdfNamespace, localName: "ID")
        let annotationAttr = attributeValue(element, namespace: rdfNamespace, localName: "annotation")
        let annotationNodeIDAttr = attributeValue(element, namespace: rdfNamespace, localName: "annotationNodeID")

        let propertyAttributes = element.attributes.filter { isPropertyAttribute($0) }
        let childElements = element.children.compactMap { child -> XMLElement? in
            if case let .element(element) = child { return element }
            return nil
        }
        let textContent = element.children.compactMap { child -> String? in
            if case let .text(text) = child { return text }
            return nil
        }.joined()
        let hasSignificantText = !textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if let parseType {
            switch parseType {
            case "Literal":
                let xmlLiteral = serializeChildren(element.children)
                let object = try Literal(xmlLiteral, datatype: RDF.Vocabulary.XMLLiteral)
                let statement = try emitStatement(subject: subject, predicate: predicate, object: AnyRDFObject(object), idAttr: idAttr, annotationAttr: annotationAttr, annotationNodeIDAttr: annotationNodeIDAttr, context: context)
                _ = statement
                return
            case "Resource":
                let blank = try newBlankNode()
                _ = try emitStatement(subject: subject, predicate: predicate, object: AnyRDFObject(blank), idAttr: idAttr, annotationAttr: annotationAttr, annotationNodeIDAttr: annotationNodeIDAttr, context: context)
                var childLiCounter = 1
                for child in childElements {
                    try parsePropertyElement(child, subject: try AnyRDFSubject(blank), inherited: context, liCounter: &childLiCounter)
                }
                return
            case "Collection":
                let objects = try childElements.map { child -> AnyRDFObject in
                    let node = try parseNodeElement(child, inherited: context)
                    return try asObject(node)
                }
                let head = try buildCollection(objects, subject: subject, predicate: predicate, idAttr: idAttr, annotationAttr: annotationAttr, annotationNodeIDAttr: annotationNodeIDAttr, context: context)
                _ = head
                return
            case "Triple":
                let tripleTerm = try parseTripleTermContent(element, inherited: context)
                _ = try emitStatement(subject: subject, predicate: predicate, object: AnyRDFObject(tripleTerm), idAttr: idAttr, annotationAttr: annotationAttr, annotationNodeIDAttr: annotationNodeIDAttr, context: context)
                return
            default:
                let xmlLiteral = serializeChildren(element.children)
                let object = try Literal(xmlLiteral, datatype: RDF.Vocabulary.XMLLiteral)
                _ = try emitStatement(subject: subject, predicate: predicate, object: AnyRDFObject(object), idAttr: idAttr, annotationAttr: annotationAttr, annotationNodeIDAttr: annotationNodeIDAttr, context: context)
                return
            }
        }

        if !childElements.isEmpty {
            guard childElements.count == 1 else {
                throw RDFXMLError.invalidElement("Property element must contain a single node element.")
            }
            let node = try parseNodeElement(childElements[0], inherited: context)
            _ = try emitStatement(subject: subject, predicate: predicate, object: try asObject(node), idAttr: idAttr, annotationAttr: annotationAttr, annotationNodeIDAttr: annotationNodeIDAttr, context: context)
            return
        }

        if hasSignificantText || datatypeAttr != nil {
            let literalValue = textContent
            let object: Literal
            if let datatypeValue = datatypeAttr {
                let datatypeIRI = try resolveIriReference(datatypeValue, base: context.baseIRI)
                object = try Literal(literalValue, datatype: datatypeIRI)
            } else {
                object = try makeLiteral(value: literalValue, language: context.language, direction: context.direction)
            }
            _ = try emitStatement(subject: subject, predicate: predicate, object: AnyRDFObject(object), idAttr: idAttr, annotationAttr: annotationAttr, annotationNodeIDAttr: annotationNodeIDAttr, context: context)
            return
        }

        if resourceAttr == nil && nodeIdAttr == nil && datatypeAttr == nil && propertyAttributes.isEmpty {
            let object = try makeLiteral(value: "", language: context.language, direction: context.direction)
            _ = try emitStatement(subject: subject, predicate: predicate, object: AnyRDFObject(object), idAttr: idAttr, annotationAttr: annotationAttr, annotationNodeIDAttr: annotationNodeIDAttr, context: context)
            return
        }

        if let datatypeValue = datatypeAttr, resourceAttr == nil, nodeIdAttr == nil, propertyAttributes.isEmpty {
            let datatypeIRI = try resolveIriReference(datatypeValue, base: context.baseIRI)
            let object = try Literal("", datatype: datatypeIRI)
            _ = try emitStatement(subject: subject, predicate: predicate, object: AnyRDFObject(object), idAttr: idAttr, annotationAttr: annotationAttr, annotationNodeIDAttr: annotationNodeIDAttr, context: context)
            return
        }

        let resourceNode: AnyRDFObject
        if let resourceValue = resourceAttr {
            let iri = try resolveIriReference(resourceValue, base: context.baseIRI)
            resourceNode = AnyRDFObject(iri)
        } else if let nodeIdValue = nodeIdAttr {
            let blank = try BlankNode(nodeIdValue)
            resourceNode = AnyRDFObject(blank)
        } else {
            let blank = try newBlankNode()
            resourceNode = AnyRDFObject(blank)
        }

        if let blank = resourceNode.node as? BlankNode {
            for attr in propertyAttributes {
                let predicateIRI = try attributeIRI(attr)
                if predicateIRI == RDF.Vocabulary.type {
                    let typeIRI = try resolveIriReference(attr.value, base: context.baseIRI)
                    try insertTriple(subject: try AnyRDFSubject(blank), predicate: predicateIRI, object: AnyRDFObject(typeIRI))
                } else {
                    let literal = try makeLiteral(value: attr.value, language: context.language, direction: context.direction)
                    try insertTriple(subject: try AnyRDFSubject(blank), predicate: predicateIRI, object: AnyRDFObject(literal))
                }
            }
        } else if let iri = resourceNode.node as? IRI {
            for attr in propertyAttributes {
                let predicateIRI = try attributeIRI(attr)
                if predicateIRI == RDF.Vocabulary.type {
                    let typeIRI = try resolveIriReference(attr.value, base: context.baseIRI)
                    try insertTriple(subject: try AnyRDFSubject(iri), predicate: predicateIRI, object: AnyRDFObject(typeIRI))
                } else {
                    let literal = try makeLiteral(value: attr.value, language: context.language, direction: context.direction)
                    try insertTriple(subject: try AnyRDFSubject(iri), predicate: predicateIRI, object: AnyRDFObject(literal))
                }
            }
        }

        _ = try emitStatement(subject: subject, predicate: predicate, object: resourceNode, idAttr: idAttr, annotationAttr: annotationAttr, annotationNodeIDAttr: annotationNodeIDAttr, context: context)
    }

    private mutating func parseTripleTermContent(_ element: XMLElement, inherited: ElementContext) throws -> TripleTerm {
        var tempParser = RDFXMLParser(text: "", baseIRI: inherited.baseIRI)
        tempParser.blankNodeCounter = blankNodeCounter
        let childElements = element.children.compactMap { child -> XMLElement? in
            if case let .element(element) = child { return element }
            return nil
        }
        let hasText = element.children.contains { child in
            if case let .text(text) = child {
                return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return false
        }
        if hasText {
            throw RDFXMLError.invalidTripleTerm("parseType=\"Triple\" cannot contain text content.")
        }

        if childElements.count == 1 {
            _ = try tempParser.parseNodeElement(childElements[0], inherited: inherited)
        } else {
            let blank = try tempParser.newBlankNode()
            var liCounter = 1
            for child in childElements {
                try tempParser.parsePropertyElement(child, subject: try AnyRDFSubject(blank), inherited: inherited, liCounter: &liCounter)
            }
        }

        let triples = tempParser.graph.triples
        guard triples.count == 1, let triple = triples.first else {
            throw RDFXMLError.invalidTripleTerm("parseType=\"Triple\" must produce exactly one triple.")
        }
        blankNodeCounter = tempParser.blankNodeCounter
        return TripleTerm(subject: triple.subject, predicate: triple.predicate, object: triple.object)
    }

    private mutating func buildCollection(_ objects: [AnyRDFObject], subject: AnyRDFSubject, predicate: IRI, idAttr: String?, annotationAttr: String?, annotationNodeIDAttr: String?, context: ElementContext) throws {
        if objects.isEmpty {
            _ = try emitStatement(subject: subject, predicate: predicate, object: AnyRDFObject(RDF.Vocabulary.nilValue), idAttr: idAttr, annotationAttr: annotationAttr, annotationNodeIDAttr: annotationNodeIDAttr, context: context)
            return
        }

        var blanks: [BlankNode] = []
        for _ in objects {
            blanks.append(try newBlankNode())
        }

        _ = try emitStatement(subject: subject, predicate: predicate, object: AnyRDFObject(blanks[0]), idAttr: idAttr, annotationAttr: annotationAttr, annotationNodeIDAttr: annotationNodeIDAttr, context: context)

        for (index, item) in objects.enumerated() {
            let current = blanks[index]
            try insertTriple(
                subject: try AnyRDFSubject(current),
                predicate: RDF.Vocabulary.first,
                object: item
            )
            let restObject: AnyRDFObject
            if index == blanks.count - 1 {
                restObject = AnyRDFObject(RDF.Vocabulary.nilValue)
            } else {
                restObject = AnyRDFObject(blanks[index + 1])
            }
            try insertTriple(
                subject: try AnyRDFSubject(current),
                predicate: RDF.Vocabulary.rest,
                object: restObject
            )
        }
    }

    private mutating func emitStatement(subject: AnyRDFSubject, predicate: IRI, object: AnyRDFObject, idAttr: String?, annotationAttr: String?, annotationNodeIDAttr: String?, context: ElementContext) throws -> Graph.TripleType {
        let statement = Graph.TripleType(subject: subject, predicate: predicate, object: object)
        try insertTriple(statement)

        if let idValue = idAttr {
            let reifierIRI = try resolveIriReference("#" + idValue, base: context.baseIRI)
            try reify(statement: statement, reifier: reifierIRI)
        }
        if let annotationValue = annotationAttr {
            let reifierIRI = try resolveIriReference(annotationValue, base: context.baseIRI)
            try annotate(statement: statement, reifier: AnyRDFSubject(reifierIRI))
        } else if let annotationNodeID = annotationNodeIDAttr {
            let blank = try BlankNode(annotationNodeID)
            try annotate(statement: statement, reifier: AnyRDFSubject(blank))
        }

        return statement
    }

    private mutating func reify(statement: Graph.TripleType, reifier: IRI) throws {
        let reifierSubject = try AnyRDFSubject(reifier)
        try insertTriple(subject: reifierSubject, predicate: RDF.Vocabulary.subject, object: try asObject(statement.subject))
        try insertTriple(subject: reifierSubject, predicate: RDF.Vocabulary.predicate, object: AnyRDFObject(statement.predicate))
        try insertTriple(subject: reifierSubject, predicate: RDF.Vocabulary.object, object: statement.object)
        try insertTriple(subject: reifierSubject, predicate: RDF.Vocabulary.type, object: AnyRDFObject(RDF.Vocabulary.Statement))
    }

    private mutating func annotate(statement: Graph.TripleType, reifier: AnyRDFSubject) throws {
        let tripleTerm = TripleTerm(subject: statement.subject, predicate: statement.predicate, object: statement.object)
        try insertTriple(subject: reifier, predicate: RDF.Vocabulary.reifies, object: AnyRDFObject(tripleTerm))
    }

    private mutating func insertTriple(_ triple: Graph.TripleType) throws {
        do {
            try graph.insert(triple)
        } catch RDFGraphError.duplicateTriple {
            return
        }
    }

    private mutating func insertTriple(subject: AnyRDFSubject, predicate: IRI, object: AnyRDFObject) throws {
        try insertTriple(Graph.TripleType(subject: subject, predicate: predicate, object: object))
    }

    private mutating func newBlankNode() throws -> BlankNode {
        blankNodeCounter += 1
        return try BlankNode("genid\(blankNodeCounter)")
    }

    private func parseSubject(from element: XMLElement, context: ElementContext) throws -> AnyRDFSubject {
        let about = attributeValue(element, namespace: rdfNamespace, localName: "about")
        let nodeID = attributeValue(element, namespace: rdfNamespace, localName: "nodeID")
        let id = attributeValue(element, namespace: rdfNamespace, localName: "ID")

        let provided = [about, nodeID, id].compactMap { $0 }
        if provided.count > 1 {
            throw RDFXMLError.invalidAttribute("rdf:about, rdf:nodeID, and rdf:ID are mutually exclusive.")
        }

        if let about {
            let iri = try resolveIriReference(about, base: context.baseIRI)
            return try AnyRDFSubject(iri)
        }
        if let nodeID {
            return try AnyRDFSubject(BlankNode(nodeID))
        }
        if let id {
            let iri = try resolveIriReference("#" + id, base: context.baseIRI)
            return try AnyRDFSubject(iri)
        }
        return try AnyRDFSubject(newBlankNode())
    }

    private func predicateIRI(for element: XMLElement, liCounter: inout Int) throws -> IRI {
        if isRdfElement(element, localName: "li") {
            let iri = try RDF.Vocabulary.containerMembershipProperty(liCounter)
            liCounter += 1
            return iri
        }
        return try elementIRI(element)
    }

    private func elementIRI(_ element: XMLElement) throws -> IRI {
        guard let namespace = element.namespaceURI else {
            throw RDFXMLError.invalidElement("Missing namespace for element \(element.localName).")
        }
        return try IRI(namespace + element.localName)
    }

    private func attributeIRI(_ attribute: XMLAttribute) throws -> IRI {
        guard let namespace = attribute.namespaceURI else {
            throw RDFXMLError.invalidAttribute("Missing namespace for attribute \(attribute.localName).")
        }
        return try IRI(namespace + attribute.localName)
    }

    private func resolveIriReference(_ value: String, base: IRI?) throws -> IRI {
        if let base, let baseURL = URL(string: base.string) {
            if let resolved = URL(string: value, relativeTo: baseURL)?.absoluteString {
                return try IRI(resolved)
            }
        }
        return try IRI(value)
    }

    private func resolveBase(_ value: String?, inherited: IRI?) throws -> IRI? {
        guard let value else { return inherited }
        if let inherited, let baseURL = URL(string: inherited.string), let resolved = URL(string: value, relativeTo: baseURL)?.absoluteString {
            return try? IRI(resolved)
        }
        return try? IRI(value)
    }

    private func elementContext(_ element: XMLElement, inherited: ElementContext) throws -> ElementContext {
        let baseValue = attributeValue(element, namespace: "http://www.w3.org/XML/1998/namespace", localName: "base")
        let baseIRI = try resolveBase(baseValue, inherited: inherited.baseIRI)
        let languageValue = attributeValue(element, namespace: "http://www.w3.org/XML/1998/namespace", localName: "lang")
        let language = languageValue?.isEmpty == true ? nil : languageValue ?? inherited.language
        let directionValue = attributeValue(element, namespace: itsNamespace, localName: "dir")
        let direction = directionValue.flatMap { TextDirection(rawValue: $0.lowercased()) } ?? inherited.direction
        return ElementContext(baseIRI: baseIRI, language: language, direction: direction)
    }

    private func attributeValue(_ element: XMLElement, namespace: String?, localName: String) -> String? {
        element.attributes.first { $0.namespaceURI == namespace && $0.localName == localName }?.value
    }

    private func isRdfElement(_ element: XMLElement, localName: String) -> Bool {
        element.namespaceURI == rdfNamespace && element.localName == localName
    }

    private func isPropertyAttribute(_ attribute: XMLAttribute) -> Bool {
        if attribute.prefix == "xmlns" || attribute.localName == "xmlns" { return false }
        if attribute.namespaceURI == rdfNamespace { return false }
        if attribute.namespaceURI == "http://www.w3.org/XML/1998/namespace" { return false }
        if attribute.namespaceURI == itsNamespace { return false }
        return true
    }

    private func makeLiteral(value: String, language: String?, direction: TextDirection?) throws -> Literal {
        if let language {
            return try Literal(value, languageTag: language, textDirection: direction)
        }
        return try Literal(value)
    }

    private func asObject(_ subject: AnyRDFSubject) throws -> AnyRDFObject {
        if let iri = subject.node as? IRI {
            return AnyRDFObject(iri)
        }
        if let blank = subject.node as? BlankNode {
            return AnyRDFObject(blank)
        }
        throw RDFXMLError.invalidElement("Subject cannot be used as object.")
    }

    private func serializeChildren(_ children: [XMLChild]) -> String {
        children.map { child in
            switch child {
            case let .text(text):
                return escapeText(text)
            case let .element(element):
                return serializeElement(element)
            }
        }.joined()
    }

    private func serializeElement(_ element: XMLElement) -> String {
        let name = element.prefix.map { "\($0):\(element.localName)" } ?? element.localName
        let attributes = element.attributes.map { attr -> String in
            let attrName = attr.prefix.map { "\($0):\(attr.localName)" } ?? attr.localName
            return "\(attrName)=\"\(escapeAttribute(attr.value))\""
        }.joined(separator: " ")
        let attributeString = attributes.isEmpty ? "" : " " + attributes
        let content = serializeChildren(element.children)
        if content.isEmpty {
            return "<\(name)\(attributeString)/>"
        }
        return "<\(name)\(attributeString)>\(content)</\(name)>"
    }

    private func escapeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func escapeAttribute(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
    }
}

// MARK: - RDF/XML serializer

private struct RDFXMLSerializer {
    private let baseIRI: IRI?
    private let rdfNamespace = RDF.Vocabulary.namespace
    private let itsNamespace = "http://www.w3.org/2005/11/its"

    init(baseIRI: IRI?) {
        self.baseIRI = baseIRI
    }

    func serialize(graph: Graph) -> String {
        let subjects = Dictionary(grouping: graph.triples, by: { $0.subject })
        let namespaceMap = buildNamespaceMap(for: graph.triples)
        let needsITS = graph.triples.contains { triple in
            if let literal = triple.object.node as? Literal {
                return literal.textDirection != nil
            }
            return false
        }

        var xmlns = "xmlns:rdf=\"\(rdfNamespace)\""
        for (prefix, namespace) in namespaceMap.sorted(by: { $0.key < $1.key }) {
            xmlns += " xmlns:\(prefix)=\"\(namespace)\""
        }
        if needsITS {
            xmlns += " xmlns:its=\"\(itsNamespace)\""
        }
        if let baseIRI {
            xmlns += " xml:base=\"\(baseIRI.string)\""
        }

        var lines: [String] = []
        lines.append("<rdf:RDF \(xmlns)>")
        for (subject, triples) in subjects.sorted(by: { $0.key.description < $1.key.description }) {
            lines.append(serializeSubject(subject, triples: triples, namespaceMap: namespaceMap))
        }
        lines.append("</rdf:RDF>")
        return lines.joined(separator: "\n")
    }

    private func serializeSubject(_ subject: AnyRDFSubject, triples: [Graph.TripleType], namespaceMap: [String: String]) -> String {
        var lines: [String] = []
        let subjectAttributes: String
        if let iri = subject.node as? IRI {
            subjectAttributes = " rdf:about=\"\(iri.string)\""
        } else if let blank = subject.node as? BlankNode {
            subjectAttributes = " rdf:nodeID=\"\(blank.identifier)\""
        } else {
            subjectAttributes = ""
        }
        lines.append("  <rdf:Description\(subjectAttributes)>")
        for triple in triples.sorted(by: { $0.predicate.string < $1.predicate.string }) {
            lines.append(serializePredicateObject(triple.predicate, triple.object, namespaceMap: namespaceMap))
        }
        lines.append("  </rdf:Description>")
        return lines.joined(separator: "\n")
    }

    private func serializePredicateObject(_ predicate: IRI, _ object: AnyRDFObject, namespaceMap: [String: String]) -> String {
        if let tripleTerm = object.node as? TripleTerm {
            return serializeTripleTerm(predicate, tripleTerm, namespaceMap: namespaceMap)
        }

        let qname = qnameFor(predicate, namespaceMap: namespaceMap) ?? "rdf:Description"
        if let iri = object.node as? IRI {
            return "    <\(qname) rdf:resource=\"\(iri.string)\"/>"
        }
        if let blank = object.node as? BlankNode {
            return "    <\(qname) rdf:nodeID=\"\(blank.identifier)\"/>"
        }
        if let literal = object.node as? Literal {
            var attrs: [String] = []
            if let language = literal.languageTag {
                attrs.append("xml:lang=\"\(language)\"")
                if let direction = literal.textDirection {
                    attrs.append("its:dir=\"\(direction.rawValue)\"")
                }
            } else if let datatype = literal.datatype {
                attrs.append("rdf:datatype=\"\(datatype.string)\"")
            }
            let attrString = attrs.isEmpty ? "" : " " + attrs.joined(separator: " ")
            let value = escapeText(literal.lexicalForm)
            return "    <\(qname)\(attrString)>\(value)</\(qname)>"
        }
        return "    <\(qname)/>"
    }

    private func serializeTripleTerm(_ predicate: IRI, _ tripleTerm: TripleTerm, namespaceMap: [String: String]) -> String {
        let qname = qnameFor(predicate, namespaceMap: namespaceMap) ?? "rdf:Description"
        var lines: [String] = []
        lines.append("    <\(qname) rdf:parseType=\"Triple\">")
        lines.append("      \(serializeTripleTermSubject(tripleTerm, namespaceMap: namespaceMap))")
        lines.append("    </\(qname)>")
        return lines.joined(separator: "\n")
    }

    private func serializeTripleTermSubject(_ tripleTerm: TripleTerm, namespaceMap: [String: String]) -> String {
        let subject = tripleTerm.subject
        let subjectAttributes: String
        if let iri = subject.node as? IRI {
            subjectAttributes = " rdf:about=\"\(iri.string)\""
        } else if let blank = subject.node as? BlankNode {
            subjectAttributes = " rdf:nodeID=\"\(blank.identifier)\""
        } else {
            subjectAttributes = ""
        }
        let predicateLine = serializePredicateObject(tripleTerm.predicate, tripleTerm.object, namespaceMap: namespaceMap)
        let indentedPredicate = predicateLine.replacingOccurrences(of: "    ", with: "        ")
        return "<rdf:Description\(subjectAttributes)>\n\(indentedPredicate)\n      </rdf:Description>"
    }

    private func buildNamespaceMap(for triples: Set<Graph.TripleType>) -> [String: String] {
        var namespaces: [String: String] = [:]
        var counter = 1
        for triple in triples {
            let predicate = triple.predicate
            if let (namespace, _) = splitIRI(predicate.string) {
                if namespaces.values.contains(namespace) { continue }
                let prefix = "ns\(counter)"
                namespaces[prefix] = namespace
                counter += 1
            }
        }
        return namespaces
    }

    private func qnameFor(_ iri: IRI, namespaceMap: [String: String]) -> String? {
        guard let (namespace, local) = splitIRI(iri.string) else { return nil }
        guard let prefix = namespaceMap.first(where: { $0.value == namespace })?.key else { return nil }
        return "\(prefix):\(local)"
    }

    private func splitIRI(_ iri: String) -> (String, String)? {
        if let hashIndex = iri.lastIndex(of: "#") {
            let ns = String(iri[..<iri.index(after: hashIndex)])
            let local = String(iri[iri.index(after: hashIndex)...])
            return validateLocalName(local) ? (ns, local) : nil
        }
        if let slashIndex = iri.lastIndex(of: "/") {
            let ns = String(iri[..<iri.index(after: slashIndex)])
            let local = String(iri[iri.index(after: slashIndex)...])
            return validateLocalName(local) ? (ns, local) : nil
        }
        return nil
    }

    private func validateLocalName(_ value: String) -> Bool {
        guard let first = value.unicodeScalars.first else { return false }
        if !(CharacterSet.letters.union(CharacterSet(charactersIn: "_")).contains(first)) {
            return false
        }
        let allowed = CharacterSet.letters.union(CharacterSet.decimalDigits).union(CharacterSet(charactersIn: "._-"))
        return value.unicodeScalars.dropFirst().allSatisfy { allowed.contains($0) }
    }

    private func escapeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
