import Foundation
import SwiftUI
import UniformTypeIdentifiers
import SemanticKit

@main
struct SemanticKitGraphViewerApp: App {
    @StateObject private var graphStore = GraphStore()
    @State private var isImporting = false
    @State private var isURLImporting = false
    @State private var isFetchingRemote = false
    @State private var importURLText = ""
    @State private var isExporting = false
    @State private var exportFormat: RDFFormat = .turtle
    @State private var exportDocument = RDFExportDocument(data: Data())
    @State private var errorMessage: String?

    var body: some Scene {
        WindowGroup {
            GraphSidebarView(dataset: graphStore.dataset, selectedGraphName: $graphStore.selectedGraphName)
                .toolbar {
                    ToolbarItemGroup {
                        Menu {
                            Button("Import File...") {
                                isImporting = true
                            }

                            Button("Import from URL...") {
                                isURLImporting = true
                            }
                        } label: {
                            Label("Import", systemImage: "square.and.arrow.down")
                        }

                        Menu {
                            ForEach(RDFFormat.allCases) { format in
                                Button("Export \(format.title)") {
                                    export(format: format)
                                }
                            }
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                .fileImporter(
                    isPresented: $isImporting,
                    allowedContentTypes: RDFFormat.importContentTypes,
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            importRdf(from: url)
                        }
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
                .fileExporter(
                    isPresented: $isExporting,
                    document: exportDocument,
                    contentType: exportFormat.contentType,
                    defaultFilename: exportFormat.defaultFilename
                ) { result in
                    if case .failure(let error) = result {
                        errorMessage = error.localizedDescription
                    }
                }
                .sheet(isPresented: $isURLImporting) {
                    RemoteImportView(
                        urlText: $importURLText,
                        isFetching: isFetchingRemote,
                        onCancel: {
                            isURLImporting = false
                        },
                        onImport: {
                            Task {
                                await importRemoteRdf(from: importURLText)
                            }
                        }
                    )
                }
                .alert("File Error", isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { _ in errorMessage = nil }
                )) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage ?? "Unknown error.")
                }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Import RDF...") {
                    isImporting = true
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Import RDF from URL...") {
                    isURLImporting = true
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])

                Menu("Export RDF") {
                    ForEach(RDFFormat.allCases) { format in
                        Button("Export \(format.title)...") {
                            export(format: format)
                        }
                    }
                }
            }
        }
    }

    private func export(format: RDFFormat) {
        exportFormat = format
        exportDocument = RDFExportDocument(data: dataForExport(format))
        isExporting = true
    }

    private func dataForExport(_ format: RDFFormat) -> Data {
        let text: String
        switch format {
        case .turtle:
            text = graphStore.activeGraph.turtleString()
        case .ntriples:
            text = graphStore.activeGraph.ntriplesString()
        case .rdfxml:
            text = graphStore.activeGraph.rdfxmlString()
        case .nquads:
            text = graphStore.dataset.nquadsString()
        }
        return Data(text.utf8)
    }

    private func importRdf(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            try importRdf(data: data, url: url, response: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func importRemoteRdf(from urlText: String) async {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter an IRI, URI, or URL."
            return
        }

        guard let url = parseRemoteURL(from: trimmed) else {
            errorMessage = "Invalid IRI/URI/URL."
            return
        }

        isFetchingRemote = true
        defer {
            isFetchingRemote = false
        }

        do {
            var request = URLRequest(url: url)
            request.setValue(RDFFormat.acceptHeader, forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                errorMessage = "Request failed with status \(httpResponse.statusCode)."
                return
            }

            try importRdf(data: data, url: url, response: response)
            isURLImporting = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importRdf(data: Data, url: URL?, response: URLResponse?) throws {
        guard let text = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidText
        }

        let formatHint = RDFFormat.detect(from: url) ?? RDFFormat.detect(from: response) ?? RDFFormat.infer(from: text)
        let result = try parseRdf(text: text, formatHint: formatHint)

        switch result {
        case .graph(let graph):
            graphStore.replace(with: graph)
        case .dataset(let dataset):
            graphStore.replace(with: dataset)
        }
    }

    private func parseRdf(text: String, formatHint: RDFFormat?) throws -> RDFImportResult {
        let orderedFormats: [RDFFormat]
        if let formatHint {
            orderedFormats = [formatHint, .rdfxml, .turtle, .ntriples, .nquads]
        } else {
            orderedFormats = [.rdfxml, .turtle, .ntriples, .nquads]
        }

        var lastError: Error?
        for format in orderedFormats {
            do {
                switch format {
                case .turtle:
                    return .graph(try Graph(turtle: text))
                case .ntriples:
                    return .graph(try Graph(ntriples: text))
                case .rdfxml:
                    return .graph(try Graph(rdfxml: text))
                case .nquads:
                    return .dataset(try Dataset(nquads: text))
                }
            } catch {
                lastError = error
            }
        }

        throw lastError ?? ImportError.unsupportedFormat
    }

    private func parseRemoteURL(from text: String) -> URL? {
        if let iri = try? IRI(iriString: text), let url = try? iri.asURL() {
            return url
        }
        if let url = URL(string: text) {
            return url
        }
        return nil
    }
}

private enum RDFFormat: String, CaseIterable, Identifiable {
    case turtle
    case ntriples
    case nquads
    case rdfxml

    var id: String { rawValue }

    var title: String {
        switch self {
        case .turtle:
            return "Turtle"
        case .ntriples:
            return "N-Triples"
        case .nquads:
            return "N-Quads"
        case .rdfxml:
            return "RDF/XML"
        }
    }

    var contentType: UTType {
        switch self {
        case .turtle:
            return .turtle
        case .ntriples:
            return .ntriples
        case .nquads:
            return .nquads
        case .rdfxml:
            return .rdfxml
        }
    }

    var defaultFilename: String {
        switch self {
        case .nquads:
            return "dataset"
        case .turtle, .ntriples, .rdfxml:
            return "graph"
        }
    }

    static var importContentTypes: [UTType] {
        var types: [UTType] = []
        for format in RDFFormat.allCases {
            types.append(format.contentType)
        }
        types.append(.xml)
        return Array(Set(types))
    }

    static var acceptHeader: String {
        "text/turtle, application/n-triples, application/n-quads, application/rdf+xml, application/xml, text/xml, text/plain;q=0.5, */*;q=0.1"
    }

    static func detect(from url: URL?) -> RDFFormat? {
        guard let url else { return nil }
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "ttl":
            return .turtle
        case "nt":
            return .ntriples
        case "nq":
            return .nquads
        case "rdf", "xml":
            return .rdfxml
        default:
            return nil
        }
    }

    static func detect(from response: URLResponse?) -> RDFFormat? {
        guard let mimeType = response?.mimeType?.lowercased() else { return nil }
        switch mimeType {
        case "text/turtle", "application/x-turtle", "application/turtle":
            return .turtle
        case "application/n-triples", "text/n-triples":
            return .ntriples
        case "application/n-quads", "text/n-quads":
            return .nquads
        case "application/rdf+xml", "text/xml", "application/xml":
            return .rdfxml
        default:
            return nil
        }
    }

    static func infer(from text: String) -> RDFFormat? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<?xml") || trimmed.contains("<rdf:RDF") {
            return .rdfxml
        }
        if trimmed.contains("@prefix") || trimmed.contains("PREFIX") || trimmed.contains("@base") || trimmed.contains("BASE") {
            return .turtle
        }
        return nil
    }
}

private enum RDFImportResult {
    case graph(Graph)
    case dataset(Dataset)
}

private enum ImportError: LocalizedError {
    case invalidText
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .invalidText:
            return "Unable to read content as UTF-8 text."
        case .unsupportedFormat:
            return "Unsupported or unrecognized RDF format."
        }
    }
}

private final class GraphStore: ObservableObject {
    @Published var dataset: Dataset = SampleGraphBuilder.makeDataset()
    @Published var selectedGraphName: IRI?

    var activeGraph: Graph {
        dataset.graph(selectedGraphName) ?? dataset.defaultGraph
    }

    func replace(with graph: Graph) {
        dataset = Dataset(defaultGraph: graph)
        selectedGraphName = nil
    }

    func replace(with dataset: Dataset) {
        self.dataset = dataset
        if let selectedGraphName, dataset.graph(selectedGraphName) == nil {
            self.selectedGraphName = nil
        }
    }
}

private enum SampleGraphBuilder {
    static func makeDataset() -> Dataset {
        Dataset(defaultGraph: makeGraph())
    }

    static func makeGraph() -> Graph {
        var graph = Graph()

        do {
            guard
                let alice = try? IRI(iriString: "https://example.com/alice"),
                let knows = try? IRI(iriString: "https://example.com/knows"),
                let name = try? IRI(iriString: "https://schema.org/name"),
                let age = try? IRI(iriString: "https://schema.org/age"),
                let rdfType = try? IRI(iriString: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"),
                let schemaPerson = try? IRI(iriString: "https://schema.org/Person"),
                let xsdInteger = try? IRI(iriString: "http://www.w3.org/2001/XMLSchema#integer")
            else {
                return graph
            }

            let bob = try BlankNode("b1")
            let aliceName = try Literal("Alice", languageTag: "en")
            let aliceAge = try Literal("29", datatype: xsdInteger)
            let aliceSubject = try AnyRDFSubject(alice)

            let triples = [
                Triple(subject: aliceSubject, predicate: rdfType, object: AnyRDFObject(schemaPerson)),
                Triple(subject: aliceSubject, predicate: knows, object: AnyRDFObject(bob)),
                Triple(subject: aliceSubject, predicate: name, object: AnyRDFObject(aliceName)),
                Triple(subject: aliceSubject, predicate: age, object: AnyRDFObject(aliceAge))
            ]

            for triple in triples {
                try? graph.insert(triple)
            }
        } catch {
            return graph
        }

        return graph
    }
}

private struct RDFExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { RDFFormat.importContentTypes }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct RemoteImportView: View {
    @Binding var urlText: String
    let isFetching: Bool
    let onCancel: () -> Void
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import from IRI, URI, or URL")
                .font(.title2)
                .fontWeight(.semibold)

            TextField("https://example.com/data.ttl", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Import") {
                    onImport()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isFetching)
            }

            if isFetching {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Fetching and parsing RDF...")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 420)
    }
}

private extension UTType {
    static let turtle = UTType(filenameExtension: "ttl") ?? .plainText
    static let ntriples = UTType(filenameExtension: "nt") ?? .plainText
    static let nquads = UTType(filenameExtension: "nq") ?? .plainText
    static let rdfxml = UTType(filenameExtension: "rdf") ?? .xml
}
