import SwiftUI
import SemanticKit

struct GraphSidebarView: View {
    let graph: Graph

    @State private var selection: NodeSelection?

    private var inspector: GraphInspector {
        GraphInspector(graph: graph)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Subjects") {
                    ForEach(inspector.subjects) { entry in
                        nodeRow(entry)
                    }
                }

                Section("Predicates") {
                    ForEach(inspector.predicates) { entry in
                        nodeRow(entry)
                    }
                }

                Section("Objects") {
                    ForEach(inspector.objects) { entry in
                        nodeRow(entry)
                    }
                }
            }
            .navigationTitle("Graph")
        } detail: {
            if let selection {
                NodeDetailView(details: inspector.details(for: selection))
            } else {
                PlaceholderDetailView()
            }
        }
    }

    @ViewBuilder
    private func nodeRow(_ entry: NodeEntry) -> some View {
        Label(entry.label, systemImage: entry.kind.symbolName)
            .tag(entry.selection)
    }
}

private struct PlaceholderDetailView: View {
    var body: some View {
        ContentUnavailableView(
            "Select a node",
            systemImage: "point.3.connected.trianglepath.dotted",
            description: Text("Pick a subject, predicate, or object to see details.")
        )
    }
}

private struct NodeDetailView: View {
    let details: NodeDetails

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                detailsSection
                triplesSection
            }
            .padding(16)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(details.label)
                .font(.title2)
                .fontWeight(.semibold)

            Text(details.kind.title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var detailsSection: some View {
        GroupBox("Details") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(details.properties) { row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 110, alignment: .leading)

                        Text(row.value)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var triplesSection: some View {
        GroupBox("Related Triples (\(details.relatedTriples.count))") {
            VStack(alignment: .leading, spacing: 10) {
                if details.relatedTriples.isEmpty {
                    Text("No related triples found.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(details.relatedTriples) { triple in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(triple.role)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(triple.text)
                                .font(.body)
                                .textSelection(.enabled)
                        }

                        if triple.id != details.relatedTriples.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private enum NodeKind: String {
    case subject
    case predicate
    case object

    var title: String {
        rawValue.capitalized
    }

    var symbolName: String {
        switch self {
        case .subject:
            return "person.crop.circle"
        case .predicate:
            return "link"
        case .object:
            return "cube"
        }
    }
}

private enum NodeRef: Hashable {
    case iri(IRI)
    case blank(BlankNode)
    case literal(Literal)

    var label: String {
        switch self {
        case .iri(let iri):
            return iri.description
        case .blank(let blank):
            return blank.description
        case .literal(let literal):
            return literal.description
        }
    }
}

private struct NodeSelection: Hashable {
    let kind: NodeKind
    let ref: NodeRef
}

private struct NodeEntry: Identifiable, Hashable {
    let selection: NodeSelection
    let label: String
    let kind: NodeKind

    var id: NodeSelection { selection }
}

private struct NodeDetails {
    let kind: NodeKind
    let label: String
    let properties: [DetailRow]
    let relatedTriples: [TripleSummary]
}

private struct DetailRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

private struct TripleSummary: Identifiable {
    let id = UUID()
    let role: String
    let text: String
}

private struct GraphInspector {
    let graph: Graph

    var subjects: [NodeEntry] {
        entries(for: .subject)
    }

    var predicates: [NodeEntry] {
        entries(for: .predicate)
    }

    var objects: [NodeEntry] {
        entries(for: .object)
    }

    func details(for selection: NodeSelection) -> NodeDetails {
        let properties = properties(for: selection.ref)
        let triples = relatedTriples(for: selection)

        return NodeDetails(
            kind: selection.kind,
            label: selection.ref.label,
            properties: properties,
            relatedTriples: triples
        )
    }

    private func entries(for kind: NodeKind) -> [NodeEntry] {
        let refs: [NodeRef]

        switch kind {
        case .subject:
            refs = graph.triples.map { nodeRef(for: $0.subject) }
        case .predicate:
            refs = graph.triples.map { nodeRef(for: $0.predicate) }
        case .object:
            refs = graph.triples.map { nodeRef(for: $0.object) }
        }

        let uniqueRefs = Array(Set(refs))

        return uniqueRefs
            .map { ref in
                let selection = NodeSelection(kind: kind, ref: ref)
                return NodeEntry(selection: selection, label: ref.label, kind: kind)
            }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    private func relatedTriples(for selection: NodeSelection) -> [TripleSummary] {
        let triples = graph.triples.filter { triple in
            switch selection.kind {
            case .subject:
                return nodeRef(for: triple.subject) == selection.ref
            case .predicate:
                return nodeRef(for: triple.predicate) == selection.ref
            case .object:
                return nodeRef(for: triple.object) == selection.ref
            }
        }

        return triples
            .map { triple in
                TripleSummary(
                    role: selection.kind.title,
                    text: triple.description
                )
            }
            .sorted { $0.text.localizedStandardCompare($1.text) == .orderedAscending }
    }

    private func properties(for ref: NodeRef) -> [DetailRow] {
        switch ref {
        case .iri(let iri):
            return [
                DetailRow(label: "Scheme", value: iri.scheme),
                DetailRow(label: "Authority", value: iri.authority ?? "(none)"),
                DetailRow(label: "Path", value: iri.path.isEmpty ? "/" : iri.path),
                DetailRow(label: "Query", value: iri.query ?? "(none)"),
                DetailRow(label: "Fragment", value: iri.fragment ?? "(none)")
            ]
        case .blank(let blank):
            return [
                DetailRow(label: "Identifier", value: blank.identifier)
            ]
        case .literal(let literal):
            let datatype = literal.datatype?.string ?? "(none, defaults to xsd:string)"
            return [
                DetailRow(label: "Lexical Form", value: literal.lexicalForm),
                DetailRow(label: "Language Tag", value: literal.languageTag ?? "(none)"),
                DetailRow(label: "Datatype", value: datatype)
            ]
        }
    }

    private func nodeRef(for subject: AnyRDFSubject) -> NodeRef {
        let node = subject.node

        if let iri = node as? IRI {
            return .iri(iri)
        }

        if let blank = node as? BlankNode {
            return .blank(blank)
        }

        return .blank(BlankNode("unknown"))
    }

    private func nodeRef(for predicate: IRI) -> NodeRef {
        .iri(predicate)
    }

    private func nodeRef(for object: AnyRDFObject) -> NodeRef {
        let node = object.node

        if let iri = node as? IRI {
            return .iri(iri)
        }

        if let blank = node as? BlankNode {
            return .blank(blank)
        }

        if let literal = node as? Literal {
            return .literal(literal)
        }

        return .literal(Literal("unknown"))
    }
}
