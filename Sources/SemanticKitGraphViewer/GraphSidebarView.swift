import SwiftUI
import SemanticKit

struct GraphSidebarView: View {
    let dataset: Dataset
    @Binding var selectedGraphName: IRI?

    @State private var nodeSelection: NodeSelection?
    @State private var searchText = ""
    @State private var nodeScope: NodeScope = .all

    private var activeGraph: Graph {
        dataset.graph(selectedGraphName) ?? dataset.defaultGraph
    }

    private var inspector: GraphInspector {
        GraphInspector(graph: activeGraph)
    }

    var body: some View {
        NavigationSplitView {
            graphList
                .navigationTitle("Graphs")
        } content: {
            nodeList
                .navigationTitle(activeGraphTitle)
                .onChange(of: selectedGraphName) {
                    nodeSelection = nil
                }
        } detail: {
            if let nodeSelection {
                NodeDetailView(details: inspector.details(for: nodeSelection))
            } else {
                GraphOverviewView(
                    dataset: dataset,
                    graph: activeGraph,
                    graphName: selectedGraphName
                )
            }
        }
    }

    private var activeGraphTitle: String {
        selectedGraphName?.string ?? "Default Graph"
    }

    private var graphSelection: Binding<GraphSelection?> {
        Binding(
            get: {
                if let selectedGraphName {
                    return .named(selectedGraphName)
                }
                return .defaultGraph
            },
            set: { newValue in
                switch newValue {
                case .named(let name):
                    selectedGraphName = name
                default:
                    selectedGraphName = nil
                }
                nodeSelection = nil
            }
        )
    }

    private var graphList: some View {
        let datasetStats = DatasetStats(dataset: dataset)

        return List(selection: graphSelection) {
            Section("Graphs") {
                graphRow(
                    title: "Default Graph",
                    subtitle: "Graph",
                    count: dataset.defaultGraph.triples.count,
                    symbolName: "square.grid.3x3",
                    selection: .defaultGraph
                )

                ForEach(dataset.namedGraphs.keys.sorted(by: { $0.string < $1.string }), id: \.self) { name in
                    let tripleCount = dataset.namedGraphs[name]?.triples.count ?? 0
                    graphRow(
                        title: name.string,
                        subtitle: "Named Graph",
                        count: tripleCount,
                        symbolName: "cube.transparent",
                        selection: .named(name)
                    )
                }
            }

            Section("Dataset") {
                LabeledContent("Graphs", value: "\(datasetStats.graphCount)")
                LabeledContent("Named Graphs", value: "\(datasetStats.namedGraphCount)")
                LabeledContent("Triples", value: "\(datasetStats.tripleCount)")
            }
        }
    }

    private func graphRow(
        title: String,
        subtitle: String,
        count: Int,
        symbolName: String,
        selection: GraphSelection
    ) -> some View {
        HStack(spacing: 8) {
            Label(title, systemImage: symbolName)
                .lineLimit(1)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
        }
        .tag(selection)
        .help(subtitle)
    }

    private var nodeList: some View {
        List(selection: $nodeSelection) {
            ForEach(nodeScope.kinds, id: \.self) { kind in
                let entries = filteredEntries(for: kind)

                Section("\(kind.title) (\(entries.count))") {
                    ForEach(entries) { entry in
                        nodeRow(entry)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Filter nodes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Scope", selection: $nodeScope) {
                    ForEach(NodeScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func filteredEntries(for kind: NodeKind) -> [NodeEntry] {
        let entries: [NodeEntry]
        switch kind {
        case .subject:
            entries = inspector.subjects
        case .predicate:
            entries = inspector.predicates
        case .object:
            entries = inspector.objects
        }

        guard !searchText.isEmpty else { return entries }
        return entries.filter { entry in
            entry.label.localizedCaseInsensitiveContains(searchText)
        }
    }

    @ViewBuilder
    private func nodeRow(_ entry: NodeEntry) -> some View {
        Label(entry.label, systemImage: entry.kind.symbolName)
            .tag(entry.selection)
    }
}

private enum GraphSelection: Hashable {
    case defaultGraph
    case named(IRI)
}

private enum NodeScope: String, CaseIterable, Identifiable {
    case all
    case subject
    case predicate
    case object

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .subject:
            return "Subjects"
        case .predicate:
            return "Predicates"
        case .object:
            return "Objects"
        }
    }

    var kinds: [NodeKind] {
        switch self {
        case .all:
            return NodeKind.allCases
        case .subject:
            return [.subject]
        case .predicate:
            return [.predicate]
        case .object:
            return [.object]
        }
    }
}

private struct DatasetStats {
    let graphCount: Int
    let namedGraphCount: Int
    let tripleCount: Int

    init(dataset: Dataset) {
        graphCount = 1 + dataset.namedGraphs.count
        namedGraphCount = dataset.namedGraphs.count
        tripleCount = dataset.defaultGraph.triples.count + dataset.namedGraphs.values.reduce(0) { $0 + $1.triples.count }
    }
}

private struct GraphStats {
    let tripleCount: Int
    let subjectCount: Int
    let predicateCount: Int
    let objectCount: Int

    init(graph: Graph) {
        let inspector = GraphInspector(graph: graph)
        tripleCount = graph.triples.count
        subjectCount = inspector.subjects.count
        predicateCount = inspector.predicates.count
        objectCount = inspector.objects.count
    }
}

private struct GraphOverviewView: View {
    let dataset: Dataset
    let graph: Graph
    let graphName: IRI?

    var body: some View {
        let stats = GraphStats(graph: graph)
        let datasetStats = DatasetStats(dataset: dataset)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                summarySection(stats: stats)
                datasetSection(stats: datasetStats)
                if !dataset.namedGraphs.isEmpty {
                    graphsSection
                }
            }
            .padding(16)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(graphName?.string ?? "Default Graph")
                .font(.title2)
                .fontWeight(.semibold)

            Text(graphName == nil ? "Default graph" : "Named graph")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func summarySection(stats: GraphStats) -> some View {
        GroupBox("Graph Summary") {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Triples", value: "\(stats.tripleCount)")
                LabeledContent("Subjects", value: "\(stats.subjectCount)")
                LabeledContent("Predicates", value: "\(stats.predicateCount)")
                LabeledContent("Objects", value: "\(stats.objectCount)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func datasetSection(stats: DatasetStats) -> some View {
        GroupBox("Dataset Summary") {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Graphs", value: "\(stats.graphCount)")
                LabeledContent("Named Graphs", value: "\(stats.namedGraphCount)")
                LabeledContent("Triples", value: "\(stats.tripleCount)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var graphsSection: some View {
        GroupBox("Named Graphs") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(dataset.namedGraphs.keys.sorted(by: { $0.string < $1.string }), id: \.self) { name in
                    let count = dataset.namedGraphs[name]?.triples.count ?? 0
                    HStack {
                        Text(name.string)
                            .lineLimit(1)
                        Spacer()
                        Text("\(count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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

private enum NodeKind: String, CaseIterable {
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
    case tripleTerm(TripleTerm)

    var label: String {
        switch self {
        case .iri(let iri):
            return iri.description
        case .blank(let blank):
            return blank.description
        case .literal(let literal):
            return literal.description
        case .tripleTerm(let term):
            return term.description
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
        case .tripleTerm(let term):
            return [
                DetailRow(label: "Subject", value: nodeRef(for: term.subject).label),
                DetailRow(label: "Predicate", value: nodeRef(for: term.predicate).label),
                DetailRow(label: "Object", value: nodeRef(for: term.object).label)
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

        return .blank(try! BlankNode("unknown"))
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

        if let term = node as? TripleTerm {
            return .tripleTerm(term)
        }

        return .literal(try! Literal("unknown"))
    }
}
