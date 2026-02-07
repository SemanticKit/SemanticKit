import Foundation

// MARK: - RDF + RDFS Vocabulary

public struct RDF {}

public extension RDF {
    enum Vocabulary {
        public static let namespace = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"

        public static let type = makeIRI("\(namespace)type")
        public static let Property = makeIRI("\(namespace)Property")
        public static let Statement = makeIRI("\(namespace)Statement")
        public static let reifies = makeIRI("\(namespace)reifies")
        public static let subject = makeIRI("\(namespace)subject")
        public static let predicate = makeIRI("\(namespace)predicate")
        public static let object = makeIRI("\(namespace)object")
        public static let Bag = makeIRI("\(namespace)Bag")
        public static let Seq = makeIRI("\(namespace)Seq")
        public static let Alt = makeIRI("\(namespace)Alt")
        public static let List = makeIRI("\(namespace)List")
        public static let first = makeIRI("\(namespace)first")
        public static let rest = makeIRI("\(namespace)rest")
        public static let nilValue = makeIRI("\(namespace)nil")
        public static let value = makeIRI("\(namespace)value")
        public static let XMLLiteral = makeIRI("\(namespace)XMLLiteral")
        public static let HTML = makeIRI("\(namespace)HTML")
        public static let JSON = makeIRI("\(namespace)JSON")
        public static let langString = makeIRI("\(namespace)langString")
        public static let dirLangString = makeIRI("\(namespace)dirLangString")

        public static func containerMembershipProperty(_ index: Int) throws -> IRI {
            guard index > 0 else {
                throw RDFTermError.invalidContainerMembershipIndex
            }
            return makeIRI("\(namespace)_\(index)")
        }

        private static func makeIRI(_ string: String) -> IRI {
            try! IRI(string)
        }
    }

    enum RDFS {
        public static let namespace = "http://www.w3.org/2000/01/rdf-schema#"

        public static let Resource = makeIRI("\(namespace)Resource")
        public static let Class = makeIRI("\(namespace)Class")
        public static let Literal = makeIRI("\(namespace)Literal")
        public static let Proposition = makeIRI("\(namespace)Proposition")
        public static let Container = makeIRI("\(namespace)Container")
        public static let ContainerMembershipProperty = makeIRI("\(namespace)ContainerMembershipProperty")
        public static let Datatype = makeIRI("\(namespace)Datatype")

        public static let label = makeIRI("\(namespace)label")
        public static let comment = makeIRI("\(namespace)comment")
        public static let seeAlso = makeIRI("\(namespace)seeAlso")
        public static let isDefinedBy = makeIRI("\(namespace)isDefinedBy")
        public static let member = makeIRI("\(namespace)member")
        public static let subClassOf = makeIRI("\(namespace)subClassOf")
        public static let subPropertyOf = makeIRI("\(namespace)subPropertyOf")
        public static let domain = makeIRI("\(namespace)domain")
        public static let range = makeIRI("\(namespace)range")

        public static var axiomsGraph: Graph {
            var graph = Graph()
            let rdf = RDF.Vocabulary.self
            let rdfs = RDF.RDFS.self

            let classAxioms: [(IRI, IRI, IRI)] = [
                (rdfs.Resource, rdf.type, rdfs.Class),
                (rdfs.Class, rdf.type, rdfs.Class),
                (rdfs.Literal, rdf.type, rdfs.Class),
                (rdfs.Datatype, rdf.type, rdfs.Class),
                (rdfs.Proposition, rdf.type, rdfs.Class),
                (rdf.Property, rdf.type, rdfs.Class),
                (rdf.Statement, rdf.type, rdfs.Class),
                (rdfs.Container, rdf.type, rdfs.Class),
                (rdfs.ContainerMembershipProperty, rdf.type, rdfs.Class),
                (rdf.List, rdf.type, rdfs.Class),
                (rdf.nilValue, rdf.type, rdf.List),
                (rdf.Alt, rdf.type, rdfs.Class),
                (rdf.Bag, rdf.type, rdfs.Class),
                (rdf.Seq, rdf.type, rdfs.Class),
                (rdf.XMLLiteral, rdf.type, rdfs.Class),
                (rdf.HTML, rdf.type, rdfs.Class),
                (rdf.JSON, rdf.type, rdfs.Class)
            ]

            let propertyAxioms: [(IRI, IRI, IRI)] = [
                (rdf.type, rdf.type, rdf.Property),
                (rdf.subject, rdf.type, rdf.Property),
                (rdf.predicate, rdf.type, rdf.Property),
                (rdf.object, rdf.type, rdf.Property),
                (rdf.reifies, rdf.type, rdf.Property),
                (rdf.first, rdf.type, rdf.Property),
                (rdf.rest, rdf.type, rdf.Property),
                (rdf.value, rdf.type, rdf.Property),
                (rdfs.subClassOf, rdf.type, rdf.Property),
                (rdfs.subPropertyOf, rdf.type, rdf.Property),
                (rdfs.domain, rdf.type, rdf.Property),
                (rdfs.range, rdf.type, rdf.Property),
                (rdfs.label, rdf.type, rdf.Property),
                (rdfs.comment, rdf.type, rdf.Property),
                (rdfs.seeAlso, rdf.type, rdf.Property),
                (rdfs.isDefinedBy, rdf.type, rdf.Property),
                (rdfs.member, rdf.type, rdf.Property)
            ]

            let schemaAxioms: [(IRI, IRI, IRI)] = [
                (rdf.type, rdfs.domain, rdfs.Resource),
                (rdf.reifies, rdfs.domain, rdfs.Resource),
                (rdf.type, rdfs.range, rdfs.Class),
                (rdf.reifies, rdfs.range, rdfs.Proposition),
                (rdfs.subClassOf, rdfs.domain, rdfs.Class),
                (rdfs.subClassOf, rdfs.range, rdfs.Class),
                (rdfs.subPropertyOf, rdfs.domain, rdf.Property),
                (rdfs.subPropertyOf, rdfs.range, rdf.Property),
                (rdfs.domain, rdfs.domain, rdf.Property),
                (rdfs.domain, rdfs.range, rdfs.Class),
                (rdfs.range, rdfs.domain, rdf.Property),
                (rdfs.range, rdfs.range, rdfs.Class),
                (rdf.subject, rdfs.domain, rdf.Statement),
                (rdf.predicate, rdfs.domain, rdf.Statement),
                (rdf.object, rdfs.domain, rdf.Statement),
                (rdfs.member, rdfs.domain, rdfs.Resource),
                (rdf.first, rdfs.domain, rdf.List),
                (rdf.rest, rdfs.domain, rdf.List),
                (rdfs.label, rdfs.domain, rdfs.Resource),
                (rdfs.label, rdfs.range, rdfs.Literal),
                (rdfs.comment, rdfs.domain, rdfs.Resource),
                (rdfs.comment, rdfs.range, rdfs.Literal),
                (rdfs.seeAlso, rdfs.domain, rdfs.Resource),
                (rdfs.seeAlso, rdfs.range, rdfs.Resource),
                (rdfs.isDefinedBy, rdfs.domain, rdfs.Resource),
                (rdfs.isDefinedBy, rdfs.range, rdfs.Resource),
                (rdf.value, rdfs.domain, rdfs.Resource),
                (rdfs.ContainerMembershipProperty, rdfs.subClassOf, rdf.Property),
                (rdfs.Datatype, rdfs.subClassOf, rdfs.Class),
                (rdf.Alt, rdfs.subClassOf, rdfs.Container),
                (rdf.Bag, rdfs.subClassOf, rdfs.Container),
                (rdf.Seq, rdfs.subClassOf, rdfs.Container),
                (rdfs.isDefinedBy, rdfs.subPropertyOf, rdfs.seeAlso),
                (rdf.subject, rdfs.range, rdfs.Resource),
                (rdf.predicate, rdfs.range, rdfs.Resource),
                (rdf.object, rdfs.range, rdfs.Resource),
                (rdfs.member, rdfs.range, rdfs.Resource),
                (rdf.first, rdfs.range, rdfs.Resource),
                (rdf.rest, rdfs.range, rdf.List),
                (rdf.value, rdfs.range, rdfs.Resource)
            ]

            for (s, p, o) in classAxioms + propertyAxioms + schemaAxioms {
                guard let subject = try? AnyRDFSubject(s) else {
                    continue
                }
                let triple = Graph.TripleType(
                    subject: subject,
                    predicate: p,
                    object: AnyRDFObject(o)
                )
                try? graph.insert(triple)
            }

            return graph
        }

        private static func makeIRI(_ string: String) -> IRI {
            try! IRI(string)
        }
    }
}

// MARK: - RDFS Entailment

public extension Graph {
    func rdfsClosure(includeAxioms: Bool = true) -> Graph {
        var reasoner = RDFSReasoner(graph: self, includeAxioms: includeAxioms)
        let closure = reasoner.computeClosure()
        return closure.merged(with: self)
    }

    func rdfsInferredTriples(includeAxioms: Bool = true) -> Set<Graph.TripleType> {
        let closure = rdfsClosure(includeAxioms: includeAxioms)
        return closure.triples.subtracting(triples)
    }
}

public extension Dataset {
    func rdfsClosure(includeAxioms: Bool = true) -> Dataset {
        let newDefault = defaultGraph.rdfsClosure(includeAxioms: includeAxioms)
        var newNamed: [IRI: Graph] = [:]

        for (name, graph) in namedGraphs {
            newNamed[name] = graph.rdfsClosure(includeAxioms: includeAxioms)
        }

        return Dataset(defaultGraph: newDefault, namedGraphs: newNamed)
    }
}

// MARK: - Internal Reasoner

private struct RDFSReasoner {
    private var graph: Graph
    private let includeAxioms: Bool

    init(graph: Graph, includeAxioms: Bool) {
        self.includeAxioms = includeAxioms
        if includeAxioms {
            self.graph = graph.merged(with: RDF.RDFS.axiomsGraph)
        } else {
            self.graph = graph
        }
    }

    mutating func computeClosure() -> Graph {
        var didChange = true

        while didChange {
            didChange = false
            if includeAxioms {
                didChange = addContainerMembershipAxioms() || didChange
            }
            let triples = Array(graph.triples)

            let rdf = RDF.Vocabulary.self
            let rdfs = RDF.RDFS.self

            var subPropertyOf: [IRI: Set<IRI>] = [:]
            var subClassOf: [AnyRDFSubject: Set<AnyRDFSubject>] = [:]
            var domain: [IRI: Set<AnyRDFSubject>] = [:]
            var range: [IRI: Set<AnyRDFSubject>] = [:]
            var typesByResource: [AnyRDFSubject: Set<AnyRDFSubject>] = [:]
            var propertyTypes: Set<IRI> = []
            var classTypes: Set<AnyRDFSubject> = []
            var containerMembershipProperties: Set<IRI> = []
            var datatypeClasses: Set<AnyRDFSubject> = []

            for triple in triples {
                let subject = triple.subject
                let predicate = triple.predicate
                let object = triple.object

                if predicate == rdf.type {
                    if let objectResource = object.resourceSubject {
                        let objectIRI = objectResource.node as? IRI
                        if objectIRI == rdf.Property, let subjectIRI = subject.node as? IRI {
                            propertyTypes.insert(subjectIRI)
                        }
                        if objectIRI == rdfs.Class {
                            classTypes.insert(subject)
                        }
                        if objectIRI == rdfs.ContainerMembershipProperty, let subjectIRI = subject.node as? IRI {
                            containerMembershipProperties.insert(subjectIRI)
                        }
                        if objectIRI == rdfs.Datatype {
                            datatypeClasses.insert(subject)
                        }

                        typesByResource[subject, default: []].insert(objectResource)
                    }
                }

                if predicate == rdfs.subPropertyOf,
                   let subjectIRI = subject.node as? IRI,
                   let objectIRI = object.node as? IRI {
                    subPropertyOf[subjectIRI, default: []].insert(objectIRI)
                }

                if predicate == rdfs.subClassOf,
                   let objectResource = object.resourceSubject {
                    subClassOf[subject, default: []].insert(objectResource)
                }

                if predicate == rdfs.domain,
                   let subjectIRI = subject.node as? IRI,
                   let objectResource = object.resourceSubject {
                    domain[subjectIRI, default: []].insert(objectResource)
                }

                if predicate == rdfs.range,
                   let subjectIRI = subject.node as? IRI,
                   let objectResource = object.resourceSubject {
                    range[subjectIRI, default: []].insert(objectResource)
                }
            }

            let subPropertyClosure = transitiveClosure(of: subPropertyOf)
            let subClassClosure = transitiveClosure(of: subClassOf)

            for (property, supers) in subPropertyClosure {
                guard let propertySubject = try? AnyRDFSubject(property) else {
                    continue
                }
                for superProperty in supers {
                    didChange = graph.addIfNeeded(
                        Graph.TripleType(
                            subject: propertySubject,
                            predicate: rdfs.subPropertyOf,
                            object: AnyRDFObject(superProperty)
                        )
                    ) || didChange
                }
            }

            for (clazz, supers) in subClassClosure {
                for superClass in supers {
                    didChange = graph.addIfNeeded(
                        Graph.TripleType(
                            subject: clazz,
                            predicate: rdfs.subClassOf,
                            object: AnyRDFObject(superClass.objectNode)
                        )
                    ) || didChange
                }
            }

            for triple in triples {
                let subject = triple.subject
                let predicate = triple.predicate
                let object = triple.object

                if let predicateSubject = try? AnyRDFSubject(predicate) {
                    didChange = graph.addIfNeeded(
                        Graph.TripleType(
                            subject: predicateSubject,
                            predicate: rdf.type,
                            object: AnyRDFObject(rdf.Property)
                        )
                    ) || didChange

                    didChange = graph.addIfNeeded(
                        Graph.TripleType(
                            subject: predicateSubject,
                            predicate: rdf.type,
                            object: AnyRDFObject(rdfs.Resource)
                        )
                    ) || didChange
                }

                didChange = graph.addIfNeeded(
                    Graph.TripleType(
                        subject: subject,
                        predicate: rdf.type,
                        object: AnyRDFObject(rdfs.Resource)
                    )
                ) || didChange

                if let objectResource = object.resourceSubject {
                    didChange = graph.addIfNeeded(
                        Graph.TripleType(
                            subject: objectResource,
                            predicate: rdf.type,
                            object: AnyRDFObject(rdfs.Resource)
                        )
                    ) || didChange
                }

                if let domains = domain[predicate] {
                    for domainClass in domains {
                        didChange = graph.addIfNeeded(
                            Graph.TripleType(
                                subject: subject,
                                predicate: rdf.type,
                                object: AnyRDFObject(domainClass.objectNode)
                            )
                        ) || didChange
                    }
                }

                if let ranges = range[predicate], let objectResource = object.resourceSubject {
                    for rangeClass in ranges {
                        didChange = graph.addIfNeeded(
                            Graph.TripleType(
                                subject: objectResource,
                                predicate: rdf.type,
                                object: AnyRDFObject(rangeClass.objectNode)
                            )
                        ) || didChange
                    }
                }

                if let superProperties = subPropertyClosure[predicate] {
                    for superProperty in superProperties {
                        didChange = graph.addIfNeeded(
                            Graph.TripleType(
                                subject: subject,
                                predicate: superProperty,
                                object: object
                            )
                        ) || didChange
                    }
                }
            }

            for (resource, types) in typesByResource {
                for clazz in types {
                    if let superClasses = subClassClosure[clazz] {
                        for superClass in superClasses {
                            didChange = graph.addIfNeeded(
                                Graph.TripleType(
                                    subject: resource,
                                    predicate: rdf.type,
                                    object: AnyRDFObject(superClass.objectNode)
                                )
                            ) || didChange
                        }
                    }
                }
            }

            for property in propertyTypes {
                if let subject = validatedSubject(property) {
                    didChange = graph.addIfNeeded(
                        Graph.TripleType(
                            subject: subject,
                            predicate: rdfs.subPropertyOf,
                            object: AnyRDFObject(property)
                        )
                    ) || didChange
                }
            }

            for clazz in classTypes {
                didChange = graph.addIfNeeded(
                    Graph.TripleType(
                        subject: clazz,
                        predicate: rdfs.subClassOf,
                        object: AnyRDFObject(rdfs.Resource)
                    )
                ) || didChange
            }

            for clazz in classTypes {
                didChange = graph.addIfNeeded(
                    Graph.TripleType(
                        subject: clazz,
                        predicate: rdfs.subClassOf,
                        object: AnyRDFObject(clazz.objectNode)
                    )
                ) || didChange
            }

            for property in containerMembershipProperties {
                if let subject = validatedSubject(property) {
                    didChange = graph.addIfNeeded(
                        Graph.TripleType(
                            subject: subject,
                            predicate: rdfs.subPropertyOf,
                            object: AnyRDFObject(rdfs.member)
                        )
                    ) || didChange
                }
            }

            for datatype in datatypeClasses {
                didChange = graph.addIfNeeded(
                    Graph.TripleType(
                        subject: datatype,
                        predicate: rdfs.subClassOf,
                        object: AnyRDFObject(rdfs.Literal)
                    )
                ) || didChange
            }

            for (property, supers) in subPropertyClosure {
                guard let propertySubject = validatedSubject(property) else {
                    continue
                }
                if !supers.isEmpty {
                    didChange = graph.addIfNeeded(
                        Graph.TripleType(
                            subject: propertySubject,
                            predicate: rdf.type,
                            object: AnyRDFObject(rdf.Property)
                        )
                    ) || didChange

                    for superProperty in supers {
                        if let superSubject = validatedSubject(superProperty) {
                            didChange = graph.addIfNeeded(
                                Graph.TripleType(
                                    subject: superSubject,
                                    predicate: rdf.type,
                                    object: AnyRDFObject(rdf.Property)
                                )
                            ) || didChange
                        }
                    }
                }
            }

            for (clazz, supers) in subClassClosure {
                if !supers.isEmpty {
                    didChange = graph.addIfNeeded(
                        Graph.TripleType(
                            subject: clazz,
                            predicate: rdf.type,
                            object: AnyRDFObject(rdfs.Class)
                        )
                    ) || didChange

                    for superClass in supers {
                        didChange = graph.addIfNeeded(
                            Graph.TripleType(
                                subject: superClass,
                                predicate: rdf.type,
                                object: AnyRDFObject(rdfs.Class)
                            )
                        ) || didChange
                    }
                }
            }
        }

        return graph
    }

    private mutating func addContainerMembershipAxioms() -> Bool {
        let rdf = RDF.Vocabulary.self
        let rdfs = RDF.RDFS.self
        var membershipIRIs: Set<IRI> = []
        var changed = false

        for triple in graph.triples {
            if let subjectIRI = triple.subject.node as? IRI,
               isContainerMembershipProperty(subjectIRI) {
                membershipIRIs.insert(subjectIRI)
            }
            if isContainerMembershipProperty(triple.predicate) {
                membershipIRIs.insert(triple.predicate)
            }
            if let objectIRI = triple.object.node as? IRI,
               isContainerMembershipProperty(objectIRI) {
                membershipIRIs.insert(objectIRI)
            }
        }

        for property in membershipIRIs {
            guard let subject = validatedSubject(property) else {
                continue
            }
            changed = graph.addIfNeeded(
                Graph.TripleType(
                    subject: subject,
                    predicate: rdf.type,
                    object: AnyRDFObject(rdfs.ContainerMembershipProperty)
                )
            ) || changed
            changed = graph.addIfNeeded(
                Graph.TripleType(
                    subject: subject,
                    predicate: rdfs.domain,
                    object: AnyRDFObject(rdfs.Resource)
                )
            ) || changed
            changed = graph.addIfNeeded(
                Graph.TripleType(
                    subject: subject,
                    predicate: rdfs.range,
                    object: AnyRDFObject(rdfs.Resource)
                )
            ) || changed
        }

        return changed
    }
}

private extension Graph {
    func merged(with other: Graph) -> Graph {
        var merged = self
        for triple in other.triples {
            _ = merged.addIfNeeded(triple)
        }
        return merged
    }

    @discardableResult
    mutating func addIfNeeded(_ triple: Graph.TripleType) -> Bool {
        guard !contains(triple) else { return false }
        try? insert(triple)
        return true
    }
}

private extension AnyRDFObject {
    var resourceSubject: AnyRDFSubject? {
        if let resource = node as? any RDFSubject {
            return validatedSubject(resource)
        }
        return nil
    }
}

private extension AnyRDFSubject {
    var objectNode: any RDFObject {
        node as! any RDFObject
    }
}

private func validatedSubject(_ node: any RDFSubject) -> AnyRDFSubject? {
    try? AnyRDFSubject(node)
}

private func transitiveClosure<T: Hashable>(of map: [T: Set<T>]) -> [T: Set<T>] {
    var result: [T: Set<T>] = [:]

    for (node, _) in map {
        var visited: Set<T> = []
        var stack = Array(map[node] ?? [])

        while let current = stack.popLast() {
            if visited.insert(current).inserted {
                if let next = map[current] {
                    stack.append(contentsOf: next)
                }
            }
        }

        if !visited.isEmpty {
            result[node] = visited
        }
    }

    return result
}

private func isContainerMembershipProperty(_ iri: IRI) -> Bool {
    let prefix = RDF.Vocabulary.namespace + "_"
    guard iri.string.hasPrefix(prefix) else { return false }
    let suffix = iri.string.dropFirst(prefix.count)
    guard !suffix.isEmpty else { return false }
    return suffix.allSatisfy { $0.isNumber }
}

